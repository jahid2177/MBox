# User JSON source integration — 2026-10-18

The attached `README(1).md` is the authoritative source for all media URLs.

| Server | Live-TV feeds | Movie categories | Series categories |
|---|---:|---:|---:|
| Server 1 | 1 | 3 | 5 |
| Server 2 | 1 | 6 | 3 |

- Config: `assets/sources/catalog_sources.json`; 19 feed references (18 distinct URL strings), preserving original user input.
- Catalog parser: `lib/services/external_catalog_service.dart`. Supports title-keyed Movie lists, `links` stream arrays, TV series episode grouping by `season`/`episode`, and nested Live-TV listings.
- Source selector: `lib/screens/shell_screen.dart`; local server preference in `lib/state/app_state.dart`.
- Local Favorites work without accounts; remote login/CMS are optional and use a separately deployed original Next.js API.
- Media playback uses the *remote stream link found in JSON*, not demo files. The app cannot fix dead links or bypass DRM, login requirements or domain restrictions.
- Failed category URLs are displayed as warnings; failed Live TV JSON is displayed as a refreshable error.
- The user-supplied Server 2 snippet had an extra comma after `Animation`; normalized valid JSON is bundled. All URL strings are preserved.

Source verification limitations: tested a sample of the GitHub raw feeds via web retrieval. Movie/series JSON format was confirmed, but the supplied live TV URLs could not be successfully retrieved. Stream media playback was not tested.

Build verification: Flutter/Dart SDK is unavailable in this environment. GitHub Actions remains the authoritative compile and platform test path. No successful build is claimed.
