# MBox — Netflix-inspired Flutter UI (Android / Windows / Android TV)

এটি **আপনার বর্তমান MBox GitHub প্রজেক্টে UI Replace করার জন্য** তৈরি, সম্পূর্ণ Backend বা Player পরিবর্তনের জন্য নয়।

## কী বদলেছে

- `lib/theme/app_theme.dart`: সিনেমাটিক প্রায়-কালো background, লাল accent, পরিষ্কার dark theme। পূর্বের ফাইলগুলো যাতে কাজ করে তার জন্য `AppColors.teal`-এর compatibility alias বজায় রয়েছে।
- `lib/screens/shell_screen.dart`: বড় Featured Hero, Netflix-inspired content rows, horizontal desktop/TV navigation, মোবাইলে bottom navigation + drawer, Search, Server Switch, Refresh, Settings/About।
- `lib/widgets/media_widgets.dart`: Poster cards, title/rating, focus border/scale এবং remote/keyboard focus।
- `lib/screens/detail_screen.dart`: Cinematic detail banner, Play, My List, genre/cast, episode list, stream source chooser।
- `lib/screens/live_screen.dart`: Live TV channel card layout, focus indication, error/URL change controls।

## GitHub-এ কীভাবে যুক্ত করবেন

এই ZIP-এর `lib/` ফোল্ডারটি আপনার **সর্বশেষ** `MBox` Repository-এর মূল ফোল্ডারে merge করে একই নামের পাঁচটি ফাইল replace করুন। অন্য ফাইল Replace করবেন না।

```
lib/theme/app_theme.dart
lib/widgets/media_widgets.dart
lib/screens/shell_screen.dart
lib/screens/detail_screen.dart
lib/screens/live_screen.dart
```

এরপর তিনটি Build চালান:

```
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --target-platform android-arm64
```

Android TV-এর জন্য আপনার আগের workflow-তে ব্যবহৃত `--dart-define=ANDROID_TV=true` ফ্ল্যাগ বজায় রাখবেন। Windows Workflow-ও আগেরটি ব্যবহার করবেন।

## কোনগুলো অপরিবর্তিত

- Server 1/Server 2-এর সব Movie, Series ও Live TV JSON URL
- JSON parsing, loading ও diagnostic logic
- Favorites/My List-এর local storage
- Login, Admin, Account API
- Settings, Player এবং streaming/episode backend code
- Android ও Android TV build workflows

**জরুরি:** আপনার আগে দেওয়া Live TV feed-এ 404 দেখা গিয়েছিল। শুধু ডিজাইন পরিবর্তন করলে অনুপস্থিত JSON ফাইল ফিরে আসবে না। Live TV কাজ করার জন্য সঠিক ও অ্যাক্সেসযোগ্য JSON URL দিতে হবে।

**পরীক্ষা সীমাবদ্ধতা:** ফাইলগুলোতে structural bracket ও import path পরীক্ষা করা হয়েছে। এই পরিবেশে Flutter SDK না থাকায় `flutter analyze`, Widget Test ও APK build বাস্তবে চালানো যায়নি।

নিজের ব্র্যান্ডিং MBOX রেখেই Netflix-inspired Layout করা হয়েছে; Netflix-এর কোনো logo বা copyright image কপি করা হয়নি। সব কনটেন্টের artwork অ্যাপের আসল JSON source থেকে নেওয়া হয়।
