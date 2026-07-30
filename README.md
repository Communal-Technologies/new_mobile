# communal_mobile

Communal mobile app (Flutter).

## Prerequisites

- **Flutter SDK** matching `pubspec.yaml`'s `environment.sdk` constraint (currently `^3.8.1`). Run `flutter doctor` and resolve any platform-specific gaps before continuing.
- For Android builds: Android Studio + the SDK / NDK versions Gradle picks up automatically.
- For iOS builds: Xcode + CocoaPods (`sudo gem install cocoapods`).

## First-time setup

### 1. Install dependencies + run codegen

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`build_runner` generates `lib/injection.config.dart` from `@injectable` annotations. Re-run it any time you add or change DI annotations. For interactive iteration, use `dart run build_runner watch --delete-conflicting-outputs` instead.

### 2. Build-time config (`--dart-define`)

Sensitive values are passed at build time, **not** bundled into `assets/` (see audit M2). Copy the template, fill in your values, and keep the file out of git:

```sh
cp tool/dart_defines.example.json tool/dart_defines.json
$EDITOR tool/dart_defines.json   # set BASE_URL, APP_ENV, GOOGLE_MAPS_API_KEY
```

`tool/dart_defines.json` is gitignored. The example template is committed.

Recognized keys:

| Key | Required | Notes |
|---|---|---|
| `APP_ENV` | yes | `development`, `staging`, or `production`. Selects which API base URL is used. |
| `BASE_URL` | only when `APP_ENV=development` | Your local / preview API. Ignored for staging / production (they use the hardcoded URLs in `lib/core/constants/constants.dart`). |
| `GOOGLE_MAPS_API_KEY` | yes (for any screen using maps / geocoding) | Same value you put in `android/local.properties`. The Android manifest-side key is consumed natively; this Dart-side copy is consumed by the geocoder helpers. |

### 3. Android Maps API key (`android/local.properties`)

The Google Maps key is no longer hardcoded in `AndroidManifest.xml` (see audit M1). The Android Gradle build reads `MAPS_API_KEY` from `android/local.properties` (gitignored) or the `MAPS_API_KEY` env var:

```sh
echo "MAPS_API_KEY=your-restricted-android-key" >> android/local.properties
```

The key **must** be restricted in Google Cloud Console to this app's package name + signing certificate SHA-1 — anything checked into the manifest is public-by-design once it's in source control.

### 4. iOS pods (iOS only)

```sh
cd ios && pod install && cd -
```

### 5. Firebase (mobile push)

`google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are not committed. Drop them into `android/app/` and `ios/Runner/` respectively before building, or have CI fetch them from secrets.

## Running the app (debug)

```sh
flutter run --dart-define-from-file=tool/dart_defines.json
```

To target a specific device:

```sh
flutter devices                                                 # list
flutter run -d <device-id> --dart-define-from-file=tool/dart_defines.json
```

For non-development environments, point `--dart-define-from-file` at a different JSON file:

```sh
flutter run --dart-define-from-file=tool/dart_defines.staging.json
flutter run --dart-define-from-file=tool/dart_defines.production.json
```

(Both files are gitignored by the `tool/dart_defines.*.json` rule.)

## Building for release

All release builds need both inputs: `tool/dart_defines.<env>.json` for Dart-side config and `MAPS_API_KEY` in `android/local.properties` (or env) for the native Maps SDK.

### Android APK

```sh
flutter build apk --release \
  --dart-define-from-file=tool/dart_defines.production.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

### Android App Bundle (Play Store)

```sh
flutter build appbundle --release \
  --dart-define-from-file=tool/dart_defines.production.json
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

> The release `signingConfig` is currently the debug keystore (`android/app/build.gradle.kts`). Replace it with a real release keystore + `key.properties` before publishing.

### iOS

```sh
flutter build ios --release \
  --dart-define-from-file=tool/dart_defines.production.json
```

Then archive in Xcode (`open ios/Runner.xcworkspace`) and upload via Organizer.

## Useful commands

```sh
flutter analyze                           # static analysis
flutter test                              # unit / widget tests
dart run build_runner build --delete-conflicting-outputs   # regenerate DI
flutter clean && flutter pub get          # nuke build cache
```

## CI hint

GitHub Actions can write the gitignored config files at job start from secrets:

```sh
echo "$DART_DEFINES_JSON_B64"   | base64 -d > tool/dart_defines.json
echo "$GOOGLE_SERVICES_JSON_B64" | base64 -d > android/app/google-services.json
echo "MAPS_API_KEY=$MAPS_API_KEY" >> android/local.properties
```
