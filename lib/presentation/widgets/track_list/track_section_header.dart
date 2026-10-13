import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class TrackSectionHeader extends StatelessWidget {
  final String leftText;
  final String rightText;
  final bool isHiResAccent;

  const TrackSectionHeader({
    super.key,
    required this.leftText,
    required this.rightText,
    this.isHiResAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftText.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              letterSpacing: 1.0,
            ),
          ),
          Text(
            rightText,
            style: AppTypography.monoMetric.copyWith(
              color: isHiResAccent ? AppColors.primary : AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
