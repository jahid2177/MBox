import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/main.dart';
import 'package:mystreamflix_flutter/state/app_state.dart';

void main() {
  testWidgets('Configuration errors are shown without starting the backend',
      (WidgetTester tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MyStreamFlixApp(initialError: 'Test backend unavailable'),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Test backend unavailable'), findsOneWidget);
  });
}
