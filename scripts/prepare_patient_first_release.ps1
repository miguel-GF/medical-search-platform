[CmdletBinding()]
param(
    [switch]$Indexable,
    [switch]$EnableFeedback
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

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

Push-Location (Join-Path $repositoryRoot 'apps/landing')
try {
    $publicVariables = @(
        'PRUEVIA_SITE_URL',
        'PRUEVIA_PATIENT_APP_ENABLED',
        'PRUEVIA_PATIENT_URL',
        'PRUEVIA_PROVIDER_ACCESS_ENABLED',
        'PRUEVIA_PROVIDER_URL',
        'PRUEVIA_SUPPORT_EMAIL',
        'PRUEVIA_API_URL',
        'PRUEVIA_TESTER_INTAKE_ENABLED',
        'PRUEVIA_PRIVACY_CONTROLLER',
        'PRUEVIA_PRIVACY_ADDRESS',
        'PRUEVIA_PRIVACY_EMAIL',
        'PRUEVIA_TESTER_NOTICE_VERSION'
    )
    foreach ($name in $publicVariables) {
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    $env:PRUEVIA_INDEXABLE = if ($Indexable) { 'true' } else { 'false' }

    Invoke-NativeCommand 'npm.cmd' @('run', 'test')
    Invoke-NativeCommand 'npm.cmd' @('run', 'typecheck')
    Invoke-NativeCommand 'npm.cmd' @(
        'exec', '--offline', '--', 'nuxt', 'generate',
        '--dotenv', 'config/patient-first.env'
    )
    Invoke-NativeCommand 'node' @('scripts/render_headers.mjs')

    $landingHtml = Get-Content -LiteralPath '.output/public/index.html' -Raw -Encoding UTF8
    foreach ($forbidden in @('?provider=1', 'Acceso para proveedores', 'https://app.pruevia.com.mx', 'https://api.pruevia.com.mx', 'http://localhost', 'http://127.0.0.1')) {
        if ($landingHtml.Contains($forbidden)) {
            throw "Landing release artifact contains forbidden patient-first marker: $forbidden"
        }
    }
}
finally {
    Pop-Location
}

Push-Location (Join-Path $repositoryRoot 'apps/patient')
try {
    Invoke-NativeCommand 'flutter' @('analyze')
    Invoke-NativeCommand 'flutter' @('test')

    $feedback = if ($EnableFeedback) { 'true' } else { 'false' }
    Invoke-NativeCommand 'flutter' @(
        'build', 'web', '--release',
        '--dart-define=API_BASE_URL=https://api.pruevia.com.mx',
        '--dart-define=API_ALLOWED_HOSTS=api.pruevia.com.mx',
        "--dart-define=PRODUCT_FEEDBACK_ENABLED=$feedback",
        '--dart-define=ANALYTICS_ENABLED=false',
        '--dart-define=PROVIDER_PORTAL_ENABLED=false',
        '--dart-define=PRIVACY_POLICY_URL=https://pruevia.com.mx/privacidad',
        '--dart-define=SUPPORT_EMAIL=contacto@pruevia.com.mx',
        '--dart-define=PRUEVIA_CHANNEL=public'
    )
    Invoke-NativeCommand 'dart' @(
        'run', 'tool/render_web_headers.dart',
        '--output', 'build/web/_headers',
        '--allowed-hosts', 'api.pruevia.com.mx'
    )
}
finally {
    Pop-Location
}

Write-Output 'Prepared landing in apps/landing/.output/public and patient PWA in apps/patient/build/web.'
Write-Output 'No remote deployment or DNS change was performed.'
