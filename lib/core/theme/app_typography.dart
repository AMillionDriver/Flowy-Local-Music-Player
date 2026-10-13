import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography definitions matching Stitch DESIGN.md:
/// - Headlines: Space Grotesk
/// - Body: Plus Jakarta Sans
/// - Metrics / Audio specs: JetBrains Mono
/// - Brand logo text: Luxurious Script
class AppTypography {
  const AppTypography._();

  static TextStyle get brandTitle => GoogleFonts.luxuriousScript(
        fontSize: 26,
        color: AppColors.primary,
        fontWeight: FontWeight.w400,
        height: 1.0,
      );

  static TextStyle get headlineLg => GoogleFonts.spaceGrotesk(
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.6,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.spaceGrotesk(
        fontSize: 20,
        height: 28 / 20,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 22 / 15,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 18 / 12,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w400,
        color: AppColors.secondary,
      );

  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        height: 16 / 13,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: AppColors.outline,
      );

  static TextStyle get monoMetric => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 15 / 11,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      );

  static TextStyle get monoTag => GoogleFonts.jetBrainsMono(
        fontSize: 10,
        height: 14 / 10,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryFixed,
      );
}
