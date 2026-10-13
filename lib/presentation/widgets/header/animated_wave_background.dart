import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AnimatedWaveBackground extends StatefulWidget {
  final Widget child;

  const AnimatedWaveBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. RepaintBoundary mengisolasi render layer header di GPU
    // 2. CustomPainter(repaint: _controller) menghilangkan AnimatedBuilder
    //    sehingga widget tree 0 kali di-rebuild tiap frame!
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WaveAndStarsPainter(animation: _controller),
        child: widget.child,
      ),
    );
  }
}

class _WaveAndStarsPainter extends CustomPainter {
  final Animation<double> animation;

  // Rasio pecahan koordinat bintang statis (precomputed, 0 memory allocation per frame)
  static const List<Offset> _starFractions = [
    Offset(0.12, 0.22),
    Offset(0.28, 0.38),
    Offset(0.44, 0.25),
    Offset(0.58, 0.18),
    Offset(0.72, 0.42),
    Offset(0.86, 0.28),
    Offset(0.92, 0.15),
  ];

  // Re-usable Paint objects (0 heap object allocation per frame)
  final Paint _glowPaint1 = Paint()
    ..color = AppColors.waveTeal.withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

  final Paint _glowPaint2 = Paint()
    ..color = AppColors.waveCyan.withValues(alpha: 0.25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);

  final Paint _wave1Paint = Paint();
  final Paint _wave2Paint = Paint();

  final Paint _strokePaint = Paint()
    ..color = AppColors.primary.withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _starPaint = Paint();
  final Paint _starGlowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  // Re-usable Path objects
  final Path _path1 = Path();
  final Path _path2 = Path();

  // Shader cache
  Size? _cachedSize;
  Shader? _cachedShader1;
  Shader? _cachedShader2;

  _WaveAndStarsPainter({required this.animation}) : super(repaint: animation);

  void _updateShaders(double width, double height) {
    if (_cachedSize?.width == width && _cachedSize?.height == height) return;
    _cachedSize = Size(width, height);

    _cachedShader1 = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF08141B),
        Color(0xFF0C212E),
        Color(0xFF163040),
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, width, height));

    _cachedShader2 = const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xBB051015),
        Color(0x99091C28),
        Color(0x55183B52),
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, width, height));

    _wave1Paint.shader = _cachedShader1;
    _wave2Paint.shader = _cachedShader2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;

    final animationValue = animation.value;
    _updateShaders(width, height);

    // 1. Ambient Background Glows
    canvas.drawCircle(Offset(width * 0.1, height * 0.3), 36, _glowPaint1);
    canvas.drawCircle(Offset(width * 0.85, height * 0.7), 42, _glowPaint2);

    // 2. Twinkling Stars (Zero allocation)
    _drawStars(canvas, width, height, animationValue);

    // 3. Layer 1: Slow Deep Wave
    _path1.reset();
    _path1.moveTo(0, height);
    final wave1Phase = animationValue * 2 * pi;
    for (double x = 0; x <= width; x += 10) {
      final y = height * 0.55 +
          sin((x / width * 2 * pi) + wave1Phase) * 12 +
          cos((x / width * 3 * pi) - wave1Phase * 0.5) * 6;
      _path1.lineTo(x, y);
    }
    _path1.lineTo(width, height);
    _path1.close();
    canvas.drawPath(_path1, _wave1Paint);

    // 4. Layer 2: Fast Cyan Accent Wave
    _path2.reset();
    _path2.moveTo(0, height);
    final wave2Phase = -animationValue * 2.5 * pi;
    for (double x = 0; x <= width; x += 8) {
      final y = height * 0.68 +
          sin((x / width * 2.5 * pi) + wave2Phase) * 9 +
          cos((x / width * 1.5 * pi) + wave2Phase) * 5;
      _path2.lineTo(x, y);
    }
    _path2.lineTo(width, height);
    _path2.close();
    canvas.drawPath(_path2, _wave2Paint);

    // Wave stroke highlight
    canvas.drawPath(_path2, _strokePaint);
  }

  void _drawStars(Canvas canvas, double width, double height, double animationValue) {
    for (int i = 0; i < _starFractions.length; i++) {
      final fraction = _starFractions[i];
      final pos = Offset(width * fraction.dx, height * fraction.dy);
      final phase = (animationValue + (i * 0.18)) % 1.0;
      final opacity = (0.25 + 0.7 * sin(phase * pi)).clamp(0.1, 0.95);
      final radius = 1.0 + (sin(phase * pi) * 0.6);

      _starPaint.color = Color.fromRGBO(187, 225, 250, opacity);
      canvas.drawCircle(pos, radius, _starPaint);

      // Soft glow around brighter stars
      if (opacity > 0.6) {
        _starGlowPaint.color = Color.fromRGBO(145, 205, 255, opacity * 0.4);
        canvas.drawCircle(pos, radius * 2.2, _starGlowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveAndStarsPainter oldDelegate) {
    return false; // Repaint dipicu langsung oleh super(repaint: animation)
  }
}
