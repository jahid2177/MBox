#!/usr/bin/env python3
"""Idempotent INTERNET permission patch for generated Flutter Android manifests."""
from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'android/app/src/main/AndroidManifest.xml'
if not p.exists():
    raise SystemExit('Android project missing; first run: flutter create --platforms=android,ios,windows .')
s = p.read_text(encoding='utf-8')
permission = '<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    s = s.replace('<application', '    ' + permission + '\n    <application', 1)
# Some user-provided streams use HTTP (not HTTPS). Android blocks such media
# without an opt-in. No passwords/tokens are sent to those content hosts.
if 'android:usesCleartextTraffic=' not in s:
    s = s.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
s = s.replace('android:label="mystreamflix_flutter"', 'android:label="MyStreamFlix"')
p.write_text(s, encoding='utf-8')
print('Android INTERNET permission configured.')
