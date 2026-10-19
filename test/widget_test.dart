import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/main.dart';

void main() {
  testWidgets('BusSafetyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BusSafetyApp());
    expect(find.text('통학버스 안전'), findsOneWidget);
  });
}
