import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyProgressIndicator extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Color? color;

  const WavyProgressIndicator({
    super.key,
    required this.progress,
    this.size = 24.0,
    this.color,
  });

  @override
  State<WavyProgressIndicator> createState() => _WavyProgressIndicatorState();
}

class _WavyProgressIndicatorState extends State<WavyProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavyPainter(
              progress: widget.progress,
              animationValue: _controller.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color color;

  _WavyPainter({
    required this.progress,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Background circle (border)
    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, bgPaint);

    // Clip to circle
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // Wave calculation
    final waveHeight = radius * 0.15;
    final waveLevel = size.height - (size.height * progress);
    
    final path = Path();
    path.moveTo(0, waveLevel);

    for (double i = 0; i <= size.width; i++) {
      final angle = (i / size.width) * 2 * math.pi + (animationValue * 2 * math.pi);
      final y = waveLevel + math.sin(angle) * waveHeight;
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, paint);
    
    // Add a second, semi-transparent wave for depth
    final path2 = Path();
    path2.moveTo(0, waveLevel);

    for (double i = 0; i <= size.width; i++) {
      final angle = (i / size.width) * 2 * math.pi - (animationValue * 2 * math.pi) + math.pi;
      final y = waveLevel + math.sin(angle) * waveHeight;
      path2.lineTo(i, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    final paint2 = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavyPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.progress != progress;
  }
}
