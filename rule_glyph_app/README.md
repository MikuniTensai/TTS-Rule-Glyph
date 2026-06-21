# Rule Glyph Lab

Rule Glyph Lab is a Flutter grid-puzzle game built around rule/glyph mechanics. The project includes a solo campaign, local network co-op modes for 2, 3, and 4 players, synthesized runtime audio, local progress storage, and JSON-backed level assets.

## Requirements

- Flutter SDK with Dart 3.x
- Android Studio/Xcode or the platform toolchain for the target you build

## Run

```sh
flutter pub get
flutter run
```

The app is designed for landscape play.

## Test And QA

```sh
flutter analyze
flutter test
```

The test suite includes engine smoke tests, targeted regressions for spikes and lasers, and schema checks for compiled and JSON level dimensions.

## Level Data

The main level source is:

- `assets/levels.json`

The web editor writes this file automatically when you run `..\run_web.bat` from the outer `rule_glyph_app` folder and edit a campaign level. Flutter now loads this JSON directly, so Android builds use the same data as the web preview.

Split runtime level assets are still kept under:

- `assets/levels/solo/chap*/`
- `assets/levels/coop/2p/`
- `assets/levels/coop/3p/`
- `assets/levels/coop/4p/`

They are regenerated automatically before Android packaging. The compiled fallback data is in `lib/data/levels_data.dart`.

Useful scripts:

```sh
dart run bin/generate_json.dart
dart run bin/split_json.dart
```

Android release builds run `bin/split_json.dart` automatically, so after editing levels from the web you can build the AAB directly:

```sh
flutter build appbundle --release
```

## Local Network Multiplayer

Local network mode uses TCP sockets on the same LAN. Release builds need network permissions/entitlements:

- Android: `android.permission.INTERNET`
- iOS: local network usage description in `Info.plist`
- macOS: network client/server entitlements

No analytics, ads, cloud sync, or external game servers are used by this project.

## Android Release Signing

For store builds, create `android/key.properties` outside version control:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

Then build:

```sh
flutter build appbundle --release
```

Without `android/key.properties`, the Gradle file falls back to debug signing for local release smoke builds only. Do not submit debug-signed artifacts to a store.
