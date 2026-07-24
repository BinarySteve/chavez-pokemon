[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ApkPath,

    [Parameter(Mandatory)]
    [string] $PublishDirectory,

    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+([-.][0-9A-Za-z.-]+)?$')]
    [string] $VersionName,

    [Parameter(Mandatory)]
    [ValidateRange(1, 2147483647)]
    [int] $VersionCode,

    [Parameter(Mandatory)]
    [ValidateLength(1, 80)]
    [string] $Title,

    [ValidateCount(0, 6)]
    [string[]] $Notes = @(),

    [string] $ExpectedCertificateSha256 = $env:POKEMON_RELEASE_CERT_SHA256,

    [switch] $AllowUnpinnedCertificate
)

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath -ErrorAction Stop).Path
if ([System.IO.Path]::GetExtension($resolvedApk) -ne '.apk') {
    throw 'ApkPath must point to an .apk file.'
}

$androidBuildTools = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
$aapt = Get-ChildItem -LiteralPath $androidBuildTools -Recurse -Filter aapt.exe |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $aapt) {
    throw 'Android aapt was not found. Install Android SDK Build Tools before publishing.'
}
$badgingOutput = & $aapt.FullName dump badging $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw 'Android could not read the APK package metadata.'
}
$packageLine = $badgingOutput | Select-String -Pattern "^package:\s+name='([^']+)'\s+versionCode='(\d+)'\s+versionName='([^']+)'"
if (-not $packageLine) {
    throw 'Could not read package name and version from the APK.'
}
$apkPackageName = $packageLine.Matches[0].Groups[1].Value
$apkVersionCode = [int] $packageLine.Matches[0].Groups[2].Value
$apkVersionName = $packageLine.Matches[0].Groups[3].Value
if ($apkPackageName -ne 'com.chavezfamily.pokemon_adventure') {
    throw "APK package mismatch. Expected com.chavezfamily.pokemon_adventure, found $apkPackageName."
}
if ($apkVersionCode -ne $VersionCode -or $apkVersionName -ne $VersionName) {
    throw "APK version is $apkVersionName+$apkVersionCode, but publishing requested $VersionName+$VersionCode. Rebuild the APK with the requested version before publishing."
}

$apkSigner = Get-ChildItem -LiteralPath $androidBuildTools -Recurse -Filter apksigner.bat |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $apkSigner) {
    throw 'Android apksigner was not found. Install Android SDK Build Tools before publishing.'
}
$signatureOutput = & $apkSigner.FullName verify --print-certs $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw 'Android rejected the APK signature.'
}
$certificateLine = $signatureOutput |
    Select-String -Pattern 'certificate SHA-256 digest:\s*([a-fA-F0-9]{64})' |
    Select-Object -First 1
if (-not $certificateLine) {
    throw 'Could not read the APK signing certificate SHA-256 digest.'
}
$certificateSha256 = $certificateLine.Matches[0].Groups[1].Value.ToLowerInvariant()
if (-not $ExpectedCertificateSha256 -and -not $AllowUnpinnedCertificate) {
    throw 'Set POKEMON_RELEASE_CERT_SHA256 before publishing a family release.'
}
if ($ExpectedCertificateSha256) {
    $expected = ($ExpectedCertificateSha256 -replace '[:\s]', '').ToLowerInvariant()
    if ($expected -notmatch '^[a-f0-9]{64}$') {
        throw 'ExpectedCertificateSha256 must be a SHA-256 certificate digest.'
    }
    if ($certificateSha256 -ne $expected) {
        throw "APK signing certificate mismatch. Expected $expected, found $certificateSha256."
    }
}

$publishRoot = [System.IO.Path]::GetFullPath($PublishDirectory)
[System.IO.Directory]::CreateDirectory($publishRoot) | Out-Null

$existingManifestPath = Join-Path $publishRoot 'latest.json'
if (Test-Path -LiteralPath $existingManifestPath) {
    try {
        $existingManifest = Get-Content -LiteralPath $existingManifestPath -Raw |
            ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Existing latest.json is invalid and was not replaced: $($_.Exception.Message)"
    }
    if ($null -eq $existingManifest.versionCode) {
        throw 'Existing latest.json has no versionCode and was not replaced.'
    }
    $existingVersionCode = [int] $existingManifest.versionCode
    if ($VersionCode -le $existingVersionCode) {
        throw "VersionCode must increase. Existing release is $existingVersionCode; requested release is $VersionCode."
    }
}

$apkName = "pokemon-adventure-$VersionName-$VersionCode.apk"
$publishedApk = Join-Path $publishRoot $apkName
Copy-Item -LiteralPath $resolvedApk -Destination $publishedApk -Force

$apkFile = Get-Item -LiteralPath $publishedApk
$checksum = (Get-FileHash -LiteralPath $publishedApk -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    schemaVersion = 1
    packageName = 'com.chavezfamily.pokemon_adventure'
    versionCode = $VersionCode
    versionName = $VersionName
    apkUrl = $apkName
    sha256 = $checksum
    sizeBytes = $apkFile.Length
    title = $Title
    notes = @($Notes)
}

$manifestPath = Join-Path $publishRoot 'latest.json'
$temporaryManifestPath = Join-Path $publishRoot 'latest.json.tmp'
$json = $manifest | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
    $temporaryManifestPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
Move-Item -LiteralPath $temporaryManifestPath -Destination $manifestPath -Force

Write-Host "Prepared homelab release:"
Write-Host "  APK:      $publishedApk"
Write-Host "  Manifest: $manifestPath"
Write-Host "  Signer:   $certificateSha256"
Write-Host "The APK was published first and latest.json was moved into place last."
