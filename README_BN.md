# MBox Windows / Android / Android TV — flutter analyze fix

## সমস্যার কারণ

তিনটি Build-ই একই Flutter `lib/` সোর্স ব্যবহার করে। বর্তমান `MBox`-এ:

1. `lib/screens/settings_screen.dart`: unused `../state/app_state.dart` import
2. একই ফাইলে Snackbar দেখানোর `if (context.mounted)`-এ `{}` নেই
3. `lib/state/app_state.dart`: preference reset-এর async callback-এ explicit return নেই

`flutter analyze --no-fatal-infos` Warning-এ exit code 1 দেয়।

## সহজ পদ্ধতি: GitHub Actions থেকে সরাসরি সোর্স Fix

1. ZIP খুলে `.github/workflows/fix-mbox-analyzer.yml` এবং `scripts/fix_mbox_analyzer.py` ফাইল দুটি **একই path-এ** MBox GitHub Repository-তে আপলোড ও Commit করুন।
2. GitHub → Actions → **Fix MBox Flutter Analyze (All Platforms)** → **Run workflow** নির্বাচন করুন।
3. এই Workflow দুটি Dart ফাইলের সংশোধন **নিজে Commit এবং Push** করবে। শুধু Script upload করলে সমস্যা ঠিক হয় না।
4. নতুন Commit হয়েছে নিশ্চিত করে Windows, Android APK ও Android TV তিনটি Build আবার Run করুন।

GitHub Actions-এর `GITHUB_TOKEN` write access বন্ধ থাকলে Repository Settings → Actions → General → Workflow permissions থেকে Read and write permissions অনুমোদন দিতে হতে পারে। Branch protection থাকলে সরাসরি push ব্যর্থ হবে; সে ক্ষেত্রে স্থানীয় পদ্ধতি ব্যবহার করুন অথবা PR মার্জ করুন।

## বিকল্প পদ্ধতি: নিজের PC থেকে Fix

প্রজেক্টের root directory-তে দুটি ফাইল upload/copy করে চালান:

```bash
python3 scripts/fix_mbox_analyzer.py
flutter analyze --no-fatal-infos
git add lib/screens/settings_screen.dart lib/state/app_state.dart
git commit -m "fix: resolve MBox analyzer warnings"
git push
```

Windows PowerShell-এ `python` ব্যবহার করতে হতে পারে।

## গুরুত্বপূর্ণ

- Original Player, TV UI, JSON server URL, Android/Windows Workflow পরিবর্তন করা হয় না।
- Fix script একাধিকবার চালালে duplicate পরিবর্তন করবে না।
- এই প্যাকেজের Python patch-এর fixture tests চালানো হয়েছে; Flutter SDK না থাকায় প্রকৃত Flutter Analyze / APK/EXE Build যাচাই করা যায়নি।
- ভবিষ্যতে সোর্সের গঠন বদলালে Script অনুমান করে Code পরিবর্তন না করে error দেখাবে।
