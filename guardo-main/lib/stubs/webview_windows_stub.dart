// Stub for webview_windows on web
import 'package:flutter/material.dart';

class WebviewController {
  Future<void> initialize() async {}
  void dispose() {}
  Future<void> loadStringContent(String html) async {}
  Stream<dynamic> get webMessage => const Stream.empty();
  Future<void> executeScript(String script) async {}
}

class Webview extends StatelessWidget {
  final WebviewController controller;
  const Webview(this.controller, {super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Webview not supported on web'));
}
