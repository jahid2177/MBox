# MyStreamFlix Flutter — Dart / Flutter Port

This is a **new Flutter client project** based on the user-supplied `MyStreamFlix-main.zip` source code (Next.js website/backend + Expo mobile app + Capacitor/Java Android TV). It is a **Flutter implementation of the streaming viewer and basic admin flows**, not an automatic line-by-line TS-to-Dart translation or a Dart rewrite of the original Node backend.

## What is implemented

- Responsive dark cinematic UI (mobile and Windows desktop), Home with featured title, trending rows and top-rated rows.
- Movies / TV Series tabs, genre filters, search, artwork, metadata and episode lists.
- Live TV browse/channel groups and stream playback route.
- My List local demo favorites, or server-backed favorites for signed-in accounts.
- Sign in, registration and persistent HTTP session cookies, validated by `/api/auth/me`; logout clears the cookie jar.
- Profiles: display, create and switch; watch history listing. Admin screen access is gated on server-reported admin role.
- Admin CMS: catalog and Live TV browsing, create/edit/delete basic content, user role management and account removal.
- `media_kit` video playback (MP4 / HLS / formats supported by native media libraries), pause, seek, speed and full screen; periodic watch-history submission.
- Sample **preview-only** catalog extracted from the supplied dummy content (`--dart-define=DEMO_MODE=true`). In demo mode, account management is disabled; sample movie metadata does **not** assert actual film streams are licensed or authentic.
- Custom launcher icons copied from supplied mobile source. GitHub Actions: Android release APK (split per ABI) and Windows desktop zip artifact directory.
- Unit tests for the movie JSON adapter.

## What is NOT yet 1:1

The source project has ~40 Next.js API handlers and much broader web Admin CMS capabilities. This Flutter port **does not yet** include Stripe/PayPal checkout flows, subtitle selector/editor, TMDB import UI, IPTV scanner, Google Drive scan and proxy tools, complete analytics charts, user reviews, video DRM, Android TV remote focus UX or a TV build. Full Netflix-style 1:1 visual parity and production-grade playback reliability across all stream formats have not been verified. Advanced series import/edit is also not included in the basic admin editor. See `docs/SOURCE_ANALYSIS.md`.

## Requirements

- Flutter stable installed, Dart 3.5+ and Android SDK to build APK. For Windows, Windows 10/11 with Visual Studio C++ desktop tools.
- A **running compatible MyStreamFlix Next.js backend**, accessible via HTTPS for real authentication, favorites, CRUD and streams.
- The archive includes **Flutter Dart sources and bootstrap scripts** rather than generated native `android/`, `ios/`, and `windows/` folders. This environment does not include the Flutter SDK; platform templates need to be generated once by Flutter using the setup command below.

> **2026-10-18 CI fix:** The incompatible generated `MyApp` widget test has been replaced with `test/widget_test.dart`, and related analyzer findings were addressed. See [`docs/BUILD_LOG_FIX_2026-10-18.md`](docs/BUILD_LOG_FIX_2026-10-18.md). The amended code still requires a fresh CI build to verify native compilation.

## First-time setup (Windows)

```powershell
# From this extracted project folder, with Flutter in PATH:
.\scripts\setup_windows.ps1
flutter doctor
flutter analyze
flutter test
flutter run -d windows --dart-define=API_BASE_URL=https://YOUR-BACKEND.example
```

## First-time setup (Android / macOS / Linux)

```bash
bash scripts/setup_unix.sh
flutter doctor
flutter run -d <device-id> --dart-define=API_BASE_URL=https://YOUR-BACKEND.example
# For Android emulator use HTTPS publicly hosted API or http://10.0.2.2:3000 locally.
# HTTP in Android may be blocked by OS network security; HTTPS is recommended.
```

## Demo mode (UI and catalog without a running backend)

```bash
flutter run -d <device-id> --dart-define=DEMO_MODE=true
```

Poster images in demo use internet-hosted references from the **original** sample dataset. Sample stream URLs may be unplayable or point to unrelated demonstration videos. This is a UI preview, **not** a production content library.

## Build APK / Windows

```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://YOUR-BACKEND.example
flutter build windows --release --dart-define=API_BASE_URL=https://YOUR-BACKEND.example
```

For GitHub Actions, push **contents of this Flutter project as the repository root**, run `Android APK` or `Windows Desktop` under Actions. Set repository variable `API_BASE_URL` (Settings → Secrets and variables → Actions → Variables). Binary artifacts are attached to completed runs. The Android workflow produces a debug-key-signed **release-mode** artifact for development/testing; configure your own signing keys for Google Play distribution.

## API and session design

`lib/services/api_service.dart` uses Dio and `PersistCookieJar`. The original backend issues an HttpOnly session cookie upon sign-in and registration. Flutter sends the cookie on subsequent requests; the backend must validate authorization on every protected endpoint. An admin role in the mobile UI alone does **not** secure an API.

| Action | API |
|---|---|
| Browse / detail | `GET /api/movies`, `GET /api/movies/:id` |
| Authenticate | `POST /api/auth/login`, `/register`, `/logout`; `GET /api/auth/me` |
| Favorites | `GET/POST /api/user/favorites`, `DELETE /api/user/favorites/:movieId` |
| History | `POST /api/user/history` |
| Profiles | `POST /api/auth/profile/create`, `/switch` |
| Admin content | `POST /api/movies`, `PUT/DELETE /api/movies/:id` |
| Admin users | `GET /api/users`, `PUT /api/users/:id/role`, `DELETE /api/users/:id` |

### Important security warning about the supplied backend

Several supplied Next.js admin routes permit fixed `x-admin-pin`, `x-admin-key` or other header values **instead of securely checking the logged-in user's role**. Some accept arbitrary `Authorization: Bearer ...` headers. These bypasses are a **critical vulnerability**. The Flutter port never sends or embeds those backdoor headers, but the backend remains vulnerable until the server routes are patched. **Do not publicly deploy the original backend without removing the header bypasses, auditing every privileged endpoint and rotating any exposed credentials.** It also contains demo-account behavior and simulated payments. Production subscriptions must be verified server-side via real provider webhooks.

## Other notes

- This project has **not been compiled here** because Flutter/Dart SDKs are not installed in the provided workspace. Run `flutter analyze`, `flutter test`, and the Actions workflows in an SDK-enabled environment.
- The original ZIP is needed to deploy the backend; the Flutter project does not contain a Next.js server, Prisma database or real movie files.
- Publish only content you have the right to distribute. Do not log in with production credentials to an untrusted clone server.
