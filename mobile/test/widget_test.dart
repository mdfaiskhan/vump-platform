import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('HomeScreen displays the application name and mission status',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VumpApp()));
    await tester.pumpAndSettle();

    expect(find.text('Vump Technologies'), findsOneWidget);
    expect(find.text('Mission 0.6 Complete'), findsOneWidget);
  });
}
