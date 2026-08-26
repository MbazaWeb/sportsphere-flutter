import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playify/app/app.dart';

void main() {
  testWidgets('Playify app boots without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PlayifyApp()),
    );
    // Splash screen renders — just check it doesn't throw
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
