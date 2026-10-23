# MBox Android TV 32-bit/64-bit Crash — Build Fix

বর্তমান GitHub `jahid2177/MBox`-এর `.github/workflows/android-tv-apk.yml`-এ `--target-platform android-arm64` আছে, যেটি শুধু ARM64 APK তৈরি করে। এই আপডেট নতুন **MBox Android TV 32-bit and 64-bit APK** Workflow যোগ করে। **পুরোনো Android/TV/Windows workflow সরানোর দরকার নেই।**

## GitHub-এ যোগ করুন

নতুন এই ফাইলগুলো একই path-এ Upload/Commit করুন:

1. `.github/workflows/android-tv-32bit.yml`
2. `scripts/check_android_tv_apks.py`
3. `scripts/collect_tv_crash.bat` (Windows PC থেকে optional debugging)

তারপর GitHub → Actions → `MBox Android TV 32-bit and 64-bit APK` → `Run workflow`।

Build সফল হলে দুটি আলাদা Artifact পাওয়া যাবে:

- `MBox-AndroidTV-32bit-armeabi-v7a` → Extract করে `app-armeabi-v7a-release.apk` ইনস্টল করুন (32-bit TV)।
- `MBox-AndroidTV-64bit-arm64-v8a` → Extract করে `app-arm64-v8a-release.apk` ইনস্টল করুন (64-bit TV)।

**সতর্কতা:** GitHub Artifacts ZIP আকারে ডাউনলোড হয়—APK ফাইলটি Extract করে TV-তে নিন। আগের app-signature/package conflict হলে Android `INSTALL_FAILED_UPDATE_INCOMPATIBLE` দেখাবে। সে ক্ষেত্রে নতুন APK-এর signing ঠিক করুন অথবা পুরোনো App Uninstall করতে হতে পারে (Uninstall করলে local favorites/settings মুছে যেতে পারে)।

## TV সত্যিই 32-bit কি না পরীক্ষা

ADB দিয়ে TV-তে কানেক্ট করে:

```sh
adb shell getprop ro.product.cpu.abilist
adb shell getprop ro.build.version.sdk
```

যদি `armeabi-v7a,armeabi` আসে এবং `arm64-v8a` না থাকে, 32-bit APK প্রয়োজন। যদি `arm64-v8a` থাকে, ডিভাইস 64-bit APK চালাতে সক্ষম হতে পারে। Android SDK level 24-এর নিচে হলে বর্তমান Flutter SDK সাপোর্ট নাও করতে পারে।

**ইনস্টল সফল হয়ে Launch-এ crash হলে ABI-ই একমাত্র কারণ নয়।** Startup plugin failure, native media engine, OS/API support, বা app code exception-এর কারণেও এমন হয়। এটি নিশ্চিত করতে logcat চাই।

## TV-র Startup Crash Log সংগ্রহ করুন

Windows-এ Android SDK Platform Tools ইনস্টল করে `adb devices` দিয়ে TV কানেক্ট করুন। WiFi debugging সমর্থিত হলে TV-তে Developer Options → USB/Wireless debugging enable করুন; TV-এর নির্দেশনা অনুযায়ী Pair/Connect করুন।

App-এর package খুঁজুন:

```bat
adb shell pm list packages | findstr mystreamflix
```

তারপর:

```bat
scripts\collect_tv_crash.bat com.mystreamflix.mystreamflix_flutter
```

অথবা Linux/macOS:

```sh
adb logcat -c
adb shell am force-stop com.mystreamflix.mystreamflix_flutter
adb shell monkey -p com.mystreamflix.mystreamflix_flutter 1
sleep 10
adb logcat -d -b main -b system -b crash -v time > mbox_tv_startup_log.txt
```

Package ID ভিন্ন হলে আপনার আসল Package ID ব্যবহার করুন। `mbox_tv_startup_log.txt` এবং `tv_device_abis.txt` দিলে `FATAL EXCEPTION`/native `SIGSEGV`/`UnsatisfiedLinkError`-এর বাস্তব কারণ চিহ্নিত করা যাবে।

## Build যাচাই

Workflow-র শেষে `check_android_tv_apks.py` প্রতিটি APK-এর সঠিক ABI-এর `libflutter.so`, `libapp.so` যাচাই করবে এবং অন্য ABI আছে কি না দেখবে। এতে **Build Package** পরীক্ষা হয়; TV-তে App সত্যিই চলবে কি না তা Build সফল হলেও নিশ্চিত হয় না।

- Server 1/2 JSON URL, Netflix UI, player ও app-state Dart file পরিবর্তন করা হয়নি।
- Existing NDK retry logic, Analyze, Test, TV Manifest check রাখা হয়েছে।
- পুরোনো Workflow এখনো `ARM64` Build করবে, নতুন Workflow-তে 32-bit APK নিন।
