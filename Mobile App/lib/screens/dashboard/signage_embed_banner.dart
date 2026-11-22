import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'signage_embed_stub.dart'
    if (dart.library.js_interop) 'signage_embed_web.dart';

class SignageEmbedBanner extends StatefulWidget {
  final String url;
  final bool isWide;

  const SignageEmbedBanner({
    super.key,
    this.url = 'https://screen.bigburry.com?mirror_name=demo',
    required this.isWide,
  });

  @override
  State<SignageEmbedBanner> createState() => _SignageEmbedBannerState();
}

class _SignageEmbedBannerState extends State<SignageEmbedBanner> {
  WebViewController? _mobileController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _mobileController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..loadRequest(Uri.parse(widget.url));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: widget.isWide ? 220 : 160,
      ),
      child: AspectRatio(
        aspectRatio: widget.isWide ? (16 / 5.2) : (16 / 6.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Embedded Media / Browser View inside banner
              if (kIsWeb)
                buildPlatformSignageEmbed(widget.url)
              else if (_mobileController != null)
                WebViewWidget(controller: _mobileController!)
              else
                Image.asset(
                  'assets/images/banner_ad.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF0F172A),
                      child: const Center(
                        child: Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    );
                  },
                ),

           
            ],
          ),
        ),
      ),
    );
  }
}
