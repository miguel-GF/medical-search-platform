[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$databaseRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$pgBin = 'C:\laragon\bin\postgresql\pgsql-12.2\bin'
$initdb = Join-Path $pgBin 'initdb.exe'
$pgCtl = Join-Path $pgBin 'pg_ctl.exe'
$psql = Join-Path $pgBin 'psql.exe'
foreach ($tool in @($initdb, $pgCtl, $psql)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "PostgreSQL 12 tool missing: $tool" }
}

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$scratch = Join-Path $tempRoot ('pruevia-pg12-smoke-' + [guid]::NewGuid().ToString('N'))
$scratch = [IO.Path]::GetFullPath($scratch)
if (-not $scratch.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($scratch)).StartsWith('pruevia-pg12-smoke-')) {
    throw 'Unsafe temporary PostgreSQL path'
}
$data = Join-Path $scratch 'data'
$log = Join-Path $scratch 'server.log'
$started = $false

New-Item -ItemType Directory -Path $scratch -ErrorAction Stop | Out-Null
try {
    & $initdb -D $data -A trust -U postgres --encoding=UTF8 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $listener.Stop()

    # Do not pipe pg_ctl output: its server child can inherit the pipe and
    # keep PowerShell waiting forever even after pg_ctl itself exits.
    & $pgCtl -D $data -l $log -o "-h 127.0.0.1 -p $port" -w start
    if ($LASTEXITCODE -ne 0) { throw 'pg_ctl start failed' }
    $started = $true

    Push-Location $databaseRoot
    try {
        & $psql -h 127.0.0.1 -p $port -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -f scripts/smoke_exact_crawler_migration_pg12.sql
        if ($LASTEXITCODE -ne 0) { throw 'crawler migration SQL smoke failed' }
    }
    finally { Pop-Location }
}
finally {
    if ($started) { & $pgCtl -D $data -m immediate -w stop }
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if ($resolvedScratch.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        ([IO.Path]::GetFileName($resolvedScratch)).StartsWith('pruevia-pg12-smoke-')) {
        Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
    }
}
