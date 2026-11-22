import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildPlatformSignageEmbed(String url) {
  final viewId = 'screenpilot-iframe-${url.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..allow = 'autoplay; fullscreen; encrypted-media';
    return iframe;
  });
  return HtmlElementView(viewType: viewId);
}
