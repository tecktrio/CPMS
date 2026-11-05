import 'package:flutter_test/flutter_test.dart';
import 'package:cims_mobile/main.dart';

void main() {
  testWidgets('CimsMobileApp initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CimsMobileApp());
    expect(find.byType(CimsMobileApp), findsOneWidget);
  });
}
