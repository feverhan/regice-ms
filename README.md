# Fridge Inventory

A Flutter-based fridge inventory app with local storage and optional AI features.

## Current Architecture

This repository now has two layers:

- Flutter mobile client
  - Main entry: `lib/main.dart`
  - App structure: `lib/app.dart`
  - Pages: `lib/pages/`
  - Models: `lib/models/`
  - Services: `lib/services/`
  - Reusable UI: `lib/widgets/`
- Android host project for Flutter
  - Path: `android/`

The Android app is no longer a WebView shell.

## Current Features

- Local inventory storage in JSON
- Add, edit, delete, and adjust item quantity
- Expiry tracking
- Low-stock tracking
- Shopping list generation
- Export inventory JSON
- In-app AI settings
- Daily advice via a Qwen-compatible API
- Recipe generation via a Qwen-compatible API
- Natural-language bulk import via a Qwen-compatible API

## Local Development

Prerequisites:

- Flutter stable
- Android SDK
- Java 17

Install dependencies:

```bash
flutter pub get
```

Run analysis:

```bash
flutter analyze
```

Run on a device or emulator:

```bash
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## GitHub Actions

The repository includes a workflow that builds the Flutter Android APK:

`/.github/workflows/android-apk.yml`

The workflow does this:

1. Checks out the repository
2. Sets up Java 17
3. Installs Flutter stable
4. Runs `flutter pub get`
5. Runs `flutter analyze`
6. Builds the debug APK
7. Uploads the APK artifact

Artifact name:

`fridge-inventory-debug-apk`

See also:

- `GITHUB_ACTIONS_ANDROID.md`
- `ANDROID_APP.md`

## AI Configuration

AI features are configured inside the app, not through build-time environment variables.

Inside the app, open settings and provide:

- API key
- Model name
- One or more compatible base URLs

Default URLs are configured for DashScope-compatible endpoints.

## Legacy Files

The repository still contains legacy Flask/web files such as:

- `app.py`
- `templates/`
- `static/`

They are no longer the primary Android client path.

## Notes

- This repository has not been fully compiled in the current environment because Flutter and Android SDK are not installed here.
- The Android build report file under `android/build/reports/` may change when Gradle runs locally or in CI.
