// Mirrors `lib/app/home_screen.dart`, per Volume 3 Chapter 3.6's
// test-mirrors-lib rule (cited by Volume 9, Chapter 9.6 §1).
//
// Pumps the real composition — `ProviderScope` wrapping `VumpApp` — rather
// than `HomeScreen` in isolation, so the router and theme are exercised too.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('HomeScreen displays the application name and mission status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VumpApp()));
    await tester.pumpAndSettle();

    expect(find.text('Vump Technologies'), findsOneWidget);
    expect(find.text('Mission 0.6 Complete'), findsOneWidget);
  });
}
