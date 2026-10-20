# MyStreamFlix — Android TV, MX-style Player, Settings & About

## Android TV build

GitHub → Actions → **MyStreamFlix Flutter Android TV APK** → **Run workflow**.

Artifact: `MyStreamFlix-Android-TV-ARM64-APK` containing `app-release.apk`.

The TV workflow generates Flutter platforms, retains the existing Android network
permissions, modifies **only its own checkout** for the TV launcher, validates
TV metadata, runs analysis/tests and builds a dedicated ARM64 TV APK.

- Leanback launcher category and `android.software.leanback` feature.
- `android.hardware.touchscreen` is **not required**.
- TV banner image and forced landscape launcher Activity.
- `ANDROID_TV=true` enables 7-item side navigation and always-visible TV playback controls.
- Player remote: Left/Right seek (default 10s); center/Enter play/pause;
  Up/Down move focus into the control row. The volume slider can be operated
  with D-pad after focusing it. Standard Flutter focus traversal lets the remote
  navigate controls and menus.
- For 32-bit-only older TV boxes, an ARM32 artifact would require a separately
  tested build target; the supplied workflow is **ARM64 only**.

The existing **Android APK** and **Windows Desktop** workflows remain separate
and are unaffected by `configure_android_tv.py`.

## New navigation

Side navigation on Windows/TV: Home → Movies → Series → Live TV → My List →
**Settings** → **About**. On small phones, the same seven-item list is in the
hamburger drawer; the five frequent destinations remain in the bottom bar.

All platforms have a **Refresh content** button in the top app bar. Settings
also has **Refresh all content**. No mock content is substituted when sources fail.

## MX-style player

This is an **MX-inspired UI**, not MX Player's proprietary player engine.
It is built on the existing cross-platform `media_kit`/MPV backend.

- On-screen seek bar, time and duration, play/pause, configurable skip,
  fullscreen on phone/desktop, aspect fit/fill, playback speed and volume.
- Embedded audio language selection from `player.state.tracks.audio` via
  `player.setAudioTrack(...)`.
- Embedded subtitle selection via `player.setSubtitleTrack(...)`; when available,
  subtitle URLs from existing media metadata appear under external subtitles.
- Double-tap on left/right half of video skips backward/forward.
- TV builds start with the player in landscape full-video mode.
- No transcoding or invented audio. Dual audio **only** works if the media
  actually contains/exposes multiple audio tracks supported by media_kit/MPV.
  Some servers provide alternate video links rather than embedded audio; users
  choose those via the existing stream/source chooser.
- Transport/codec, server headers, DRM and external-host limitations still apply.

## Settings

- Content server, refresh, Live TV source navigation.
- Autoplay on/off, default speed (0.5–2.0x), skip interval (10/15/30s),
  video fit/fill, subtitles enabled/disabled by default, preferred audio
  language auto/English/Hindi/Bangla/Korean/Turkish.
- Reset preferences (does not clear My List or Live TV URL overrides).
- Saved using `SharedPreferences`; Android dependency is still pinned to
  `shared_preferences_android: 2.4.28` to avoid the previously reported crash.

## About

Developer: **Md Jahidul Islam**. App name, version, platform list and source
configuration explanation included.

## Build/testing limitations

Flutter/Dart SDK is not installed in the authoring runtime, so `flutter analyze`,
`flutter test`, real APK and Windows builds, remote focus and native track playback
cannot be executed locally. Python checks cover the manifest, banner and ZIP
structure; run the workflows to verify actual builds and test with a dual-audio
media file you have permission to use.
