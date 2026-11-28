import 'package:flutter/material.dart';

class CpmsFormPage extends StatelessWidget {
  const CpmsFormPage({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.automaticallyImplyLeading = true,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: title,
        actions: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                content,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
