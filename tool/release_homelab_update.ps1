[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateLength(1, 80)]
    [string] $Title,

    [ValidateCount(0, 6)]
    [string[]] $Notes = @(),

    [string] $ManifestUrl = 'https://poke.chaveznet.dev/latest.json',

    [string] $PublishDirectory = 'C:\docker\pokemon-adventure-updates\releases',

    [string] $KeystorePath = 'C:\secure\pokemon-family-release.jks',

    [string] $KeyAlias = 'pokemon-family'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Raw
$versionMatch = [regex]::Match(
    $pubspec,
    '(?m)^version:\s*(\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?)\+(\d+)\s*$'
)
if (-not $versionMatch.Success) {
    throw 'pubspec.yaml must contain a version such as 1.0.1+2.'
}
$versionName = $versionMatch.Groups[1].Value
$versionCode = [int] $versionMatch.Groups[2].Value

$resolvedKeystore = (Resolve-Path -LiteralPath $KeystorePath -ErrorAction Stop).Path
$publishRoot = [System.IO.Path]::GetFullPath($PublishDirectory)
$latestManifestPath = Join-Path $publishRoot 'latest.json'
if (-not (Test-Path -LiteralPath $latestManifestPath)) {
    throw 'No hosted latest.json was found. Use the documented first-release workflow to establish the signing chain.'
}

$latestManifest = Get-Content -LiteralPath $latestManifestPath -Raw |
    ConvertFrom-Json -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($latestManifest.apkUrl)) {
    throw 'The hosted latest.json has no apkUrl.'
}
$hostedApk = [System.IO.Path]::GetFullPath(
    (Join-Path $publishRoot ([string] $latestManifest.apkUrl))
)
$publishPrefix = $publishRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $hostedApk.StartsWith(
    $publishPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw 'The hosted apkUrl resolves outside the publish directory.'
}
if (-not (Test-Path -LiteralPath $hostedApk)) {
    throw "The currently hosted APK was not found: $hostedApk"
}

$androidBuildTools = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
$apkSigner = Get-ChildItem -LiteralPath $androidBuildTools -Recurse -Filter apksigner.bat |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $apkSigner) {
    throw 'Android apksigner was not found. Install Android SDK Build Tools before publishing.'
}
$hostedSignatureOutput = & $apkSigner.FullName verify --print-certs $hostedApk
if ($LASTEXITCODE -ne 0) {
    throw 'Android rejected the currently hosted APK signature.'
}
$hostedCertificateLine = $hostedSignatureOutput |
    Select-String -Pattern 'certificate SHA-256 digest:\s*([a-fA-F0-9]{64})' |
    Select-Object -First 1
if (-not $hostedCertificateLine) {
    throw 'Could not read the hosted APK signing certificate.'
}
$hostedCertificate = $hostedCertificateLine.Matches[0].Groups[1].Value

$previousEnvironment = @{}
foreach ($name in @(
    'POKEMON_KEYSTORE_PATH',
    'POKEMON_KEYSTORE_PASSWORD',
    'POKEMON_KEY_ALIAS',
    'POKEMON_KEY_PASSWORD'
)) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable(
        $name,
        'Process'
    )
}

$signingPlaintext = $null
try {
    $env:POKEMON_KEYSTORE_PATH = $resolvedKeystore
    $env:POKEMON_KEY_ALIAS = $KeyAlias
    if ([string]::IsNullOrWhiteSpace($env:POKEMON_KEYSTORE_PASSWORD)) {
        $securePassword = Read-Host 'Family signing password' -AsSecureString
        $signingPlaintext = [System.Net.NetworkCredential]::new(
            '',
            $securePassword
        ).Password
        $env:POKEMON_KEYSTORE_PASSWORD = $signingPlaintext
        $env:POKEMON_KEY_PASSWORD = $signingPlaintext
    }
    elseif ([string]::IsNullOrWhiteSpace($env:POKEMON_KEY_PASSWORD)) {
        $env:POKEMON_KEY_PASSWORD = $env:POKEMON_KEYSTORE_PASSWORD
    }

    Push-Location $repoRoot
    try {
        & flutter build apk --release `
            "--build-name=$versionName" `
            "--build-number=$versionCode" `
            "--dart-define=APP_UPDATE_MANIFEST_URL=$ManifestUrl"
        if ($LASTEXITCODE -ne 0) {
            throw 'Flutter release build failed.'
        }

        & (Join-Path $PSScriptRoot 'publish_homelab_update.ps1') `
            -ApkPath (Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk') `
            -PublishDirectory $publishRoot `
            -VersionName $versionName `
            -VersionCode $versionCode `
            -Title $Title `
            -Notes $Notes `
            -ExpectedCertificateSha256 $hostedCertificate
    }
    finally {
        Pop-Location
    }
}
finally {
    $signingPlaintext = $null
    foreach ($name in $previousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable(
            $name,
            $previousEnvironment[$name],
            'Process'
        )
    }
}
