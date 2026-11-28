import 'dart:async';

import 'package:flutter/material.dart';

Future<T> runWithLoadingPage<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() operation,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = MaterialPageRoute<void>(
    builder: (_) => PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );

  unawaited(navigator.push(route));
  try {
    return await operation();
  } finally {
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}
