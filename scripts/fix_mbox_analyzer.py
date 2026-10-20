#!/usr/bin/env python3
"""Fix the three MBox flutter analyze issues in the checked-out repository.

Changes only lib/screens/settings_screen.dart and lib/state/app_state.dart.
Fails safely if the source no longer matches the reviewed structure.
Idempotent: safe to execute more than once.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = ROOT / 'lib' / 'screens' / 'settings_screen.dart'
STATE = ROOT / 'lib' / 'state' / 'app_state.dart'


def update_settings(source: str) -> tuple[str, list[str]]:
    notes = []
    # Dart analyzer explicitly identified this import as unused in SettingsScreen.
    new_source, removed = re.subn(
        r"(?m)^[ \t]*import[ \t]+['\"]\.\./state/app_state\.dart['\"];[ \t]*\n",
        '', source, count=1,
    )
    if removed:
        notes.append('Removed unused app_state.dart import')

    # Cover both the line-122 and line-159 versions of the same Snackbar code.
    pattern = re.compile(
        r'(?P<indent>^[ \t]*)if[ \t]*\([ \t]*context\.mounted[ \t]*\)'
        r'[ \t\r\n]*(?P<statement>ScaffoldMessenger\.of\(context\)\.showSnackBar\('
        r'[\s\S]*?\)\s*\)\s*;)',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(new_source))
    if len(matches) > 1:
        raise RuntimeError('More than one mounted Snackbar statement; refusing ambiguous change')
    if matches:
        def wrap(match: re.Match[str]) -> str:
            indent = match.group('indent')
            statement = match.group('statement').strip()
            # Indent continuation lines consistently inside the new if block.
            lines = statement.splitlines()
            lines = [lines[0].strip()] + [line.strip() for line in lines[1:]]
            return (indent + 'if (context.mounted) {\n'
                    + '\n'.join(indent + '  ' + line for line in lines)
                    + '\n' + indent + '}')
        new_source = pattern.sub(wrap, new_source, count=1)
        notes.append('Wrapped context.mounted Snackbar in braces')
    elif not re.search(r'if\s*\(\s*context\.mounted\s*\)\s*\{', new_source):
        raise RuntimeError('Could not locate SettingsScreen mounted-Snackbar block')
    return new_source, notes


def update_app_state(source: str) -> tuple[str, list[str]]:
    notes = []
    # Scope the fix to the playback-reset function; do not alter unrelated callbacks.
    start = re.search(r'Future\s*<\s*void\s*>\s+resetPlayerPreferences\s*\(\s*\)\s*async\s*\{', source)
    if not start:
        raise RuntimeError('Could not locate resetPlayerPreferences()')
    segment = source[start.end():]
    pattern = re.compile(
        r'(?P<head>await\s+_saveLocalSettings\s*\(\s*\(\s*prefs\s*\)\s*async\s*\{)'
        r'(?P<body>[\s\S]*?)'
        r'(?P<indent>^[ \t]*)\}\s*\)\s*;',
        re.MULTILINE,
    )
    match = pattern.search(segment)
    if not match:
        raise RuntimeError('Could not locate async _saveLocalSettings in resetPlayerPreferences()')
    body = match.group('body')
    if 'prefs.remove(' not in body:
        raise RuntimeError('Preference-reset callback no longer removes stored keys')
    if not re.search(r'\breturn\s+null\s*;', body):
        indent = match.group('indent')
        fixed = (match.group('head') + body.rstrip() + '\n'
                 + indent + '  return null;\n' + indent + '});')
        segment = segment[:match.start()] + fixed + segment[match.end():]
        notes.append('Added explicit return null to preference reset callback')
    return source[:start.end()] + segment, notes


def main() -> None:
    for path in (SETTINGS, STATE):
        if not path.is_file():
            raise RuntimeError(f'Missing expected Dart file: {path}')
    old_settings = SETTINGS.read_text(encoding='utf-8')
    old_state = STATE.read_text(encoding='utf-8')
    settings, notes_settings = update_settings(old_settings)
    state, notes_state = update_app_state(old_state)

    # Safety validations before writing either file.
    assert "import '../state/app_state.dart';" not in settings
    assert re.search(r'if\s*\(\s*context\.mounted\s*\)\s*\{', settings)
    assert re.search(r'(?s)resetPlayerPreferences.*?return null\s*;', state)

    if settings != old_settings:
        SETTINGS.write_text(settings, encoding='utf-8')
    if state != old_state:
        STATE.write_text(state, encoding='utf-8')
    print('\n'.join('FIX: ' + n for n in (notes_settings + notes_state))
          or 'ALREADY FIXED: No Dart changes needed.')
    print('Files checked: lib/screens/settings_screen.dart, lib/state/app_state.dart')


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f'FIX FAILED (no unexpected replacements): {e}', file=sys.stderr)
        sys.exit(1)
