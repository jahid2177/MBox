#!/usr/bin/env python3
"""Idempotent MBox display-name fix across generated Flutter platform files.

Run once after adding this file to the MBox repository:
    python3 scripts/rename_mbox.py

Subsequent GitHub Actions builds run:
    python3 scripts/rename_mbox.py --generated-only

Keep pubspec.yaml's internal `name`, Android applicationId / Kotlin namespace,
and Flutter create --project-name untouched to avoid breaking package imports.
"""
from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OLD_BRANDS = ("MyStreamFlix", "myStreamFlix", "mystreamflix_flutter")


def write_if_changed(path: Path, content: str) -> bool:
    if not path.is_file():
        return False
    old = path.read_text(encoding="utf-8")
    if old == content:
        return False
    path.write_text(content, encoding="utf-8")
    print(f"UPDATED: {path.relative_to(ROOT)}")
    return True


def transform(path: Path, fn) -> bool:
    if not path.is_file():
        return False
    original = path.read_text(encoding="utf-8")
    return write_if_changed(path, fn(original)) if fn(original) != original else False


def update_android_manifest():
    path = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not path.is_file():
        print("SKIP: AndroidManifest.xml not generated yet")
        return

    def replace_label(match: re.Match[str]) -> str:
        tag = match.group(0)
        if re.search(r'android:label\s*=\s*[\"\']', tag):
            return re.sub(r'android:label\s*=\s*([\"\']).*?\1',
                          'android:label="MBox"', tag, count=1)
        return tag[:-1] + ' android:label="MBox">'

    transform(path, lambda s: re.sub(r'<application\b[^>]*>', replace_label, s, count=1, flags=re.S))


def update_windows():
    main = ROOT / "windows/runner/main.cpp"
    def set_window_title(s: str) -> str:
        # Official Flutter Windows runner calls FlutterWindow::Create.
        s = re.sub(r'(window\.Create\(\s*L\")[^\"]*(\")',
                   r'\g<1>MBox\2', s, count=1)
        # Also handle older MFC/Win32 SetWindowText-style title literals.
        return s.replace('L"MyStreamFlix"', 'L"MBox"')
    transform(main, set_window_title)

    cmake = ROOT / "windows/CMakeLists.txt"
    def rename_exe(s: str) -> str:
        # Windows executable name; leave CMake project() and Dart package name unchanged.
        return re.sub(r'(?m)^(\s*set\(BINARY_NAME\s+")[^\"]+("\)\s*)$',
                      r'\g<1>MBox\2', s, count=1)
    transform(cmake, rename_exe)

    rc = ROOT / "windows/runner/Runner.rc"
    def brand_resource(s: str) -> str:
        for key in ("FileDescription", "ProductName", "InternalName"):
            s = re.sub(r'(VALUE\s+"' + key + r'"\s*,\s*")[^\"]*(")',
                       r'\g<1>MBox\2', s)
        s = re.sub(r'(VALUE\s+"OriginalFilename"\s*,\s*")[^\"]*(")',
                   r'\g<1>MBox.exe\2', s)
        return s
    transform(rc, brand_resource)


def update_ios():
    path = ROOT / "ios/Runner/Info.plist"
    if not path.is_file():
        return
    with path.open("rb") as f:
        data = plistlib.load(f)
    changed = False
    for key in ("CFBundleDisplayName", "CFBundleName"):
        if data.get(key) != "MBox":
            data[key] = "MBox"
            changed = True
    if changed:
        with path.open("wb") as f:
            plistlib.dump(data, f)
        print(f"UPDATED: {path.relative_to(ROOT)}")


def update_existing_project_files():
    configure = ROOT / "scripts/configure_android.py"
    def configure_mbox(s: str) -> str:
        s = s.replace('android:label="MyStreamFlix"', 'android:label="MBox"')
        s = s.replace("'android:label=\"mystreamflix_flutter\"', 'android:label=\"MyStreamFlix\"'",
                      "'android:label=\"mystreamflix_flutter\"', 'android:label=\"MBox\"'")
        return s
    transform(configure, configure_mbox)

    main = ROOT / "lib/main.dart"
    transform(main, lambda s: re.sub(r"(\btitle\s*:\s*['\"])(?:MyStreamFlix|mystreamflix_flutter)(['\"])",
                                      r'\g<1>MBox\2', s))

    unix = ROOT / "scripts/setup_unix.sh"
    if unix.is_file():
        s = unix.read_text(encoding="utf-8")
        hook = 'python3 scripts/rename_mbox.py --generated-only'
        if hook not in s and 'python3 scripts/configure_android.py' in s:
            s = s.replace('python3 scripts/configure_android.py',
                          'python3 scripts/configure_android.py\n' + hook, 1)
            write_if_changed(unix, s)

    ps = ROOT / "scripts/setup_windows.ps1"
    if ps.is_file():
        s = ps.read_text(encoding="utf-8")
        hook = 'python scripts/rename_mbox.py --generated-only'
        if hook not in s:
            marker = "if ($LASTEXITCODE -ne 0) { throw 'Android manifest configuration failed' }"
            if marker in s:
                s = s.replace(marker, marker + "\n  " + hook +
                              "\n  if ($LASTEXITCODE -ne 0) { throw 'MBox display name configuration failed' }", 1)
                write_if_changed(ps, s)

    # All CI workflows calling flutter create must update the newly-generated
    # Android / TV / Windows labels in the same run (especially Windows title).
    workflows = ROOT / ".github/workflows"
    if workflows.exists():
        for wf in sorted([*workflows.glob('*.yml'), *workflows.glob('*.yaml')]):
            if wf.name == 'rename-mbox-app.yml':
                continue
            s = wf.read_text(encoding='utf-8')
            if 'flutter create' not in s or 'rename_mbox.py --generated-only' in s:
                continue
            # Match GitHub Actions run: flutter create ... on one line.
            pattern = re.compile(r'(?m)^(?P<indent>[ \t]*)run:[ \t]*flutter create[^\r\n]*(?:\r?\n|$)')
            is_windows = bool(re.search(r'runs-on:\s*windows-', s))
            cmd = 'python scripts/rename_mbox.py --generated-only' if is_windows else 'python3 scripts/rename_mbox.py --generated-only'
            def insert_hook(m: re.Match[str]) -> str:
                indent = m.group('indent')
                # The following step should line up with the previous - name:.
                list_indent = indent[:-2] if len(indent) >= 2 else ''
                return (m.group(0).rstrip('\r\n') + '\n' + list_indent +
                        '- name: Apply MBox app name\n' + indent + 'run: ' + cmd + '\n')
            modified, count = pattern.subn(insert_hook, s, count=1)
            if count:
                write_if_changed(wf, modified)
            else:
                print(f"CHECK MANUALLY: {wf.relative_to(ROOT)} has flutter create in a multiline step")


def main():
    parser = argparse.ArgumentParser(description='Name Android/Android TV/Windows apps MBox')
    parser.add_argument('--generated-only', action='store_true',
                        help='Patch generated platform files only; do not modify repository scripts or workflow YAMLs')
    args = parser.parse_args()
    if not args.generated_only:
        update_existing_project_files()
    update_android_manifest()
    update_windows()
    update_ios()
    print('MBox display name update complete. Internal application/package IDs unchanged.')

if __name__ == '__main__':
    main()
