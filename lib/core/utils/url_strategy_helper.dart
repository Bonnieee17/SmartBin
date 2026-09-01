import 'package:flutter/foundation.dart';

/// A helper to get the current URL or origin safely across platforms.
class UrlStrategyHelper {
  static String get currentOrigin {
    if (kIsWeb) {
      // We will use conditional imports to implement this
      return _getWebOrigin();
    }
    return 'http://localhost';
  }

  static String get currentFullUrl {
    if (kIsWeb) {
      return _getWebFullUrl();
    }
    return '';
  }

  static void clearUrlParams() {
    if (kIsWeb) {
      _clearWebUrlParams();
    }
  }

  // These will be stubbed for mobile
  static String _getWebOrigin() => 'http://localhost';
  static String _getWebFullUrl() => '';
  static void _clearWebUrlParams() {}
}
