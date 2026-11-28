import 'package:flutter/material.dart';

class OrderSplitView extends StatelessWidget {
  const OrderSplitView({super.key, required this.orders, required this.detail});

  static const double minimumWidth = 1000;

  final Widget orders;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width: (constraints.maxWidth * 0.22).clamp(244.0, 300.0).toDouble(),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: orders,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child:
                detail ??
                const Center(
                  child: Text('Select a purchase order to view its details.'),
                ),
          ),
        ],
      ),
    );
  }
}
