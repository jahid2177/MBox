#!/usr/bin/env python3
"""CI guard against releasing a TV APK invisible in the TV launcher."""
from pathlib import Path
import xml.etree.ElementTree as ET
manifest = Path(__file__).resolve().parents[1] / 'android/app/src/main/AndroidManifest.xml'
root = ET.parse(manifest).getroot()
ns = '{http://schemas.android.com/apk/res/android}'
attrs = lambda n: f'{ns}{n}'
features = {e.get(attrs('name')): e.get(attrs('required')) for e in root.findall('uses-feature')}
assert features.get('android.software.leanback') == 'true', 'Missing Leanback feature'
assert features.get('android.hardware.touchscreen') == 'false', 'Touchscreen required'
app = root.find('application')
assert app is not None and app.get(attrs('banner')) == '@drawable/tv_banner', 'TV banner missing'
activity = app.find('activity')
assert activity is not None and activity.get(attrs('screenOrientation')) == 'landscape'
assert any(c.get(attrs('name')) == 'android.intent.category.LEANBACK_LAUNCHER'
           for f in activity.findall('intent-filter') for c in f.findall('category'))
assert (manifest.parent / 'res/drawable-nodpi/tv_banner.png').is_file(), 'TV banner PNG is missing'
print('Android TV launcher manifest verified')
