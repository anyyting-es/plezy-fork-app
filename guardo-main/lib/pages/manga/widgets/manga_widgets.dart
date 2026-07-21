import 'package:flutter/material.dart';

class MangaSynopsis extends StatefulWidget {
  final String description;
  final TextAlign textAlign;
  final int maxLines;
  const MangaSynopsis({
    super.key,
    required this.description, 
    this.textAlign = TextAlign.start,
    this.maxLines = 4,
  });
  @override
  State<MangaSynopsis> createState() => _MangaSynopsisState();
}

class _MangaSynopsisState extends State<MangaSynopsis> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
        child: Text(
          widget.description, 
          textAlign: widget.textAlign,
          maxLines: _isExpanded ? null : widget.maxLines, 
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis, 
          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class DetailChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  const DetailChip({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: Colors.white.withValues(alpha: 0.15))
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown, 
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: Colors.white70), const SizedBox(width: 5)],
            Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]
        )
      ),
    );
  }
}
