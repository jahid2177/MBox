import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/main.dart';
import 'package:mystreamflix_flutter/state/app_state.dart';
import 'package:mystreamflix_flutter/screens/settings_screen.dart';
import 'package:mystreamflix_flutter/screens/about_screen.dart';

void main() {
  testWidgets('About shows the requested developer name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutScreen())),
    );
    expect(find.text('Md Jahidul Islam'), findsOneWidget);
    expect(find.text('MyStreamFlix'), findsOneWidget);
  });

  testWidgets('Settings shows playback and server controls', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Active content server'), findsOneWidget);
    expect(find.text('Refresh all content'), findsOneWidget);
    expect(find.text('Autoplay video'), findsOneWidget);
    expect(find.text('Live TV source'), findsNothing);
  });

  test('player preferences have sensible safe defaults', () {
    final state = AppState();
    expect(state.playbackSpeed, 1.0);
    expect(state.seekSeconds, 10);
    expect(state.autoPlay, isTrue);
    expect(state.preferredAudioLanguage, 'auto');
    state.dispose();
  });
}
