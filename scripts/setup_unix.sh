#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name mystreamflix_flutter --org com.mystreamflix --platforms=android,ios,windows .
python3 scripts/configure_android.py
python3 scripts/rename_mbox.py --generated-only
flutter pub get
dart run flutter_launcher_icons
echo 'Flutter project initialized.'
