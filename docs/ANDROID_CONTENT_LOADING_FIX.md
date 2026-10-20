# MyStreamFlix — Android app opens but no content loads

## Findings from source

- The project previously inserted `android.permission.INTERNET` only by running `scripts/configure_android.py` *after* `flutter create`. Builds made another way could omit the permission, especially in the **release** manifest.
- The code loaded JSON sources in batches and waited for each batch of three to finish before showing anything. Some category JSON files are large, and the two supplied Live TV URLs have shown HTTP 404, so a long wait could look like an empty app.
- `AppState.init()` previously had no outer error handler: an error while reading preferences or the bundled JSON manifest could leave the loading indicator running indefinitely.
- The user-supplied movie feeds are distinct from Live TV feeds. Their existing URLs remain unchanged. No sample/demo content was added.

## Changes

1. Added `android/app/src/main/AndroidManifest.xml` to source control. It includes INTERNET permission for release builds and allows HTTP for poster/video URLs provided in the user's catalogs. This is intentionally permissive; in production, HTTPS-only sources are preferable.
2. JSON sources now download concurrently (maximum three requests), with progress published as **each** feed completes. Working sources appear without waiting for failing/slow sources.
3. Large JSON parsing happens using Flutter's `compute` to avoid blocking Android UI during parsing.
4. Startup errors display an error message instead of leaving endless loading.
5. Home now shows a source warning banner; tap it to see the category-specific errors.
6. An automated test checks that a 404 Live TV feed does not stop Movies loading.

## Build on GitHub

- Upload all changed files, **including** `android/app/src/main/AndroidManifest.xml`.
- Run `Actions > MyStreamFlix Flutter Android APK > Run workflow`.
- Install the **new** generated APK; uninstall the old app first if necessary. Local favorites could be lost on uninstall.
- Start the app on an internet-connected phone and wait for the initial catalog. On the Home page, tap `sources unavailable` to inspect failures.

## If content still does not appear

1. Open the same user-supplied Movie JSON link in Chrome **on that same Android phone**. If Chrome fails, the phone/network cannot reach the content source.
2. Check the Android APK's effective release permissions: `aapt dump permissions app-release.apk` or `adb shell dumpsys package com.mystreamflix.mystreamflix_flutter | grep INTERNET` (the installed package may vary).
3. Capture app logs: `adb logcat -c`, launch the app, then `adb logcat -d -v time > streamflix-android-log.txt` and send the log with a screenshot of the Home source diagnostics. Avoid posting personal tokens or account details.
4. If the movie **titles show but posters do not**, some catalog poster URLs use plain HTTP and may also be unavailable due to host restrictions, mixed network conditions, or expired links.
5. If items show but do not **play**, that is a separate stream URL / video codec / network restriction issue; the catalog loading fix alone cannot guarantee playback.

## Status

Source files and ZIP integrity can be checked in this environment. A real Flutter Android build and playback test require Flutter/Android SDK and a device; they have **not** been confirmed here.
