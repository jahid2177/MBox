# MBox App Name Update — Android / Android TV / Windows

**লক্ষ্য:** ফোন/TV-তে Launcher App Name এবং Windows-এর Window Title/EXE নাম `MBox` করা।
**অপরিবর্তিত:** Flutter Dart package name `mystreamflix_flutter`, Android application ID, package namespace, server JSON, player, settings, 32-bit APK build.

## GitHub-এ সহজে আপডেট (GitHub Actions)

1. এই ZIP-এর `scripts/rename_mbox.py` এবং `.github/workflows/rename-mbox-app.yml` ফাইলগুলো MBox Repository-এর **একই path**-এ আপলোড করুন ও Commit করুন।
2. GitHub → **Actions → Set MBox App Name → Run workflow** চালান।
3. Workflow বর্তমান Repository-তে `AndroidManifest.xml`, `scripts/configure_android.py`, Setup Scripts ও `flutter create`-সম্পর্কিত Build Workflows সংশোধন করে Commit করবে।
4. এরপর Android APK, Android TV (32-bit/64-bit), Windows Desktop—প্রতিটির নতুন Build চালান।
5. Android-এ পুরোনো অ্যাপ Uninstall না করেই নতুন APK Update হিসেবে ইনস্টল করা উচিত (যদি signing key/package ID একই থাকে)।

## সরাসরি Android App Name বদলাতে

ZIP-এর `android/app/src/main/AndroidManifest.xml` ফাইলটি একই path-এ Replace করলেও Android launcher নাম MBox হবে। কিন্তু `scripts/configure_android.py` ও Windows runner পুনর্জেনারেশনে যাতে পুরোনো নাম ফিরে না আসে, Auto Update Script-ও ব্যবহার করতে হবে।

## Windows-এ নিজে চালাতে

```powershell
python scripts/rename_mbox.py
.\scripts\setup_windows.ps1
flutter build windows --release
```

## Android-এ নিজে চালাতে

```bash
python3 scripts/rename_mbox.py
bash scripts/setup_unix.sh
flutter build apk --release --split-per-abi
```

## যাচাই

Android APK: `aapt dump badging app-release.apk` কমান্ডে `application-label:'MBox'` দেখাবে।
Windows: Build Release ফোল্ডারে `MBox.exe` থাকবে এবং উইন্ডোর নাম MBox হবে।

**সীমাবদ্ধতা:** Flutter SDK না থাকায় এখানে APK/EXE চালিয়ে পরীক্ষা করা হয়নি। Repo branch protection বা restricted GITHUB_TOKEN থাকলে Actions workflow commit করতে নাও পারবে; সেক্ষেত্রে স্থানীয়ভাবে `python scripts/rename_mbox.py` চালিয়ে ফাইলগুলো নিজে commit করুন।
