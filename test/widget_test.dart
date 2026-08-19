import 'package:flutter_test/flutter_test.dart';
import 'package:sportsphere_app/main.dart';

void main() {
  testWidgets('Sport Sphere app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SportSphereApp());

    expect(find.text('SPORT'), findsOneWidget);
  });
}
