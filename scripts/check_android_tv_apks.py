#!/usr/bin/env python3
"""Validate MBox TV split APKs contain the required Flutter native libraries."""
from pathlib import Path
import sys
from zipfile import BadZipFile, ZipFile


def check_apk(path_string: str) -> bool:
    path = Path(path_string)
    expected_abi = (
        "armeabi-v7a" if "armeabi-v7a" in path.name
        else "arm64-v8a" if "arm64-v8a" in path.name
        else None
    )
    if expected_abi is None:
        print(f"FAIL: unknown ABI in APK filename: {path.name}")
        return False
    if not path.is_file():
        print(f"FAIL: APK not found: {path}")
        return False
    try:
        with ZipFile(path) as archive:
            names = set(archive.namelist())
            native_prefix = f"lib/{expected_abi}/"
            expected = {f"{native_prefix}libflutter.so", f"{native_prefix}libapp.so"}
            missing = expected - names
            other_abis = sorted({p.split('/')[1] for p in names if p.startswith('lib/') and p.count('/') >= 2 and p.split('/')[1] != expected_abi})
            if missing:
                print(f"FAIL: {path.name} missing {sorted(missing)}")
                return False
            if other_abis:
                print(f"FAIL: {path.name} includes unexpected ABIs: {other_abis}")
                return False
            native_libs = sorted(p for p in names if p.startswith(native_prefix) and p.endswith('.so'))
            print(f"PASS: {path.name} ({path.stat().st_size / (1024*1024):.1f} MiB)")
            print(f"ABI: {expected_abi}; native libraries: {len(native_libs)}")
            print("    " + ", ".join(p.rsplit('/', 1)[-1] for p in native_libs[:18]))
            return True
    except (OSError, BadZipFile) as exc:
        print(f"FAIL: cannot inspect {path}: {exc}")
        return False


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/check_android_tv_apks.py app-armeabi-v7a-release.apk [app-arm64-v8a-release.apk]")
        return 2
    return 0 if all([check_apk(path) for path in sys.argv[1:]]) else 1


if __name__ == '__main__':
    raise SystemExit(main())
