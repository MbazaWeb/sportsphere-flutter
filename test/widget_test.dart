import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsphere_app/app/app.dart';

void main() {
  testWidgets('Sport Sphere app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SportSphereApp()),
    );

    expect(find.text('SPORT'), findsOneWidget);
  });
}
