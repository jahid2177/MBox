# MBox Feature Update — Android / Android TV / Windows

এই ZIP-এ সরাসরি পুরোনো `player_screen.dart` দেওয়া হয়নি। আপনার বর্তমান MBox Repository-এর উন্নত 483-line MX-style Player অক্ষত রাখতে একটি safe Python patch ও automated GitHub workflow দেওয়া হয়েছে।

## নতুন সুবিধা

1. **MBOX intro animation:** অ্যাপ খোলার পর ২.২ সেকেন্ডের কালো/লাল সিনেমাটিক intro, তারপর Home। কোনো Demo API নেই।
2. **Sort:** Movies ও Series-এ ডিফল্ট `Year: Newest first` এবং 2026, 2025, ... বছরভিত্তিক poster rows। Year unknown হলে শেষে। Dropdown থেকে Oldest, A–Z বা Rating বেছে নেওয়া যায়।
3. **Settings:** শুধু `Live TV source`-এর link/tile অপসারিত; Live TV screen-এর URL edit button এবং content server switch অক্ষত।
4. **Player Back:** ভিডিওর ওপর title-এর বাম পাশে Back button; fullscreen ও TV-তে একই।
5. **Exit confirmation:** Android/Android TV-এর root Back এবং Windows window X চাপলে Exit/Cancel dialog।
6. **Player controls:** Android/mobile-এ বাম দিকে vertical swipe = app brightness, ডান দিকে swipe = player volume; সব platform-এর player toolbar-এ Brightness slider; পূর্বের media_kit Volume/Audio/Subtitle/Speed/Seek controls অক্ষত। Brightness application-scoped (device-wide system brightness নয়) এবং player ছাড়লে reset হয়।

## সবচেয়ে সহজ পদ্ধতি: GitHub Actions

ZIP থেকে নিচের ফাইলগুলো **হুবহু পাথ** অনুযায়ী Repository-তে Upload ও Commit করুন:

- `scripts/apply_mbox_features.py`
- `lib/screens/mbox_splash_screen.dart`
- `lib/utils/catalog_sort.dart`
- `test/catalog_sort_test.dart`
- `.github/workflows/apply-mbox-ui-features.yml`

GitHub → Actions → **Apply MBox UI Features** → Run workflow। Workflow patch চালাবে, `flutter pub get`, `dart format`, `flutter analyze --no-fatal-infos`, test সফল হলে সংশোধিত মূল ফাইলগুলো Commit করবে। তারপর আপনার আগের Windows, Android ও Android TV Build চালান। Repo Settings → Actions → General → Workflow permissions-এ Contents write permission অনুমোদিত থাকতে হবে।

## বিকল্প: নিজের PC-তে

Repository-এর root-এ ZIP-এর ফাইলগুলো কপি করে চালান:

```powershell
python scripts/apply_mbox_features.py
flutter pub get
dart format lib test/catalog_sort_test.dart
flutter analyze --no-fatal-infos
flutter test test/catalog_sort_test.dart
```

পরে `pubspec.yaml`, `lib/main.dart`, `lib/screens/shell_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/player_screen.dart` এবং নতুন ফাইলগুলো Commit করুন।

## সতর্কতা

- এটি বর্তমান Netflix-style MBox repository-এর পরিচিত source markers-এর ওপর patch; source বদলে থাকলে **আধাআধি সম্পাদনা না করে** clear error দেখাবে। এমন হলে নতুন source পাঠান।
- GitHub JSON content/source URLs পরিবর্তন করা হয় না। আগের 404 JSON লিংক এই আপডেট ঠিক করে না।
- Flutter SDK এখানে পাওয়া যায়নি; GitHub Actions-এ `flutter analyze`, test ও APK Build দিয়ে ফল যাচাই করতে হবে।
- Windows-এ close confirmation `window_manager` দিয়ে; Android/iOS brightness `screen_brightness` plugin দিয়ে। Windows brightness plugin সমর্থন ডিভাইসের ওপর নির্ভরশীল; কাজ না করলে warning থাকবে।
