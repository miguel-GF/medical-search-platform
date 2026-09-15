param([int]$Port=55439,[string]$Database='pruevia_intake_test')
$ErrorActionPreference='Stop'
$repoPath=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# Only the disposable local database. Never accepts a remote DSN or credentials.
$dbArgs=@('-h','127.0.0.1','-p',"$Port",'-U','postgres','-d',$Database,'-v','ON_ERROR_STOP=1','-X','-q')
function RunSqlFile([string]$relative) {
  & psql @dbArgs -f (Join-Path $repoPath $relative)
  if($LASTEXITCODE -ne 0){throw "SQL failed: $relative"}
}
RunSqlFile 'database/tests/provider_intake_bootstrap.sql'
foreach($file in @('20260831120000_118_provider_claims.sql','20260831122000_120_provider_claims_scope_guards.sql','20260831123000_121_provider_profile_change_requests.sql','20260904140000_provider_document_verification.sql','20260906220000_provider_non_anonymous_identity.sql')) {
  RunSqlFile "database/supabase/migrations/$file"
}
$legacy=Get-Content (Join-Path $repoPath 'database/supabase/migrations/20260904100000_provider_admin_idempotency.sql') -Raw -Encoding UTF8
$function=[regex]::Match($legacy,'(?s)create or replace function ingest.admin_revoke_provider_claim_core\(.*?\$\$;').Value
if(!$function){throw 'Missing legacy revocation implementation'}
$function | & psql @dbArgs
if($LASTEXITCODE -ne 0){throw 'Legacy function failed'}
RunSqlFile 'database/supabase/migrations/20260914120000_provider_application_workflow.sql'
RunSqlFile 'database/supabase/migrations/20260914121000_provider_document_activation_gate.sql'
RunSqlFile 'database/tests/provider_intake_contract.sql'
