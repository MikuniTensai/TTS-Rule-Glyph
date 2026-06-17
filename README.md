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

Runtime level assets live under:

- `assets/levels/solo/chap*/`
- `assets/levels/coop/2p/`
- `assets/levels/coop/3p/`
- `assets/levels/coop/4p/`

The compiled fallback data is in `lib/data/levels_data.dart`. Keep JSON and compiled data in sync when editing levels.

Useful scripts:

```sh
dart run bin/generate_json.dart
dart run bin/split_json.dart
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
