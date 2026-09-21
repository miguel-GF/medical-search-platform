[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$BuildName = '1.0.0',
    [ValidateRange(1, 2100000000)][int]$BuildNumber = 1
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Resolve-JdkTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command "$Name.exe" -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $command = Get-Command $Name -ErrorAction SilentlyContinue
    }
    if ($null -ne $command) {
        return $command.Source
    }

    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        foreach ($filename in @("$Name.exe", $Name)) {
            $candidate = Join-Path $env:JAVA_HOME "bin/$filename"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }

    throw "$Name was not found. Install or select the JDK used by Flutter."
}

$requiredSigningVariables = @(
    'PRUEVIA_RELEASE_STORE_FILE',
    'PRUEVIA_RELEASE_STORE_PASSWORD',
    'PRUEVIA_RELEASE_KEY_ALIAS',
    'PRUEVIA_RELEASE_KEY_PASSWORD'
)

$missing = @($requiredSigningVariables | Where-Object {
    [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
})
if ($missing.Count -gt 0) {
    throw "Android upload signing is not configured. Missing: $($missing -join ', ')"
}

$storePath = [Environment]::GetEnvironmentVariable('PRUEVIA_RELEASE_STORE_FILE')
if (-not (Test-Path -LiteralPath $storePath -PathType Leaf)) {
    throw 'PRUEVIA_RELEASE_STORE_FILE does not point to an existing keystore.'
}
$storePath = (Resolve-Path -LiteralPath $storePath).Path
$env:PRUEVIA_RELEASE_STORE_FILE = $storePath

$keytool = Resolve-JdkTool -Name 'keytool'
$keyAlias = [Environment]::GetEnvironmentVariable('PRUEVIA_RELEASE_KEY_ALIAS')
& $keytool -list -alias $keyAlias -keystore $storePath -storepass:env PRUEVIA_RELEASE_STORE_PASSWORD *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'The Android upload keystore or alias could not be verified.'
}

$patientRoot = Join-Path $repositoryRoot 'apps/patient'
Push-Location $patientRoot
try {
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
    & flutter build appbundle --release `
        --build-name $BuildName `
        --build-number $BuildNumber `
        --dart-define=API_BASE_URL=https://api.pruevia.com.mx `
        --dart-define=API_ALLOWED_HOSTS=api.pruevia.com.mx `
        --dart-define=PRODUCT_FEEDBACK_ENABLED=true `
        --dart-define=ANALYTICS_ENABLED=false `
        --dart-define=PROVIDER_PORTAL_ENABLED=false `
        --dart-define=PRIVACY_POLICY_URL=https://pruevia.com.mx/privacidad `
        --dart-define=SUPPORT_EMAIL=contacto@pruevia.com.mx `
        --dart-define=PRUEVIA_CHANNEL=closed_android `
        --dart-define="APP_VERSION=$BuildName+$BuildNumber"
    if ($LASTEXITCODE -ne 0) { throw 'Android App Bundle build failed' }
}
finally {
    Pop-Location
}

$bundlePath = Join-Path $patientRoot 'build/app/outputs/bundle/release/app-release.aab'
if (-not (Test-Path -LiteralPath $bundlePath -PathType Leaf)) {
    throw 'The Android build finished without producing the expected App Bundle.'
}

$jarsigner = Resolve-JdkTool -Name 'jarsigner'
$signatureOutput = (& $jarsigner '-J-Duser.language=en' '-J-Duser.country=US' -verify $bundlePath 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $signatureOutput -notmatch 'jar verified\.') {
    throw 'The generated Android App Bundle signature could not be verified.'
}
Write-Output 'AAB JAR signature: verified.'

$bundle = Get-Item -LiteralPath $bundlePath
$bundleHash = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
$gitCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitCommit)) {
    throw 'Could not identify the Git commit used for the Android build.'
}
$gitStatus = (& git -C $repositoryRoot status --porcelain --untracked-files=normal | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Could not identify whether the Android build used a dirty worktree.'
}

$evidence = [ordered]@{
    schema_version = 1
    package_id = 'com.pruevia.app'
    version_name = $BuildName
    version_code = $BuildNumber
    app_bundle_file = $bundle.Name
    app_bundle_bytes = $bundle.Length
    app_bundle_sha256 = $bundleHash
    built_at_utc = [DateTime]::UtcNow.ToString('o')
    git_commit = $gitCommit
    git_dirty = -not [string]::IsNullOrWhiteSpace($gitStatus)
    api_origin = 'https://api.pruevia.com.mx'
    release_channel = 'closed_android'
    product_feedback_enabled = $true
    analytics_enabled = $false
    provider_portal_enabled = $false
    signature_verified = $true
    uploaded_to_google_play = $false
}
$evidencePath = Join-Path $bundle.DirectoryName 'app-release.evidence.json'
$evidenceJson = $evidence | ConvertTo-Json
[System.IO.File]::WriteAllText(
    $evidencePath,
    "$evidenceJson$([Environment]::NewLine)",
    [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Signed Android App Bundle prepared for closed testing: $BuildName+$BuildNumber"
Write-Output "AAB: $bundlePath"
Write-Output "Evidence: $evidencePath"
Write-Output "SHA-256: $bundleHash"
Write-Output 'No artifact was uploaded to Google Play.'
