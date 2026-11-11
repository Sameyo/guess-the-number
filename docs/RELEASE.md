# Releasing to Google Play

## One-time: create the upload key

Run this once on your own computer and keep the file and passwords somewhere
safe (a password manager). If the key is lost, Google can reset it, but that
takes a support request.

```sh
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Google Play App Signing keeps the real app signing key. This upload key only
proves that an upload came from you.

## Local release builds

Create `android/key.properties` (it is git-ignored):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Then run `flutter build appbundle --release`. The bundle is written to
`build/app/outputs/bundle/release/app-release.aab`.

Without `key.properties`, release builds are signed with the debug key. They
install on a phone, but Google Play rejects them.

## CI release builds

Add these repository secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 upload-keystore.jks` (macOS: `base64 -i upload-keystore.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password |

After that, every CI run on `main` uploads two artifacts: `guess-the-number-aab`
(upload this to Play Console) and `guess-the-number-apk` (install this on a
phone).

The first time the APK switches from the debug key to the upload key, Android
refuses to install it over the old build. Uninstall the old build once, which
also clears local records and saved games.

## Every release

1. Bump `version` in `pubspec.yaml`. The number after `+` is the Android
   `versionCode` and must go up for every upload, for example `1.0.0+1` then
   `1.0.1+2`.
2. Merge to `main` and download the `guess-the-number-aab` artifact.
3. Upload it to a testing track in Play Console, then promote it.

## Icon and splash

The source images are in `assets/icon/`. After changing them, run:

```sh
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
