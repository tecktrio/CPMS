import 'package:flutter_test/flutter_test.dart';
import 'package:cpms_mobile/main.dart';

void main() {
  testWidgets('CpmsMobileApp initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CpmsMobileApp());
    expect(find.byType(CpmsMobileApp), findsOneWidget);
  });
}
