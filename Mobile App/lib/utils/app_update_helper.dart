import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateHelper {
  static const String appVersion = '1.0.1';
  static const String buildNumber = '27';
  static const String androidPackageName = 'com.cpms.cpms_mobile';
  static const String playStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String playStoreMarketUri =
      'market://details?id=$androidPackageName';

  // iOS App Store URL (will fallback gracefully)
  static const String appStoreWebUrl =
      'https://apps.apple.com/app/cpms-mobile/id6738914614';
  static const String appStoreMarketUri =
      'itms-apps://itunes.apple.com/app/id6738914614';

  /// Open Play Store or App Store based on the current platform
  static Future<bool> openStore({BuildContext? context}) async {
    try {
      if (kIsWeb) {
        final uri = Uri.parse(playStoreWebUrl);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (Platform.isAndroid) {
        final marketUri = Uri.parse(playStoreMarketUri);
        final webUri = Uri.parse(playStoreWebUrl);

        if (await canLaunchUrl(marketUri)) {
          return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        } else {
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } else if (Platform.isIOS) {
        final itmsUri = Uri.parse(appStoreMarketUri);
        final webUri = Uri.parse(appStoreWebUrl);

        if (await canLaunchUrl(itmsUri)) {
          return await launchUrl(itmsUri, mode: LaunchMode.externalApplication);
        } else {
          return await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Desktop / Other platforms fallback to web Play Store link
        final webUri = Uri.parse(playStoreWebUrl);
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open app store: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open store: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return false;
    }
  }
}

