# Android Release Signing — Keystore Reference

> **This file is safe to commit. It contains NO passwords.**
> Actual secrets (passwords, aliases) live in each flavor's gitignored
> `android/keystore/<flavor>/<flavor>_credentials.txt` and `<flavor>.properties`.

## How per-flavor signing works
Each brand flavor is signed with its OWN keystore. `android/app/build.gradle.kts`
loops the brand flavors and, for any flavor that has a
`android/keystore/<flavor>/<flavor>.properties` file, creates a matching
`signingConfig` and assigns it in `productFlavors`. Flavors WITHOUT their own
properties file fall back to the global `release` key (if `android/keystore.properties`
exists) or the `debug` key.

- Selection is automatic by **name match** — `--flavor pippro` uses
  `keystore/pippro/pippro.properties` → its `storeFile` (`pippro.jks`).
- Adding a new flavor needs ONLY a new `keystore/<flavor>/` folder + files —
  NO `build.gradle.kts` change.

## Folder layout
```
android/keystore/
├── <flavor>/
│   ├── <flavor>.jks               (gitignored — the signing key)
│   ├── <flavor>.properties        (gitignored — storeFile/passwords/alias)
│   └── <flavor>_credentials.txt   (gitignored — human-readable notes)
├── keystore.properties.example    (committed — template)
└── README.md                      (committed — this file)
```

## Flavors with their own keystore
| Flavor | Keystore path | Alias | Password convention |
|--------|---------------|-------|---------------------|
| pipze  | `android/keystore/pipze/pipze.jks`   | `pipze`  | `<flavor>@123` |
| baazex | `android/keystore/baazex/baazex.jks` | `baazex` | `<flavor>@123` |
| pippro | `android/keystore/pippro/pippro.jks` | `pippro` | `<flavor>@123` |

> Convention: store & key password = `<flavor>@123`, alias = `<flavor>`.
> Exact passwords are in each flavor's gitignored `<flavor>_credentials.txt`.

## Generate a keystore (new flavor)
```
keytool -genkey -v -keystore android/keystore/<flavor>/<flavor>.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias <flavor> \
  -storepass <flavor>@123 -keypass <flavor>@123 \
  -dname "CN=<flavor>, OU=<flavor>, O=<flavor>, L=NA, ST=NA, C=NA"
```
Then create `android/keystore/<flavor>/<flavor>.properties`:
```
storeFile=keystore/<flavor>/<flavor>.jks
storePassword=<flavor>@123
keyAlias=<flavor>
keyPassword=<flavor>@123
```

## Build an AAB at 1.0.0
```
flutter build appbundle --flavor <flavor> --build-name=1.0.0 --build-number=1
```
Output: `build/app/outputs/bundle/<flavor>Release/app-<flavor>-release.aab`

## Verify the signing key
```
unzip -l build/app/outputs/bundle/<flavor>Release/app-<flavor>-release.aab | grep 'META-INF/.*\.RSA$'
```
The signing block should be `META-INF/<FLAVOR>.RSA` (flavor name), NOT `META-INF/ANDROIDD.RSA`
(which would mean the debug key was used).

## Backup (IMPORTANT — do NOT put keystores in assets/)
`assets/` ships inside the APK/AAB and is committed to git, so keystores/passwords
there would become PUBLIC. Back up OUTSIDE the repo instead:
```
mkdir -p ~/keystore-backups/whitelabel
cp -R android/keystore/pipze android/keystore/baazex android/keystore/pippro ~/keystore-backups/whitelabel/
```
Or an encrypted zip for cloud/USB:
```
zip -er ~/keystore-backups-whitelabel.zip android/keystore/pipze android/keystore/baazex android/keystore/pippro
```
Also enable **Play App Signing** per app so Google can reset the upload key if a `.jks` is ever lost.

## Build environment note
Gradle requires **JDK 17** (set via `android/gradle.properties` → `org.gradle.java.home`).
JDK 25 fails with `java.lang.IllegalArgumentException: 25.0.2` before the script even evaluates.
