#!/usr/bin/env python3
"""Safely apply MBox feature changes to the current Netflix-style Flutter repo.

Run in the repository root: python3 scripts/apply_mbox_features.py
Stops instead of overwriting newer source when a known anchor has changed.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n == 1:
        return text.replace(old, new, 1)
    if n == 0 and new in text:
        return text  # rerunning an already applied patch
    raise RuntimeError(f'{label}: expected one matching anchor, found {n}. No changes saved.')


def apply(path: str, transform) -> None:
    target = ROOT / path
    original = target.read_text(encoding='utf-8')
    changed = transform(original)
    if changed != original:
        target.write_text(changed, encoding='utf-8')
        print('UPDATED', path)
    else:
        print('UNCHANGED', path)


def pubspec(src: str) -> str:
    for package, version in [('screen_brightness', '^2.1.11'),
                             ('window_manager', '^0.5.2')]:
        if not re.search(r'^  ' + re.escape(package) + r':', src, re.M):
            src = replace_once(src, '  media_kit: ', f'  {package}: {version}\n  media_kit: ',
                               'pubspec.yaml dependency marker')
    return src


def main(src: str) -> str:
    if "import 'screens/mbox_splash_screen.dart';" not in src:
        src = replace_once(src, "import 'screens/shell_screen.dart';",
            "import 'screens/shell_screen.dart';\nimport 'screens/mbox_splash_screen.dart';\n"
            "import 'dart:io' show Platform;\nimport 'package:window_manager/window_manager.dart';",
            'main.dart imports')
    if 'windowManager.setPreventClose(true)' not in src:
        src = replace_once(src, '  MediaKit.ensureInitialized();',
            '  MediaKit.ensureInitialized();\n'
            '  if (Platform.isWindows) {\n'
            '    await windowManager.ensureInitialized();\n'
            '    await windowManager.setPreventClose(true);\n'
            '  }', 'main.dart window setup')
    src = replace_once(src, "title: 'MyStreamFlix'", "title: 'MBox'", 'main.dart app title')
    src = replace_once(src, 'home: initialError == null ? const ShellScreen() : Scaffold(',
        'home: initialError == null\n'
        '      ? const MBoxSplashScreen(next: ShellScreen())\n'
        '      : Scaffold(', 'main.dart splash home')
    return src


def settings(src: str) -> str:
    # Remove the Live TV source tile, not the server selector or refresh tile.
    expr = (r'\s*const Divider\(height: 1\),\s*ListTile\(\s*'
            r'leading: const Icon\(Icons\.live_tv_outlined\),.*?'
            r'onTap: onOpenLiveTv,\s*\),')
    if "title: const Text('Live TV source')" in src:
        src, n = re.subn(expr, '', src, count=1, flags=re.S)
        if n != 1:
            raise RuntimeError('settings: failed to isolate Live TV source tile')
    src = replace_once(src, '  final VoidCallback onOpenLiveTv;\n', '',
                       'settings: callback field')
    # Two known current code styles (expanded and compact).
    if 'const SettingsScreen({super.key, required this.onOpenLiveTv});' in src:
        src = src.replace('const SettingsScreen({super.key, required this.onOpenLiveTv});',
                          'const SettingsScreen({super.key});', 1)
    elif 'const SettingsScreen({super.key, required this.onOpenLiveTv});' not in src:
        # multiline style
        src = re.sub(r'const SettingsScreen\(\{super\.key, required this\.onOpenLiveTv\}\);',
                     'const SettingsScreen({super.key});', src)
    if 'onOpenLiveTv' in src:
        raise RuntimeError('settings: residual onOpenLiveTv reference')
    return src


def shell(src: str) -> str:
    if "import '../utils/catalog_sort.dart';" not in src:
        src = replace_once(src, "import 'package:flutter/material.dart';",
            "import 'dart:io' show Platform;\n"
            "import 'package:flutter/material.dart';\n"
            "import 'package:flutter/services.dart';\n"
            "import 'package:window_manager/window_manager.dart';\n"
            "import '../utils/catalog_sort.dart';", 'shell: imports')
    src = replace_once(src, 'class _ShellScreenState extends State<ShellScreen> {',
        'class _ShellScreenState extends State<ShellScreen> with WindowListener {',
        'shell: window listener')
    if '  CatalogSort sort = CatalogSort.newest;' not in src:
        src = replace_once(src, '  int tab = 0;',
            '  int tab = 0;\n  CatalogSort sort = CatalogSort.newest;\n'
            '  bool _exitDialogOpen = false;', 'shell: sort and exit state')
    if '  Future<void> _confirmExit() async {' not in src:
        newmethods = '''  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
  }

  @override
  void onWindowClose() {
    _confirmExit();
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || !mounted) return;
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close MBox?'),
        content: const Text('Are you sure you want to exit MBox?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || leave != true) return;
    if (Platform.isWindows) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } else {
      await SystemNavigator.pop();
    }
  }

'''
        src = replace_once(src, '  @override\n  void dispose() {',
                           newmethods + '  @override\n  void dispose() {',
                           'shell: exit method insertion')
        src = replace_once(src, '    searchController.dispose();',
            '    if (Platform.isWindows) windowManager.removeListener(this);\n'
            '    searchController.dispose();', 'shell: listener dispose')
    src = replace_once(src, '5 => SettingsScreen(onOpenLiveTv: () => changeTab(3)),',
        '5 => const SettingsScreen(),', 'shell: remove settings link')
    if 'sort: sort,' not in src:
        src = replace_once(src, '        tab: tab,\n        search: search,',
            '        tab: tab,\n        sort: sort,\n'
            '        onSort: (next) => setState(() {\n'
            '          sort = next;\n'
            '          visibleLimit = 72;\n'
            '        }),\n        search: search,', 'shell: catalog sort state pass')
    if 'return PopScope<void>(' not in src:
        src = replace_once(src, '    return Scaffold(\n      drawer:',
            '    return PopScope<void>(\n'
            '      canPop: false,\n'
            '      onPopInvokedWithResult: (didPop, result) {\n'
            '        if (!didPop) _confirmExit();\n'
            '      },\n'
            '      child: Scaffold(\n      drawer:', 'shell: confirm exit popscope')
        src = replace_once(src, '    );\n  }\n}\n\nclass _DesktopNavigation',
                           '    ));\n  }\n}\n\nclass _DesktopNavigation',
                           'shell: close popscope')
    if '  final CatalogSort sort;' not in src:
        src = replace_once(src,
            'class _BrowseCatalog extends StatelessWidget {\n  final int tab;',
            'class _BrowseCatalog extends StatelessWidget {\n'
            '  final CatalogSort sort;\n'
            '  final ValueChanged<CatalogSort> onSort;\n'
            '  final int tab;', 'shell: catalog sorting members')
        src = replace_once(src,
            'const _BrowseCatalog({required this.tab, required this.search,',
            'const _BrowseCatalog({required this.tab, required this.sort,\n'
            '    required this.onSort, required this.search,',
            'shell: catalog constructor')
        src = replace_once(src,
            'final base = catalog.where((m) => tab == 0 ||\n'
            '      (tab == 1 ? !m.isSeries : m.isSeries)).toList();',
            'final base = sortCatalog(catalog.where((m) => tab == 0 ||\n'
            '      (tab == 1 ? !m.isSeries : m.isSeries)), sort);',
            'shell: sorted base')
        src = replace_once(src,
            'g.toLowerCase() == genre.toLowerCase()))).toList();',
            'g.toLowerCase() == genre.toLowerCase()))), sort);',
            'shell: selection sort')
        src = replace_once(src,
            'final selection = base.where((m) =>',
            'final selection = sortCatalog(base.where((m) =>',
            'shell: selection helper')
        src = replace_once(src,
            "final filtered = keyword.isNotEmpty || genre != 'All';",
            "final filtered = keyword.isNotEmpty || genre != 'All' ||\n"
            '        sort != CatalogSort.newest;', 'shell: sorted grid option')
        src = replace_once(src,
            "final genres = ['All', ...{for (final m in base) ...m.genres}];",
            "final genres = ['All', ...{for (final m in base) ...m.genres}];\n"
            '    final years = base.where((m) => m.releaseYear > 0)\n'
            '        .map((m) => m.releaseYear).toSet().toList()\n'
            '      ..sort((a, b) => b.compareTo(a));',
            'shell: year categories')
        src = replace_once(src,
            "              Text('${selection.length} titles',",
            "              PopupMenuButton<CatalogSort>(\n"
            "                tooltip: 'Sort movies and series',\n"
            "                initialValue: sort,\n"
            "                onSelected: onSort,\n"
            "                icon: const Icon(Icons.sort_rounded),\n"
            "                itemBuilder: (_) => CatalogSort.values\n"
            "                  .map((value) => PopupMenuItem<CatalogSort>(\n"
            "                    value: value, child: Text(value.label),\n"
            "                  )).toList(),\n"
            "              ),\n"
            "              Text('${selection.length} titles',",
            'shell: popup sort menu')
        src = replace_once(src,
            '            else SliverList(delegate: SliverChildListDelegate([',
            '''            else if (tab == 1 || tab == 2)
              SliverList(delegate: SliverChildListDelegate([
                for (final year in years)
                  MediaRow(
                    title: '$year',
                    items: base.where((m) => m.releaseYear == year).toList(),
                    onTap: onSelect,
                  ),
                if (base.any((m) => m.releaseYear <= 0))
                  MediaRow(
                    title: 'Year not listed',
                    items: base.where((m) => m.releaseYear <= 0).toList(),
                    onTap: onSelect,
                  ),
                const SizedBox(height: 36),
              ]))
            else SliverList(delegate: SliverChildListDelegate([''',
            'shell: year group rows')
    return src


def player(src: str) -> str:
    if "import 'package:screen_brightness/screen_brightness.dart';" not in src:
        src = replace_once(src, "import 'package:flutter/services.dart';",
            "import 'package:flutter/services.dart';\n"
            "import 'package:screen_brightness/screen_brightness.dart';",
            'player: brightness import')
    if '  bool _gestureVisible = false;' not in src:
        src = replace_once(src, '  double volume = 100;',
            '  double volume = 100;\n'
            '  double _brightness = .5;\n'
            '  bool _gestureVisible = false;\n'
            '  bool _gestureBrightness = true;\n'
            '  bool _brightnessAvailable = true;\n'
            '  Timer? _gestureTimer;', 'player: brightness fields')
    if '  Future<void> _loadBrightness() async {' not in src:
        methods = '''  Future<void> _loadBrightness() async {
    try {
      final value = await ScreenBrightness.instance.application;
      if (mounted) setState(() => _brightness = value.clamp(.05, 1.0).toDouble());
    } catch (error) {
      if (mounted) setState(() => _brightnessAvailable = false);
    }
  }

  void _setBrightness(double next) {
    if (!_brightnessAvailable) return;
    final value = next.clamp(.05, 1.0).toDouble();
    if (mounted) setState(() => _brightness = value);
    ScreenBrightness.instance.setApplicationScreenBrightness(value)
      .catchError((Object error) {
        if (mounted) setState(() => _brightnessAvailable = false);
      });
  }

  void _swipeStart(DragStartDetails details, double width) {
    if (androidTvBuild || locked) return;
    _gestureTimer?.cancel();
    setState(() {
      _gestureBrightness = details.localPosition.dx < width / 2;
      _gestureVisible = true;
    });
  }

  void _swipeUpdate(DragUpdateDetails details, double height) {
    if (androidTvBuild || locked || !_gestureVisible) return;
    final change = -details.delta.dy / height;
    if (_gestureBrightness) {
      _setBrightness(_brightness + change * 1.35);
    } else {
      final next = (volume + change * 130).clamp(0.0, 100.0).toDouble();
      setState(() => volume = next);
      player.setVolume(next);
    }
  }

  void _swipeEnd() {
    _gestureTimer?.cancel();
    _gestureTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _gestureVisible = false);
    });
  }

  Future<void> _selectBrightness() async {
    hideTimer?.cancel();
    if (!_brightnessAvailable) {
      _showError('Application brightness is not supported on this device.');
      return;
    }
    await showModalBottomSheet<void>(context: context,
      builder: (sheetContext) => SafeArea(child: StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Screen brightness', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700)),
            Row(children: [
              const Icon(Icons.brightness_low),
              Expanded(child: Slider(
                value: _brightness.clamp(.05, 1.0).toDouble(),
                min: .05,
                max: 1.0,
                onChanged: (v) {
                  _setBrightness(v);
                  setSheetState(() {});
                },
              )),
              const Icon(Icons.brightness_high),
            ]),
          ]),
        ),
      )),
    );
    _showControls();
  }

  Widget _swipeIndicator() {
    final value = _gestureBrightness ? _brightness : volume / 100;
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_gestureBrightness ? Icons.brightness_6_rounded : Icons.volume_up_rounded,
          size: 34),
        const SizedBox(height: 10),
        Text('${(value * 100).round()}%'),
        const SizedBox(height: 9),
        SizedBox(width: 105, child: LinearProgressIndicator(value: value,
          backgroundColor: Colors.white24, color: AppColors.red)),
      ]),
    )));
  }

'''
        src = replace_once(src, '  Widget _control(IconData icon, String label, VoidCallback? onTap,',
            methods + '  Widget _control(IconData icon, String label, VoidCallback? onTap,',
            'player: add brightness and gesture methods')
        src = replace_once(src, '      fillVideo = app.fillVideo;',
                           '      _loadBrightness();\n      fillVideo = app.fillVideo;',
                           'player: brightness setup')
        src = replace_once(src, '    hideTimer?.cancel();\n    _writeHistory();',
            '    hideTimer?.cancel();\n    _gestureTimer?.cancel();\n'
            '    ScreenBrightness.instance.resetApplicationScreenBrightness()\n'
            '      .catchError((Object _) {});\n'
            '    _writeHistory();', 'player: brightness reset')
        src = replace_once(src,
            '        onTap: () => setState(() => controlsVisible = !controlsVisible),',
            '        onVerticalDragStart: (details) => _swipeStart(details, constraints.maxWidth),\n'
            '        onVerticalDragUpdate: (details) => _swipeUpdate(details, constraints.maxHeight),\n'
            '        onVerticalDragEnd: (_) => _swipeEnd(),\n'
            '        onTap: () => setState(() => controlsVisible = !controlsVisible),',
            'player: attach gestures')
        src = replace_once(src,
            'Expanded(child: Text(widget.episode?.title ?? widget.movie.title,',
            "_control(Icons.arrow_back_rounded, 'Back',\n"
            "                     () => Navigator.maybePop(context)),\n"
            '                   Expanded(child: Text(widget.episode?.title ?? widget.movie.title,',
            'player: back beside video title')
        src = replace_once(src,
            "if (small) _control(Icons.volume_up_outlined, 'Volume', _selectVolume),",
            "if (small) _control(Icons.volume_up_outlined, 'Volume', _selectVolume),\n"
            "                     _control(Icons.brightness_6_outlined, 'Brightness', _selectBrightness),",
            'player: brightness toolbar')
        src = replace_once(src,
            '           if (playbackError != null) ColoredBox(',
            '           if (_gestureVisible && !androidTvBuild) _swipeIndicator(),\n'
            '           if (playbackError != null) ColoredBox(',
            'player: swipe indicator')
    return src


def run() -> None:
    # Validate & stage the entire patch first: never leave a half-applied project.
    operations = [
        ('pubspec.yaml', pubspec),
        ('lib/main.dart', main),
        ('lib/screens/settings_screen.dart', settings),
        ('lib/screens/shell_screen.dart', shell),
        ('lib/screens/player_screen.dart', player),
    ]
    staged = []
    for filename, transformer in operations:
        path = ROOT / filename
        before = path.read_text(encoding='utf-8')
        after = transformer(before)
        staged.append((path, before, after))
    for path, before, after in staged:
        if before != after:
            path.write_text(after, encoding='utf-8')
            print('UPDATED', path.relative_to(ROOT))
        else:
            print('UNCHANGED', path.relative_to(ROOT))
    print('Patch applied. Run flutter pub get, dart format lib, flutter analyze, flutter test.')

if __name__ == '__main__':
    try:
        run()
    except (OSError, RuntimeError) as exc:
        print(f'NOT APPLIED: {exc}', file=sys.stderr)
        sys.exit(1)
