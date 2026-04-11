# Flutter Android App

This repository now uses Flutter for the Android client.

Key points:

- The app is no longer a WebView shell.
- The UI is implemented in Flutter under `lib/main.dart`.
- Android exists as the Flutter host project under `/android`.
- GitHub Actions can build the debug APK automatically.

Main project files:

- `pubspec.yaml`
- `lib/main.dart`
- `.github/workflows/android-apk.yml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/regicems/app/MainActivity.kt`

Local build flow:

1. Install Flutter stable.
2. Run `flutter pub get`.
3. Run `flutter build apk --debug`.

Output:

`build/app/outputs/flutter-apk/app-debug.apk`

Current app capabilities:

- Local inventory storage
- Add, edit, delete, and adjust item quantity
- Low-stock and expiry tracking
- Shopping list generation
- JSON export
- AI settings inside the app
- Daily advice, recipe generation, and bulk import via a Qwen-compatible API

GitHub Actions:

See `GITHUB_ACTIONS_ANDROID.md` for the workflow details.
