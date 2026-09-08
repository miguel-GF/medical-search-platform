param(
  [string]$Test = 'provider_claims_test.sql',
  [switch]$InternalRelease
)
$ErrorActionPreference = 'Stop'
$dbRoot = Split-Path $PSScriptRoot -Parent
$testPath = Join-Path $dbRoot "supabase/tests/$Test"
if ($Test -notmatch '^[a-z0-9_]+\.sql$' -or !(Test-Path -LiteralPath $testPath)) {
  throw 'Specify one SQL contract filename from supabase/tests.'
}
# Rehearse the pending changes in one transaction. No migration ledger entry,
# fixture, privilege change or Storage metadata survives the final rollback.
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add("begin;`nset local lock_timeout = '5s';`nset local statement_timeout = '60s';")
$migrations = Get-ChildItem (Join-Path $dbRoot 'supabase/migrations') -Filter '*.sql' |
  Where-Object { $_.Name -ge '20260904115000_provider_aal2_immediate_hardening.sql' -and $_.Name -le $(if ($InternalRelease) { '20260908100000_internal_document_freeze.sql' } else { '20260906240000_provider_change_json_size.sql' }) } |
  Sort-Object Name
foreach ($migration in $migrations) {
  $source = [IO.File]::ReadAllText($migration.FullName)
  $source = $source -replace '(?im)^(begin|commit);\s*$', ''
  $parts.Add($source)
}
$parts.Add('create temporary table security_tap_results (ordinal bigint generated always as identity, result text);')
$contract = [IO.File]::ReadAllText($testPath)
$contract = $contract -replace '(?im)^(begin|rollback);\s*$', ''
$contract = $contract -replace '(?im)^select extensions\.(?!plan\()', 'insert into security_tap_results(result) select extensions.'
$contract = $contract -replace '(?im)^select \* from extensions.finish\(\);', 'insert into security_tap_results(result) select * from extensions.finish();'
$parts.Add($contract)
$parts.Add('select result from security_tap_results order by ordinal; rollback;')
$artifact = Join-Path ([IO.Path]::GetTempPath()) ('pruevia-security-' + [guid]::NewGuid().ToString('N') + '.sql')
try {
  [IO.File]::WriteAllText($artifact, ($parts -join "`n"), [Text.UTF8Encoding]::new($false))
  Push-Location $dbRoot
  try {
    # Windows PowerShell turns native stderr progress into ErrorRecords.
    # Inspect the actual process status and SQL/TAP response below.
    $ErrorActionPreference = 'Continue'
    try {
      $output = & npx.cmd supabase@2.116.0 db query --linked --file $artifact 2>&1
      $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    $output | ForEach-Object { Write-Output $_.ToString() }
    $joined = $output -join "`n"
    if ($exitCode -ne 0 -or $joined -match 'not ok|Looks like|"_tag":\s*"Error"' -or $joined -notmatch 'ok [0-9]+ -') {
      throw 'Security rehearsal failed; inspect the TAP results above.'
    }
  } finally { Pop-Location }
} finally {
  if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact }
}
