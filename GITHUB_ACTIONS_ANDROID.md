# GitHub Actions Build For Flutter APK

This repository now builds the Android app as a Flutter project.

Workflow file:

`/.github/workflows/android-apk.yml`

What it does:

1. Checks out the repository
2. Sets up Java 17
3. Installs Flutter stable
4. Runs `flutter pub get`
5. Runs `flutter analyze`
6. Builds a debug APK
7. Uploads the APK as a workflow artifact

Artifact path:

`build/app/outputs/flutter-apk/app-debug.apk`

How to use it:

1. Push the repository to GitHub.
2. Open the `Actions` tab.
3. Select `Build Flutter APK`.
4. Click `Run workflow`, or let it run automatically on push to `main` or `master`.
5. Download the `fridge-inventory-debug-apk` artifact after the workflow succeeds.

Notes:

- This is a Flutter APK, not a WebView shell.
- AI features require the user to enter a compatible API key inside the app.
- The workflow currently produces a debug APK only.

If you want, the next step can be:

1. Add release signing with GitHub Secrets
2. Build a release APK
3. Build an Android App Bundle (`.aab`) for store distribution
