import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class AppForegroundService {
  static const MethodChannel _channel = MethodChannel('com.plezy/app_foreground');

  static Future<bool> requestForeground() async {
    if (!Platform.isAndroid) return false;

    try {
      return await _channel.invokeMethod<bool>('requestForeground') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
