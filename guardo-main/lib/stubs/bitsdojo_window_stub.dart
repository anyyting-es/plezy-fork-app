// Stub for bitsdojo_window on web
import 'package:flutter/material.dart';

class BitsdojoWindow {
  void doWhenWindowReady(VoidCallback callback) {}
}

final appWindow = AppWindowStub();

class AppWindowStub {
  bool get isVisible => true;
  Size get size => Size.zero;
  set minSize(Size size) {}
  set size(Size size) {}
  set alignment(dynamic alignment) {}
  set title(String title) {}
  void show() {}
  void close() {}
  void maximize() {}
  void minimize() {}
  void restore() {}
}

class WindowButton extends StatelessWidget {
  const WindowButton({super.key, dynamic colors, dynamic onPressed});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class CloseWindowButton extends WindowButton {
  const CloseWindowButton({super.key, super.colors, super.onPressed});
}

class MaximizeWindowButton extends WindowButton {
  const MaximizeWindowButton({super.key, super.colors, super.onPressed});
}

class MinimizeWindowButton extends WindowButton {
  const MinimizeWindowButton({super.key, super.colors, super.onPressed});
}

class WindowCaption extends StatelessWidget {
  final Widget? title;
  final List<Widget>? children;
  final Color? backgroundColor;
  final bool? brightness;
  const WindowCaption({super.key, this.title, this.children, this.backgroundColor, this.brightness});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class MoveWindow extends StatelessWidget {
  final Widget? child;
  const MoveWindow({super.key, this.child});
  @override
  Widget build(BuildContext context) => child ?? const SizedBox.shrink();
}

class WindowButtonColors {
  final Color? iconNormal;
  final Color? mouseOver;
  final Color? mouseDown;
  final Color? iconMouseOver;
  final Color? iconMouseDown;
  WindowButtonColors({this.iconNormal, this.mouseOver, this.mouseDown, this.iconMouseOver, this.iconMouseDown});
}

void doWhenWindowReady(VoidCallback callback) {}
