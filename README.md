# MyStreamFlix — Flutter/Dart • User JSON servers

This is an updated Flutter/Dart version of **MyStreamFlix**. It uses only the JSON catalog sources in the supplied `README(1).md`, not sample/demo film or TV links.

## Content sources (no Next.js backend needed)

Edit `assets/sources/catalog_sources.json` to manage the supplied lists. The app reads this asset, fetches the live-TV feed and each Movie and Series category from GitHub raw JSON, and parses the remote entries into streaming items.

| Server | Live TV | Movie categories | Series categories |
|---|---|---:|---:|
| Server 1 | `LiveTV/live_tv.json` | Hollywood, Bollywood, Indian Bangla (3) | English, Korean, Hindi, Bangla, Turkish (5) |
| Server 2 | `live_tv.json` | Hollywood, Bollywood, Hindi Dubbed, Indian Bangla, Korean, Animation (6) | English, Hindi Dubbed, Hindi TV (3) |

**All 19 user-supplied JSON URLs have been preserved verbatim.** The trailing comma after the final item of Server 2 `movie_categories` in the original README was fixed while generating valid JSON.

- No `DEMO_MODE` or demo movie links. A missing or unreachable URL produces a visible error instead of substituted content.
- Switch between **Server 1 / Server 2** in the top toolbar; the choice persists locally.
- Refresh to fetch the latest source data; category failure does not block other successful categories. Loaded batches become visible while remaining sources are fetched.
- The `links` array holds movie stream alternatives; series use `season` and `episode` grouping; use the source chooser to pick alternatives. `media_kit` plays supported MP4, HLS, MKV streams.
- My List persists locally even without signing in.
- Search and dynamically generated source category filters are provided; Show More loads additional movie cards.

**Live TV feeds caveat:** during source review, both `jahid2177/Mydemoproject` live-TV URLs failed to load from the web retrieval environment. The app keeps your exact URLs and displays errors if the server returns HTTP 404 or is unavailable. Verify that the files are public and paths/case are correct. The live parser supports map/list JSON with nested categories, `url`, `stream_url`, and `links`, but the exact Live TV feed shape has not been independently verified.

**Streaming caveat:** a valid JSON feed does not guarantee the underlying media URL is reachable, playable, or licensed for redistribution. External HTTP media hosts may block hotlinking, require headers, use expiring links, or return incompatible codecs. The app does not proxy, cache or bypass access controls.

## Setup Windows

```powershell
.\scripts\setup_windows.ps1
flutter analyze
flutter test
flutter run -d windows
```

## Android setup

```bash
bash scripts/setup_unix.sh
flutter analyze
flutter test
flutter run -d <device-id>
flutter build apk --release --split-per-abi
```

For Android, `scripts/configure_android.py` adds INTERNET permission and allows cleartext HTTP traffic because some supplied media links are HTTP. Prefer HTTPS in the data sources; HTTP streams are not encrypted.

## GitHub Actions

The workflows `.github/workflows/android-apk.yml` and `windows-desktop.yml` generate missing native platform files, analyze, test, build and upload artifacts. Put the contents of this project at the **repository root** and run workflows under Actions.

`flutter` and `dart` were not available in the authoring environment, so the project was not compiled locally. Run GitHub Actions to verify compilation and device playback.

## Optional login / Next.js backend

The supplied GitHub JSON endpoints are static content feeds, **not authentication or database backends**. App browsing, playback and local Favorites work without Next.js, Prisma, Firebase, or sign-in.

For optional original account/profile/admin functions, provide a secure compatible Next.js deployment and pass both:

```bash
flutter run -d windows --dart-define=ENABLE_ACCOUNTS=true --dart-define=API_BASE_URL=https://YOUR-OWN-BACKEND.example
```

**Security:** do not publicly deploy the original Next.js backend before fixing the exposed admin header bypasses documented in `docs/SOURCE_ANALYSIS.md`. Admin CMS modifies the optional Next.js database, not the read-only GitHub raw JSON lists.

Use only video/channel feeds that you have permission to distribute.

When applying the **changed-files-only** ZIP over an older build, delete `assets/demo/catalog.json` from the old repository as well. The complete updated ZIP already omits this file.

## Live TV: fixing HTTP 404 on Server 1 / Server 2

Both live_tv.json URLs provided in `assets/sources/catalog_sources.json` were checked and returned 404 on 2026-10-19.
The app cannot display TV channels without a working source file. This build adds **Live TV → Change Live TV URL**:

1. In GitHub, find the actual public live TV JSON file and use **Raw** to copy its URL.
2. Switch to the correct server in the app. Open the Live TV page and press the antenna/settings icon or **Change Live TV URL**.
3. Paste the new URL, press **Verify & Save**, and the app checks whether it contains playable channel entries before saving.
4. The URL is saved for that server on the local device. A separate URL can be saved for Server 2.

There is **no invented/demo channel fallback**. Restore original resets back to the original URL, which still requires a fix in GitHub. See `docs/LIVE_TV_HTTP_404_FIX.md`.

### Android content loading troubleshooting (October 2026)

This version includes a checked-in Android manifest with release INTERNET permission, per-source incremental loading, background JSON parsing and category-specific errors. See [docs/ANDROID_CONTENT_LOADING_FIX.md](docs/ANDROID_CONTENT_LOADING_FIX.md). The user-supplied Live TV URLs may still return HTTP 404; an accessible Live TV JSON feed is needed to display those channels. No demo content was substituted.


### Android release app initialization fix (2026-10-20)

The `shared_preferences_android` dependency is pinned to `2.4.28` to avoid an Android release-only JNI/R8 crash involving `SharedPreferencesApiRegistrar.getAll`. The Android build workflow checks the resolved version. See `docs/ANDROID_SHARED_PREFERENCES_CRASH_FIX_2026-10-20.md`.
