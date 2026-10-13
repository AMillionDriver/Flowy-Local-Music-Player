import 'package:flutter/material.dart';

/// Design tokens extracted directly from Stitch project DESIGN.md.
/// Strictly enforces the deep nocturnal oceanic palette (#0A151A background).
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF0A151A);
  static const Color surface = Color(0xFF0A151A);
  static const Color surfaceDim = Color(0xFF0A151A);
  static const Color surfaceBright = Color(0xFF303B41);
  static const Color surfaceContainerLowest = Color(0xFF051015);
  static const Color surfaceContainerLow = Color(0xFF121D23);
  static const Color surfaceContainer = Color(0xFF162127);
  static const Color surfaceContainerHigh = Color(0xFF202B32);
  static const Color surfaceContainerHighest = Color(0xFF2B363D);

  static const Color primary = Color(0xFF91CDFF);
  static const Color primaryContainer = Color(0xFF4C97CE);
  static const Color primaryFixed = Color(0xFFCCE5FF);
  static const Color primaryFixedDim = Color(0xFF91CDFF);
  static const Color onPrimary = Color(0xFF003350);
  static const Color onPrimaryContainer = Color(0xFF002C46);

  static const Color secondary = Color(0xFFA6CCE4);
  static const Color secondaryContainer = Color(0xFF274D62);
  static const Color secondaryFixed = Color(0xFFC4E7FF);
  static const Color onSecondary = Color(0xFF083448);
  static const Color onSecondaryContainer = Color(0xFF98BDD5);

  static const Color onSurface = Color(0xFFD8E4EC);
  static const Color onSurfaceVariant = Color(0xFFC0C7D0);
  static const Color outline = Color(0xFF8A919A);
  static const Color outlineVariant = Color(0xFF40484F);

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  // Accent wave gradients
  static const Color waveTeal = Color(0xFF163040);
  static const Color waveBlue = Color(0xFF0F2838);
  static const Color waveCyan = Color(0xFF275A7C);
}
