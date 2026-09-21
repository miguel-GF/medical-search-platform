[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$adminRoot = Join-Path $repositoryRoot 'apps/admin'

$required = @(
    'VITE_API_URL',
    'VITE_API_ALLOWED_HOSTS',
    'VITE_SUPABASE_URL',
    'VITE_SUPABASE_ALLOWED_HOSTS',
    'VITE_SUPABASE_PUBLISHABLE_KEY'
)

foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath "Env:$name") -or [string]::IsNullOrWhiteSpace((Get-Item -LiteralPath "Env:$name").Value)) {
        throw "$name is required for the production Admin build. Keep its value outside Git."
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

Push-Location $adminRoot
try {
    Invoke-NativeCommand 'npm.cmd' @('run', 'typecheck')
    Invoke-NativeCommand 'npm.cmd' @('test')
    Invoke-NativeCommand 'npm.cmd' @('run', 'build')
    Invoke-NativeCommand 'node' @('scripts/render_headers.mjs')

    $index = Get-Content -LiteralPath 'dist/index.html' -Raw -Encoding UTF8
    foreach ($forbidden in @('http://localhost', 'http://127.0.0.1', '__PRUEVIA_CONNECT_SRC__')) {
        if ($index.Contains($forbidden)) {
            throw "Admin release artifact contains forbidden marker: $forbidden"
        }
    }
}
finally {
    Pop-Location
}

Write-Output 'Prepared Admin production artifact in apps/admin/dist.'
Write-Output 'Cloudflare Access remains an external gate and must be verified before opening the custom domain.'
