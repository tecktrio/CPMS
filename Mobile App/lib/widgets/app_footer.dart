import 'package:flutter/material.dart';

/// Standard footer displayed across all screens in the application.
class AppFooter extends StatelessWidget {
  final double topPadding;
  final double bottomPadding;

  const AppFooter({
    super.key,
    this.topPadding = 24.0,
    this.bottomPadding = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: const Center(
        child: Text(
          'Developed by Bigburry Hypersystems',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

