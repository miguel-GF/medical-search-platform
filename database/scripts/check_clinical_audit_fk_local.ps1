[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ArtifactDir,[Parameter(Mandatory=$true)][string]$WorkspaceRoot)
$ErrorActionPreference='Stop'
$workspaceRoot=[IO.Path]::GetFullPath($WorkspaceRoot)
if(-not (Test-Path -LiteralPath (Join-Path $workspaceRoot 'database\scripts\prepare_clinical_audit_fk_correction.py'))){throw 'Unexpected workspace'}
$artifactRoot=Join-Path $workspaceRoot 'collectors\artifacts'
$taskDir=[IO.Path]::GetFullPath($ArtifactDir)
if(-not $taskDir.StartsWith($artifactRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Local check must stay in artifacts'}
$pgBin='C:\laragon\bin\postgresql\pgsql-12.2\bin'
$cluster=Join-Path $taskDir 'local-pg12-constraint-check'
if(Test-Path -LiteralPath $cluster){throw 'Preserve the existing local check'}
New-Item -ItemType Directory -Path $cluster -ErrorAction Stop | Out-Null
$passwordFile=Join-Path $cluster 'password.local'
$taskPassword=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($passwordFile,$taskPassword,[Text.UTF8Encoding]::new($false))
$previousPassword=$env:PGPASSWORD
$previousEncoding=$env:PGCLIENTENCODING
$env:PGPASSWORD=$taskPassword
$env:PGCLIENTENCODING='UTF8'
$started=$false
try {
 & (Join-Path $pgBin 'initdb.exe') -D (Join-Path $cluster 'data') -A scram-sha-256 -U candidate_eval --locale=C --encoding=UTF8 --pwfile=$passwordFile *> (Join-Path $cluster 'initdb.log')
 if($LASTEXITCODE -ne 0){throw 'Local initdb failed'}
 $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
 $listener.Start();$taskPort=([Net.IPEndPoint]$listener.LocalEndpoint).Port;$listener.Stop()
 & (Join-Path $pgBin 'pg_ctl.exe') -D (Join-Path $cluster 'data') -l (Join-Path $cluster 'server.log') -o "-h 127.0.0.1 -p $taskPort" -w start
 if($LASTEXITCODE -ne 0){throw 'Local PostgreSQL did not start'}
 $started=$true
 $bootstrap="create schema health; create schema core; create schema audit; create table health.services(catalog_item_id uuid primary key); create table core.provider_brands(id uuid primary key); create table audit.events(id bigint primary key);"
 $bootstrapFile=Join-Path $cluster 'bootstrap.sql'
 [IO.File]::WriteAllText($bootstrapFile,$bootstrap,[Text.UTF8Encoding]::new($false))
 $connection=@('-h','127.0.0.1','-p',$taskPort.ToString(),'-U','candidate_eval','-d','postgres','-v','ON_ERROR_STOP=1')
 & (Join-Path $pgBin 'psql.exe') @connection -f $bootstrapFile *> (Join-Path $cluster 'bootstrap.log')
 if($LASTEXITCODE -ne 0){throw 'Local bootstrap failed'}
 foreach($variant in @('original','corrected')) {
   $fragment=Get-Content -LiteralPath (Join-Path $taskDir ('panel-registry-'+$variant+'.sql')) -Raw -Encoding UTF8
   $sqlFile=Join-Path $cluster ($variant+'.sql')
   [IO.File]::WriteAllText($sqlFile,"begin;`n"+$fragment+"`nrollback;`n",[Text.UTF8Encoding]::new($false))
   $errorLog=Join-Path $cluster ($variant+'-error.log')
   $process=Start-Process -FilePath (Join-Path $pgBin 'psql.exe') -ArgumentList ($connection+@('-f',('"'+$sqlFile+'"'))) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $cluster ($variant+'.log')) -RedirectStandardError $errorLog
   $code=$process.ExitCode
   if($variant -eq 'original'){
     $originalExit=$code
     if($code -eq 0){throw 'Original unexpectedly accepted the incompatible FK'}
     $failure=Get-Content -LiteralPath $errorLog -Raw
     if(-not $failure.Contains('cannot be implemented') -or -not $failure.Contains('uuid and bigint')){throw 'Original failed for a different reason'}
   } else {
     $correctedExit=$code
     if($code -ne 0){throw 'Corrected local registry DDL failed'}
   }
 }
 $version=& (Join-Path $pgBin 'postgres.exe') --version
 $receipt=@{at=[DateTime]::UtcNow.ToString('o');postgres_version=$version;host='127.0.0.1';port=$taskPort;original_exit=$originalExit;corrected_exit=$correctedExit;scope='Two registry tables against empty parent tables with matching key types; not a full algorithm evaluation';production_calls=0}
 [IO.File]::WriteAllText((Join-Path $taskDir 'local-fk-check.json'),(ConvertTo-Json $receipt),[Text.UTF8Encoding]::new($false))
 ConvertTo-Json $receipt
} finally {
 if($started){& (Join-Path $pgBin 'pg_ctl.exe') -D (Join-Path $cluster 'data') -m fast -w stop}
 $env:PGPASSWORD=$previousPassword
 $env:PGCLIENTENCODING=$previousEncoding
 Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue
}
