import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'services/api_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  ApiService? service;
  String? initError;
  if (!demoMode) {
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
    title: 'MyStreamFlix', debugShowCheckedModeBanner: false, theme: buildAppTheme(),
    home: initialError == null ? const ShellScreen() : Scaffold(
      body: Center(child: Padding(
        padding: const EdgeInsets.all(25), child: Text('Configuration error: $initialError'),
      )),
    ),
  );
}
