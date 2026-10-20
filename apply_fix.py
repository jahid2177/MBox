#!/usr/bin/env python3
"""Apply the three analyzer fixes from GitHub Actions run 106920604869.

Run from anywhere: python apply_fix.py /path/to/MBox
The script makes backups and refuses to modify an unexpected source layout.
"""
from pathlib import Path
import re
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) >= 2 else Path.cwd().resolve()
SETTINGS = ROOT / 'lib/screens/settings_screen.dart'
STATE = ROOT / 'lib/state/app_state.dart'


def create_updated_sources():
    try:
        original_settings = SETTINGS.read_text(encoding='utf-8')
        original_state = STATE.read_text(encoding='utf-8')
    except FileNotFoundError as exc:
        raise SystemExit(f'ERROR: Missing {exc.filename}. Run from the MBox project root or give its path.')

    settings = original_settings
    state = original_state
    fixed = []

    unused_import = "import '../state/app_state.dart';\n"
    if unused_import in settings:
        settings = settings.replace(unused_import, '', 1)
        fixed.append('settings_screen.dart: removed unused import')
    elif "import '../state/app_state.dart';" in settings:
        raise SystemExit('ERROR: unexpected settings import line ending')

    # Replace the one-line 'if' with a proper block, preserving the snackbar and the mounted check.
    old_mounted = (
        'if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(\n'
        "            const SnackBar(content: Text('Player settings reset')));"
    )
    new_mounted = (
        'if (context.mounted) {\n'
        '            ScaffoldMessenger.of(context).showSnackBar(\n'
        "              const SnackBar(content: Text('Player settings reset')));\n"
        '          }'
    )
    if old_mounted in settings:
        settings = settings.replace(old_mounted, new_mounted, 1)
        fixed.append('settings_screen.dart: mounted check now uses braces')
    elif not re.search(r'if\s*\(context\.mounted\)\s*\{', settings):
        raise SystemExit('ERROR: mounted-check source differs from the logged commit. Nothing changed.')

    # The callback returns FutureOr<Object?>; an async block must return a value
    # on every path. Returning null is valid and does not change preference removal.
    expression = re.compile(
        r'(await\s+_saveLocalSettings\s*\(\s*\(prefs\)\s+async\s*\{\s*'
        r'for\s*\(final\s+key\s+in\s*\[[\s\S]*?\]\)\s*\{\s*'
        r'await\s+prefs\.remove\(key\);\s*\})'
        r'(\s*)\}\);',
        re.MULTILINE,
    )
    matches = list(expression.finditer(state))
    if len(matches) == 1:
        match = matches[0]
        start_line = state.rfind('\n', 0, match.start()) + 1
        indent = re.match(r'\s*', state[start_line:match.start()]).group(0)
        replacement = match.group(1) + '\n' + indent + '  return null;\n' + indent + '});'
        state = state[:match.start()] + replacement + state[match.end():]
        fixed.append('app_state.dart: preference-reset callback explicitly returns null')
    elif len(matches) > 1:
        raise SystemExit('ERROR: found several matching preference reset blocks. Nothing changed.')
    elif not re.search(r'await\s+prefs\.remove\(key\);\s*}\s*return\s+null\s*;\s*}\);', state):
        raise SystemExit('ERROR: preference reset callback differs from the logged commit. Nothing changed.')

    for target, before, after in [(SETTINGS, original_settings, settings), (STATE, original_state, state)]:
        if before != after:
            backup = target.with_suffix(target.suffix + '.bak')
            if not backup.exists():
                backup.write_text(before, encoding='utf-8')
            target.write_text(after, encoding='utf-8')
    if fixed:
        print('Applied source fixes:')
        for change in fixed:
            print('  - ' + change)
    else:
        print('Already fixed: no changes necessary.')
    print('Next: flutter analyze --no-fatal-infos')


if __name__ == '__main__':
    create_updated_sources()
