# MyStreamFlix Android: SharedPreferences JNI / R8 crash fix

## Screenshot symptom

`App initialization failed: PlatformException(PlatformException, java.lang.NoSuchMethodError: no non-static method "Lio/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar;.getAll(Ljava/lang/String;Ljava/util/List;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;" ... )`

This matches the known October 2026 regression in `shared_preferences_android` 2.5.0 in Android **release** builds. R8 rewrites method descriptors needed by JNI-based Pigeon registration. The app dies during startup settings reads, before it requests the movie and series JSON URLs.

## Changes

1. `pubspec.yaml`: directly pins the Android implementation to `shared_preferences_android: 2.4.28`. Do **not** change it to `^2.4.28`, which would allow 2.5.x again. Keep `shared_preferences` for the Dart API.
2. `android/app/proguard-rules.pro`: defensive keep rules for JNI/Pigeon Kotlin runtime types. These do not replace the pin until a verified upstream fix is available.
3. `lib/state/app_state.dart`: startup now continues loading catalogs even if local settings are unavailable; preferences saves are best-effort. Without working preferences, selections/favorites may not persist across restarts.
4. `.github/workflows/android-apk.yml`: verifies resolved Android plugin version before release APK compilation and includes Android native changes as trigger paths.

## GitHub actions

Upload all changed files at their **original relative paths**. Then rerun **MyStreamFlix Flutter Android APK** via Actions. The workflow executes `flutter pub get` and verifies version 2.4.28. Download and install the new APK on your device; do not test the prior APK.

## Local commands

```bash
flutter clean
flutter pub get
flutter pub deps --style=compact | grep shared_preferences_android
flutter build apk --release --split-per-abi --dart-define=ENABLE_ACCOUNTS=false
```

The version output must contain `shared_preferences_android 2.4.28`.

## Unrelated issue

A 404 response for Live TV JSON is a separate **source URL** problem. Correcting the Android preferences crash enables the app to reach network/catalog initialization; it does not repair missing server-hosted Live TV JSON files.

## Verification caveat

The modified sources, dependency pin, and ZIPs can be statically checked here. A Flutter SDK and Android device/emulator are required to verify `flutter pub get`, release compilation and on-device playback.

Technical references:
- https://pub.dev/packages/shared_preferences_android/changelog
- https://saymyframe.com/blog/shared-preferences-android-release-build-crash
