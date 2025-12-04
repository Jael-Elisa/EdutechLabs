import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test básico de la app', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Edutech Labs'),
        ),
      ),
    );

    expect(find.text('Edutech Labs'), findsOneWidget);
  });
}
