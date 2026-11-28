import 'package:flutter/material.dart';

/// Shared form layout that keeps the actions reachable on small screens.
class CpmsFormDialog extends StatelessWidget {
  const CpmsFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = Icons.edit_outlined,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(child: title),
        ],
      ),
      content: content,
      actions: actions,
    );
  }
}
