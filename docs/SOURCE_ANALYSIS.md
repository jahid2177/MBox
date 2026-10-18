# Source Inspection — MyStreamFlix-main.zip

## Files and framework inventory

| Source folder | Observed stack | Function |
|---|---|---|
| `app/` | Next.js 15 API / App Router | Website pages and ~40 server route files |
| `src/` | React/TypeScript | Main website UI, streaming player, AdminCMS, catalogs |
| `mobile/` | Expo SDK 52 / React Native 0.76 | Separate Android/iOS client (8 components, 4 screens) |
| `tv/` | Android Java + Capacitor | Android TV WebView shell and focus scripts |
| `prisma/` | Prisma | SQL and MongoDB schema variants |
| `src/lib/data-service.ts` | TS | Hybrid Prisma/in-memory database |
| `src/lib/dummy-movies.json` | JSON | 99 sample content items, 49 movies, 50 series |
| `.github/workflows/` | GitHub Actions | Native-source Android and TV APK pipelines |

## Main product capabilities found

- Catalog: movies, episodic series, live channels, category filters, rankings, featured sections, hero and lists.
- Authentication: password login, registration, HttpOnly signed session cookie, viewer profiles, role-based capabilities.
- Media: MP4/HLS-like source URLs, subtitles, player controls, seek, playback speed, episode lists, resume/history routes.
- CMS: metadata CRUD, TMDB integrations, IPTV/GDrive import utilities, analytics, user management, settings.
- Monetization: free/VIP flags; Stripe, PayPal subscription routes; demo/sandbox flows.
- UI locales: English, Indonesian, Spanish in main project; separate mobile translations.

## Flutter architecture mapping

```
lib/
├── main.dart                 # Flutter app entry, AppScope
├── theme/app_theme.dart      # Colors and Material theme
├── models/app_user.dart      # User and profile data model
├── models/media_item.dart    # Movie, season, episode, subtitle adapters
├── services/api_service.dart # Existing Next.js REST endpoints + cookie jar
├── state/app_state.dart      # Catalog/auth/favorites global state
├── widgets/media_widgets.dart # Posters, rows, image fallbacks
└── screens/
    ├── shell_screen.dart     # Responsive nav, hero, search, category grids
    ├── detail_screen.dart    # Content metadata, seasons/episodes
    ├── live_screen.dart      # Live TV categories and channels
    ├── auth_screen.dart      # Login/registration
    ├── profile_screen.dart   # Viewer profiles and sign-out
    ├── player_screen.dart    # Native video + history
    ├── history_screen.dart   # Watch history listing
    └── admin_screen.dart     # Basic backend CRUD, users, roles
```

## Findings and differences

1. **Do not rename TSX into Dart.** Expo, Next.js/React and Flutter have different rendering and runtime models; Flutter UI is implemented natively in new Dart files.
2. **Backend remains Node.** A complete Dart backend conversion would require porting every API handler, Prisma query, storage processor and payment webhook separately, which this delivery does not claim to do.
3. **Original mobile frontend has insecure admin header injection** in `mobile/src/api/client.ts`. Corresponding backend routes accept known fixed header values (`app/api/movies/route.ts`, `app/api/movies/[id]/route.ts`, `app/api/users/route.ts`). The new Flutter client removes such headers. Server patch is still essential.
4. **Original client persisted serialized User locally without revalidating** the session when relaunching. The Flutter app checks `/api/auth/me` instead of trusting a stored local admin flag.
5. **`DELETE` helper in original mobile API** can return `{success: true}` even when server request fails. New Flutter client only treats successful HTTP response as success.
6. **Mixed demo and real content:** The backend supports in-memory dummy data and demo accounts. Flutter demo preview is explicit via `DEMO_MODE=true`, not silently presented as live content.
7. **The Android TV platform is separate.** Flutter Windows layout and Android mobile navigation are included, but TV remote focus and launcher configuration need their own implementation.
8. **Video URL/codec availability is server and format dependent.** The Flutter player cannot guarantee playback of DRM-restricted, geo-blocked, unlicensed or unauthorized streams.
9. **Subscriptions:** Because payments require trusted server/webhook logic, no Flutter-side fake payment success is implemented.
10. **Browser support:** This project targets Android/iOS/Windows. Persisted cookie storage uses `dart:io` and is not built for Flutter Web.

## Practical next steps

- Patch the server-side admin authorization vulnerabilities and rotate exposed secrets.
- Run Flutter generated-platform bootstrap, analyzer, unit tests and APK/Windows build in an SDK-enabled environment.
- Verify API parity with deployed backend (including session cookie attributes and domain).
- Test real authorized MP4, HLS and Live TV streams on device, then integrate missing scanners, payment checkout and profile/review enhancements.
- Design a separate Flutter Android TV target with remote-focus navigation, media keys and TV manifest/banner.
