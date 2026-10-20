# MBox Android TV Static Analysis Fix

**Log:** `logs_106920604869.zip`  
**GitHub source:** `jahid2177/MBox`, commit `8cab1625a9a54780142623ecf71c6952bc9aeac9`  
**Affected:** `lib/screens/settings_screen.dart`, `lib/state/app_state.dart`

## লগে পাওয়া সমস্যা

1. `settings_screen.dart:3:8` — `unused_import`
2. `settings_screen.dart:122:32` — `curly_braces_in_flow_control_structures`
3. `app_state.dart:244:44` — `body_might_complete_normally_nullable`

`flutter analyze --no-fatal-infos`-এ Warning থাকলে Exit Code 1 আসে। তাই Android TV APK Build শুরু হয়নি। অন্যদিকে `shared_preferences_android 2.4.28` সঠিকভাবে resolve হয়েছে।

## সবচেয়ে সহজ সমাধান — Patch Script

১. আপনার **বর্তমান MBox Repository**-এর রুটে `apply_fix.py` রাখুন (এই পুরোনো MyStreamFlix ZIP দিয়ে `MBox` Replace করবেন না)।  
২. আপনার PC বা Codespaces Terminal-এ চালান:

```bash
python3 apply_fix.py
flutter analyze --no-fatal-infos
```

৩. Script দুটো Dart ফাইলে নির্দিষ্ট অংশ পরিবর্তন করবে। আগের ফাইলের `.bak` backup থাকবে। এরপর `lib/screens/settings_screen.dart` ও `lib/state/app_state.dart` GitHub-এ Commit করুন।

## GitHub Editor দিয়ে সরাসরি ঠিক করতে চাইলে

**`lib/screens/settings_screen.dart`** থেকে এই লাইন মুছে দিন:

```dart
import '../state/app_state.dart';
```

এক লাইনের `mounted` check-কে পরিবর্তন করুন:

```dart
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Player settings reset')),
  );
}
```

**`lib/state/app_state.dart`**-এ `resetPlayerPreferences()`-এর `_saveLocalSettings((prefs) async { ... });` callback-এর `for` লুপ শেষে `return null;` যুক্ত করুন:

```dart
await _saveLocalSettings((prefs) async {
  for (final key in [
    'player_speed', 'player_seek_seconds', 'player_autoplay',
    'player_subtitles', 'player_fill_video', 'player_audio_language',
  ]) {
    await prefs.remove(key);
  }
  return null;
});
```

## এরপর

- **Actions → Android TV → Run workflow** চালান।
- এই সংশোধন কেবল লগে পাওয়া Static Analysis সমস্যা লক্ষ্য করে করা। Flutter/Android SDK-তে এখানে সম্পূর্ণ APK Build পরীক্ষা করা হয়নি।
- এটি Live TV JSON HTTP 404 বা APK-এর প্লেব্যাক সংক্রান্ত সমস্যা সমাধানের দাবি নয়।
