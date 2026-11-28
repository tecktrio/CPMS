import 'package:flutter/material.dart';

class CpmsStockQuantityInput extends StatefulWidget {
  const CpmsStockQuantityInput({
    super.key,
    required this.quantity,
    required this.itemName,
    required this.onChanged,
  });

  final double quantity;
  final String itemName;
  final ValueChanged<double>? onChanged;

  @override
  State<CpmsStockQuantityInput> createState() => _CpmsStockQuantityInputState();
}

class _CpmsStockQuantityInputState extends State<CpmsStockQuantityInput> {
  late double _quantity = widget.quantity;
  String _format(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');

  @override
  void didUpdateWidget(covariant CpmsStockQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity) {
      _quantity = widget.quantity;
    }
  }

  void _step(int amount) {
    final next = (_quantity + amount).clamp(0.0, double.infinity).toDouble();
    final onChanged = widget.onChanged;
    if (onChanged == null || !next.isFinite || next == _quantity) return;
    setState(() => _quantity = next);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onChanged != null;
    return SizedBox(
      width: 124,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Decrease stock',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: canEdit && _quantity > 0 ? () => _step(-1) : null,
          ),
          Expanded(
            child: Semantics(
              label: 'Stock quantity for ${widget.itemName}',
              child: Text(
                _format(_quantity),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase stock',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 18),
            onPressed: canEdit ? () => _step(1) : null,
          ),
        ],
      ),
    );
  }
}
