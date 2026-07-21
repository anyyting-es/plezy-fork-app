import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../utils/platform_detector.dart';

class AppExitService {
  static const bool _tvosBuild = bool.fromEnvironment('TVOS_BUILD');
  static const MethodChannel _channel = MethodChannel('com.plezy/app_exit');

  /// Requests that the host platform closes or backgrounds the app.
  ///
  /// tvOS has no public API for force-quitting or going Home, so callers that
  /// handle a physical back/Menu key should let the event continue instead.
  static Future<bool> requestExit() async {
    if (_tvosBuild || PlatformDetector.isAppleTV()) return false;

    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('requestExit') ?? true;
      } on MissingPluginException {
        await SystemNavigator.pop();
        return true;
      } on PlatformException {
        await SystemNavigator.pop();
        return true;
      }
    }

    await SystemNavigator.pop();
    return true;
  }
}
