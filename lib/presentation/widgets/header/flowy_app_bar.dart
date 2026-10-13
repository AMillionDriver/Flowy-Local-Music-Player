import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'animated_wave_background.dart';

class FlowyAppBar extends StatelessWidget {
  final VoidCallback? onTuneTap;
  final VoidCallback? onEqualizerTap;

  const FlowyAppBar({
    super.key,
    this.onTuneTap,
    this.onEqualizerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: AnimatedWaveBackground(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Logo & App Name
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo_flowy.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Flowy',
                  style: AppTypography.brandTitle,
                ),
                const Spacer(),
                // Actions
                _ActionButton(
                  icon: Icons.tune,
                  tooltip: 'Pencarian dan Filter',
                  onTap: onTuneTap,
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.equalizer,
                  tooltip: 'Pengaturan Suara',
                  onTap: onEqualizerTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: AppColors.onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}
