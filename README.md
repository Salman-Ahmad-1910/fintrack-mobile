# FinTrack ERP — Flutter mobile app

Mobile client for the FinTrack-ERP / Wasooli.pk Go (Gin) backend. It talks to
the same `/api/v1` REST API as the Next.js web app, so both share one database.

See `COMPLETION_REPORT.md` for the feature comparison, API list, known issues
and the backend problems found during the port.

## 1. Requirements (Windows)

- Flutter SDK (stable) with Dart ^3.13 — `flutter doctor` must be green for
  Android.
- Android Studio (Android SDK + an emulator) or a phone with USB debugging.

## 2. Configure the API server

The base URL lives in one place: `lib/core/api_config.dart` (`kDefaultBase`,
currently `https://103.99.136.68:8090/api/v1`). Override it without editing
code:

```powershell
flutter run --dart-define=API_BASE_URL=https://erp.example.com/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://erp.example.com/api/v1
```

Users can also tap the server address under the sign-in form to change it.

**HTTPS certificate (required for release builds).** A `build.sh --prod` Go
binary serves HTTPS on port 8090. If `TLS_CERT_FILE` / `TLS_KEY_FILE` are not
set, `main.go` generates a *self-signed certificate for localhost/127.0.0.1*,
which Android rejects (the app then shows a "certificate is not trusted"
message). Fix it on the server — never by disabling checks in the app:

- point a domain (e.g. `erp.example.com`) at the server and issue a Let's
  Encrypt certificate, then start the binary with
  `TLS_CERT_FILE=/path/fullchain.pem TLS_KEY_FILE=/path/privkey.pem`; or
- run the Go server in dev (HTTP) mode on localhost behind nginx/Caddy that
  terminates TLS with a valid certificate.

Release builds allow HTTPS only (`android/app/src/main/res/xml/network_security_config.xml`).
Debug/profile builds also allow plain HTTP so you can test against a LAN dev
server, e.g. `--dart-define=API_BASE_URL=http://192.168.1.10:8090/api/v1`.

## 3. Run on Windows

```powershell
cd fintrack-mobile
flutter pub get
flutter analyze
flutter test
flutter run            # pick the emulator/phone
```

## 4. Release APK

1. Create a keystore once:
   `keytool -genkey -v -keystore C:\keys\fintrack-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fintrack`
2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in the passwords/path (the file is git-ignored). Without it the release
   build is signed with the debug key — fine for testing, not for Play Store.
3. Build:
   ```powershell
   flutter build apk --release --dart-define=API_BASE_URL=https://erp.example.com/api/v1
   ```
   Output: `build\app\outputs\flutter-apk\app-release.apk`
   (use `flutter build apk --split-per-abi` for smaller per-device APKs).
4. Before publishing, change `applicationId` (`com.example.fintrack`) in
   `android/app/build.gradle.kts` to your own package name.
