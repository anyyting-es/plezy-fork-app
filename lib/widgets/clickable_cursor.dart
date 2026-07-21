import 'package:flutter/material.dart';

import '../utils/platform_detector.dart';

class ClickableCursor extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const ClickableCursor({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    // No pointer on TV: skip the MouseRegion entirely — one exists per card
    // and they add up on low-end devices.
    if (PlatformDetector.isTV()) return child;
    return MouseRegion(cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer, child: child);
  }
}
