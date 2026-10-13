import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AnimatedEqualizer extends StatefulWidget {
  final bool isPlaying;

  const AnimatedEqualizer({
    super.key,
    this.isPlaying = true,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. RepaintBoundary mengisolasi repaint dari TrackListTile induk
    // 2. CustomPainter(repaint: _controller) menghilangkan AnimatedBuilder
    //    sehingga widget tree 0 kali di-rebuild tiap frame!
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(18, 18),
        painter: _EqualizerPainter(
          animation: _controller,
          isPlaying: widget.isPlaying,
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isPlaying;

  static final Paint _barPaint = Paint()
    ..color = AppColors.primaryFixed
    ..style = PaintingStyle.fill;

  static const Radius _radius = Radius.circular(2);

  _EqualizerPainter({
    required this.animation,
    required this.isPlaying,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final val = animation.value;

    final h1 = isPlaying
        ? (6.0 + 10.0 * (0.5 + 0.5 * sin(val * 2 * pi)))
        : 6.0;
    final h2 = isPlaying
        ? (4.0 + 8.0 * (0.5 + 0.5 * sin((val + 0.3) * 2 * pi)))
        : 4.0;
    final h3 = isPlaying
        ? (7.0 + 9.0 * (0.5 + 0.5 * sin((val + 0.6) * 2 * pi)))
        : 5.0;

    const barWidth = 3.0;
    const gap = 2.0;
    const totalWidth = (barWidth * 3) + (gap * 2); // 13.0
    final startX = (size.width - totalWidth) / 2.0;
    final baselineY = size.height;

    // Bar 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, baselineY - h1, barWidth, h1),
        _radius,
      ),
      _barPaint,
    );

    // Bar 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + barWidth + gap, baselineY - h2, barWidth, h2),
        _radius,
      ),
      _barPaint,
    );

    // Bar 3
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + (barWidth + gap) * 2, baselineY - h3, barWidth, h3),
        _radius,
      ),
      _barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying;
  }
}
