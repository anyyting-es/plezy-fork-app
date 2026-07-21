import 'package:flutter/material.dart';

import '../focus/focusable_button.dart';

/// A dialog action button that wraps [FocusableButton] around a [TextButton]
/// (or [FilledButton] when [isPrimary] is true).
///
/// Use in an [AlertDialog]'s `actions:` list — replaces the 4-line
/// `FocusableButton(onPressed: ..., child: TextButton(onPressed: ..., ...))`
/// boilerplate with a single call.
class DialogActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final FocusNode? focusNode;
  final bool isPrimary;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onNavigateRight;

  const DialogActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.focusNode,
    this.isPrimary = false,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateLeft,
    this.onNavigateRight,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableButton(
      focusNode: focusNode,
      onPressed: onPressed,
      useBackgroundFocus: isPrimary,
      onNavigateUp: onNavigateUp,
      onNavigateDown: onNavigateDown,
      onNavigateLeft: onNavigateLeft,
      onNavigateRight: onNavigateRight,
      child: isPrimary
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
