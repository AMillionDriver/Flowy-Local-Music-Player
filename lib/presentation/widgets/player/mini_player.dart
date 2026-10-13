import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../common/track_artwork.dart';

class MiniPlayer extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPauseTap;
  final VoidCallback onNextTap;
  final VoidCallback onPreviousTap;
  final VoidCallback? onTap;

  const MiniPlayer({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPauseTap,
    required this.onNextTap,
    required this.onPreviousTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Tooltip(
        message: 'Buka Pemutar Lengkap',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Top Thin Linear Progress Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: AppColors.surfaceContainerHighest,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  // Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // Left Visualizer / Art
                        TrackArtwork(
                          track: track,
                          size: 44,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(width: 12),
                        // Track Info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm,
                              ),
                            ],
                          ),
                        ),
                        // Control Buttons
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous,
                            color: AppColors.onSurfaceVariant,
                            size: 24,
                          ),
                          tooltip: 'Sebelumnya',
                          onPressed: onPreviousTap,
                        ),
                        // Play/Pause circular accent button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: onPlayPauseTap,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: AppColors.onPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_next,
                            color: AppColors.onSurfaceVariant,
                            size: 24,
                          ),
                          tooltip: 'Berikutnya',
                          onPressed: onNextTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
