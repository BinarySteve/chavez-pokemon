# Homelab app updates

The Android app can check a small JSON release manifest on a private homelab,
download a newer APK, verify its SHA-256 checksum, and hand the verified file to
Android's package installer.

The experience is intentionally child-friendly:

1. Home shows **A new adventure is ready!**
2. A visual What's New dialog explains the update.
3. The action says **Update with a grown-up**.
4. Download progress stays visible in the app.
5. Android requires an adult to allow this app as an install source and confirm
   the update.

The existing app remains usable if the server is offline, the download fails,
or verification rejects the APK.

## Chosen homelab topology

Pokémon Adventure uses a dedicated static container at:

```text
C:\docker\pokemon-adventure-updates
```

It intentionally does not reuse Lift Ledger's authenticated Fastify and
PostgreSQL services. This app has no accounts or server data, so the smaller
service avoids tokens, database availability, migrations, and update tracking.

The container:

- runs unprivileged Nginx with all Linux capabilities dropped;
- mounts `releases/` read-only;
- publishes port `6983`;
- serves only `/healthz`, `/latest.json`, and versioned Pokémon Adventure APKs;
- prevents caching of `latest.json` and APK responses; and
- serves APK responses as `text/event-stream` so Cloudflare Tunnel streams
  large files instead of buffering and prematurely closing the response.

Start or inspect it with:

```powershell
Set-Location C:\docker\pokemon-adventure-updates
docker compose up -d
docker compose ps
Invoke-WebRequest http://localhost:6983/healthz
```

The locally managed Cloudflare Tunnel routes
`https://poke.chaveznet.dev` directly to `http://localhost:6983`. Its ingress
rule lives in `C:\Users\itsst\.cloudflared\config.yml`; do not migrate the
tunnel to dashboard management merely to edit this route. The APK's HTTP
content type is only a transport hint for Cloudflare. The app saves the
response as an APK, verifies its expected size and SHA-256 checksum, and then
hands the local file to Android with the package-installer MIME type.

## One-time requirements

### Use a permanent signing key

Android only accepts an APK as an update when its application ID and signing
certificate match the installed app and its version code is not lower. Before
installing the first durable family-device build:

- create a permanent release keystore;
- back it up in at least two secure places;
- never commit the keystore or its passwords; and
- sign every future homelab APK with that same key.

The current project still falls back to the debug certificate. That is suitable
for emulator testing only. Replacing the certificate later requires uninstalling
the app, which erases local trainer progress.

#### 1. Create the key once

Run this outside the repository. `keytool` asks for the password without
printing it:

```powershell
New-Item -ItemType Directory -Path C:\secure -Force

keytool -genkeypair -v `
  -keystore C:\secure\pokemon-family-release.jks `
  -storetype PKCS12 `
  -alias pokemon-family `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10950 `
  -dname "CN=Pokemon Adventure Family, OU=Family Apps, O=Chavez Family, C=US"
```

The 10,950-day validity is approximately 30 years. Never generate this key
again for later releases; every update must use this exact file and alias.

#### 2. Back it up before installing the first family build

Store:

- the `.jks` file in two encrypted backup locations, including one offline;
- the keystore password and alias in the password manager; and
- the signing-certificate SHA-256 digest in the password manager.

Do not put the key or passwords in Git, the Docker release directory, cloud
notes, or the APK. Losing the key prevents future updates. Someone obtaining
both the key and password could produce an update Android would trust.

#### 3. Load signing secrets for one PowerShell session

Gradle reads these environment variables. The secure prompt avoids showing the
password while it is entered; closing the PowerShell window clears the
session-scoped variables.

```powershell
$env:POKEMON_KEYSTORE_PATH = 'C:\secure\pokemon-family-release.jks'
$env:POKEMON_KEY_ALIAS = 'pokemon-family'

$pokemonSigningPassword = Read-Host 'Family signing password' -AsSecureString
$pokemonSigningPlaintext = [System.Net.NetworkCredential]::new(
  '',
  $pokemonSigningPassword
).Password
$env:POKEMON_KEYSTORE_PASSWORD = $pokemonSigningPlaintext
$env:POKEMON_KEY_PASSWORD = $pokemonSigningPlaintext
```

PKCS12 uses the same password for the keystore and private key.

#### 4. Build and record the certificate

Build the first durable APK with the permanent key and final update URL:

```powershell
Set-Location C:\Code\chavez-pokemon

flutter build apk --release `
  --dart-define=APP_UPDATE_MANIFEST_URL=https://poke.chaveznet.dev/latest.json

$apkSigner = Get-ChildItem `
  "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse `
  -Filter apksigner.bat |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $apkSigner.FullName verify --verbose --print-certs `
  .\build\app\outputs\flutter-apk\app-release.apk
```

Copy the reported `certificate SHA-256 digest` into the password manager, then
set it for publishing:

```powershell
$env:POKEMON_RELEASE_CERT_SHA256 = '<64-character digest from apksigner>'
```

The publisher refuses a release signed by any other certificate.

#### 5. Install the first permanent build

The first permanently signed APK is the root of the update chain.

- If Pokémon Adventure is not installed on the device, install this APK
  normally.
- If a debug-signed copy is installed, Android cannot update it with the new
  certificate. Preserve any trainer data first, uninstall the debug copy, then
  install the permanent build.

The app does not yet have trainer backup/restore. Do not uninstall an existing
family-device copy with progress until that data can be safely preserved. The
emulator can be reset without affecting the future family update chain.

After this first install, every release must retain the application ID
`com.chavezfamily.pokemon_adventure`, use the same key, and increase
`versionCode`.

### Serve updates over HTTPS

Release builds reject plain HTTP update URLs. Put the files behind an HTTPS
reverse proxy with a certificate trusted by the tablet. Debug builds permit
HTTP for local emulator testing only.

The web server must serve `latest.json` and the APK.

## Release manifest

See [latest.example.json](homelab/latest.example.json).

```json
{
  "schemaVersion": 1,
  "packageName": "com.chavezfamily.pokemon_adventure",
  "versionCode": 2,
  "versionName": "1.1.0",
  "apkUrl": "pokemon-adventure-1.1.0-2.apk",
  "sha256": "64 lowercase hexadecimal characters",
  "sizeBytes": 123456789,
  "title": "More Pokémon fun",
  "notes": [
    "New discoveries to explore",
    "Friendlier battle tips"
  ]
}
```

`versionCode` controls update ordering and must increase for every release.
`versionName` is the friendly label. A relative `apkUrl` resolves beside the
manifest. The app rejects malformed manifests, APKs larger than 750 MiB,
unexpected sizes, and checksum mismatches.

## Publish a build

Increase the version in `pubspec.yaml`. Both parts matter; for example,
`1.0.1+2` means display version `1.0.1` and Android version code `2`.

Use the combined release command:

```powershell
.\tool\release_homelab_update.ps1 `
  -Title "More Pokémon fun" `
  -Notes "New discoveries to explore","Friendlier battle tips"
```

The command reads the version from `pubspec.yaml`, prompts locally for the
family signing password if it is not already loaded, builds with the HTTPS
manifest URL, and pins the signature to the APK currently served by the
homelab. The password is not written to disk.

The dedicated Docker container mounts that release directory read-only. The
publisher copies the versioned APK first and moves the completed `latest.json`
into place last, so devices never see a manifest pointing to a missing file.
Before publishing, the script reads the APK itself and refuses to continue if
its package name, `versionName`, or `versionCode` differs from the command. It
also refuses a `versionCode` that does not increase over `latest.json`. Nginx
serves the new release immediately without a restart.

## Android's first-update permission

On Android 8 and newer, the first update opens **Allow from this source** for
Pokémon Adventure. An adult enables it, returns to the app, and taps
**I allowed it—continue**. Android then displays its normal update confirmation.
This permission is per app and can be revoked later in Android settings.

## Emulator test

For an HTTP server running on the development PC, Android Emulator reaches the
host as `10.0.2.2`. Debug builds allow this:

```powershell
flutter run `
  --dart-define=APP_UPDATE_MANIFEST_URL=http://10.0.2.2:6983/latest.json
```

The test APK must have a higher version code and use the same debug signing key.
