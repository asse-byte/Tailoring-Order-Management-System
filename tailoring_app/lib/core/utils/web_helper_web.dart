// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../network/api_client.dart';

void updateWebTabFaviconAndTitle(String? logoUrl, String shopName) {
  if (kIsWeb) {
    try {
      final String resolved = logoUrl != null
          ? (logoUrl.startsWith('http') ? logoUrl : '${ApiClient.baseUrl}$logoUrl')
          : 'favicon.png';
      js.context.callMethod('changeFavicon', <dynamic>[resolved]);
      js.context.callMethod('changeTitle', <dynamic>[shopName]);
    } catch (_) {}
  }
}
