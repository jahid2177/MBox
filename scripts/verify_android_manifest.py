#!/usr/bin/env python3
"""Fail CI if the generated Android release manifest blocks remote catalog access."""
from pathlib import Path
import xml.etree.ElementTree as ET

manifest = Path(__file__).resolve().parents[1] / 'android/app/src/main/AndroidManifest.xml'
root = ET.parse(manifest).getroot()
ns = '{http://schemas.android.com/apk/res/android}'
permissions = {e.get(f'{ns}name') for e in root.findall('uses-permission')}
if 'android.permission.INTERNET' not in permissions:
    raise SystemExit('ERROR: Android release manifest missing INTERNET permission')
application = root.find('application')
if application is None or application.get(f'{ns}usesCleartextTraffic') != 'true':
    raise SystemExit('ERROR: Catalog poster/video URLs may use HTTP; cleartext option absent')
print('Android manifest check passed: INTERNET and HTTP image/stream access configured.')
