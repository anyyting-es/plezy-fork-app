import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TVFocusWrapper extends StatefulWidget {
  const TVFocusWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.focusColor,
    this.borderRadius = 8.0,
    this.scaleOnFocus = 1.05,
    this.showBorder = true,
    this.showGlow = false,
    this.focusNode,
    this.listenTo,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? focusColor;
  final double borderRadius;
  final double scaleOnFocus;
  final bool showBorder;
  final bool showGlow;
  final FocusNode? focusNode;
  final FocusNode? listenTo; // Add this

  @override
  State<TVFocusWrapper> createState() => _TVFocusWrapperState();
}

class _TVFocusWrapperState extends State<TVFocusWrapper> {
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_updateFocus);
    widget.listenTo?.addListener(_updateFocus);
  }

  void _updateFocus() {
    final hasFocus = _focusNode.hasFocus || (widget.listenTo?.hasFocus ?? false);
    if (hasFocus != _isFocused) {
      if (mounted) setState(() => _isFocused = hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_updateFocus);
    widget.listenTo?.removeListener(_updateFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusColor = widget.focusColor ?? theme.colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (_) => _updateFocus(),
      onKeyEvent: (node, event) {
        if (_isFocused &&
            (event is KeyDownEvent) &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isFocused ? widget.scaleOnFocus : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: (widget.showBorder && _isFocused)
                  ? Border.all(
                      color: focusColor,
                      width: 3.0,
                    )
                  : null,
              boxShadow: (widget.showGlow && _isFocused)
                  ? [
                      BoxShadow(
                        color: focusColor.withValues(alpha: 0.4),
                        blurRadius: 35,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: focusColor.withValues(alpha: 0.15),
                        blurRadius: 55,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
