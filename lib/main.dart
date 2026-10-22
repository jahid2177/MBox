import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/shell_screen.dart';
import 'screens/mbox_splash_screen.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  ApiService? service;
  String? initError;
  if (accountsEnabled) {
    try { service = await ApiService.create(); }
    catch (e) { initError = e.toString(); }
  }
  final state = AppState(api: service);
  runApp(AppScope(state: state, child: MyStreamFlixApp(initialError: initError)));
  await state.init();
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing from tree');
    return scope!.notifier!;
  }
}

class MyStreamFlixApp extends StatelessWidget {
  final String? initialError;
  const MyStreamFlixApp({super.key, this.initialError});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MBox', debugShowCheckedModeBanner: false, theme: buildAppTheme(),
    home: initialError == null
      ? const MBoxSplashScreen(next: ShellScreen())
      : Scaffold(
      body: Center(child: Padding(
        padding: const EdgeInsets.all(25), child: Text('Configuration error: $initialError'),
      )),
    ),
  );
}
