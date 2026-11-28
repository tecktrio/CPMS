import 'package:cpms_mobile/widgets/cpms_stock_quantity_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stock buttons update the plain quantity without opening an input', (
    tester,
  ) async {
    final updates = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CpmsStockQuantityInput(
            quantity: 0,
            itemName: 'Materials',
            onChanged: updates.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Decrease stock'));
    expect(updates, isEmpty);
    await tester.tap(find.byTooltip('Increase stock'));
    await tester.tap(find.byTooltip('Increase stock'));
    await tester.pump();
    expect(updates, [1, 2]);
    expect(find.byType(AlertDialog), findsNothing);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease stock'));
    await tester.pump();
    expect(updates, [1, 2, 1]);
    expect(find.text('1'), findsOneWidget);
  });
}
