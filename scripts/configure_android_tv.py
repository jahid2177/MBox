#!/usr/bin/env python3
"""Apply Android TV launcher properties for the dedicated Android TV CI build.

Called AFTER `flutter create` and BEFORE `flutter build apk`. It is intentionally
not called in the phone workflow, so phones keep their normal launcher setup.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

manifest = Path(__file__).resolve().parents[1] / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Missing AndroidManifest.xml: run flutter create first')
ns = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ns)
attr = lambda key: f'{{{ns}}}{key}'
tree = ET.parse(manifest)
root = tree.getroot()

def feature(name: str, required: str):
    e = next((e for e in root.findall('uses-feature') if e.get(attr('name')) == name), None)
    if e is None:
        e = ET.Element('uses-feature')
        root.insert(0, e)
    e.set(attr('name'), name)
    e.set(attr('required'), required)

feature('android.software.leanback', 'true')
feature('android.hardware.touchscreen', 'false')
app = root.find('application')
if app is None:
    raise SystemExit('No application in manifest')
app.set(attr('banner'), '@drawable/tv_banner')
activity = app.find('activity')
if activity is None:
    raise SystemExit('No main activity in manifest')
activity.set(attr('screenOrientation'), 'landscape')
intent = next((e for e in activity.findall('intent-filter') if any(
    c.get(attr('name')) == 'android.intent.category.LAUNCHER'
    for c in e.findall('category'))), None)
if intent is None:
    raise SystemExit('No existing launcher intent in manifest')
if not any(e.get(attr('name')) == 'android.intent.category.LEANBACK_LAUNCHER'
           for e in intent.findall('category')):
    ET.SubElement(intent, 'category', {attr('name'): 'android.intent.category.LEANBACK_LAUNCHER'})
tree.write(manifest, encoding='unicode', xml_declaration=True)
print('Android TV manifest configured: leanback launcher, banner, no-touchscreen, landscape')
