import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../common/track_artwork.dart';
import 'animated_equalizer.dart';

class ActiveTrackCard extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOptionsTap;

  const ActiveTrackCard({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onTap,
    required this.onFavoriteTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Left Accent Line
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: AppColors.primary,
                    ),
                  ),
                  // Background ambient subtle gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryContainer.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  // Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        // Album Thumbnail with Equalizer overlay
                        TrackArtwork(
                          track: track,
                          size: 48,
                          borderRadius: BorderRadius.circular(8),
                          overlay: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: AnimatedEqualizer(
                                isPlaying: isPlaying,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Titles and Specs
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.primaryFixed,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${track.artist} • ${track.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer
                                          .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      track.sampleRate != null
                                          ? '${track.audioFormat} • ${track.sampleRate}'
                                          : track.audioFormat,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.monoTag.copyWith(
                                        color: AppColors.primaryFixed,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                track.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: track.isFavorite
                                    ? AppColors.primary
                                    : AppColors.outline,
                                size: 19,
                              ),
                              tooltip: 'Favorit',
                              onPressed: onFavoriteTap,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              track.duration,
                              style: AppTypography.monoMetric.copyWith(
                                color: AppColors.primaryFixedDim,
                                fontSize: 11,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.onSurfaceVariant,
                                size: 18,
                              ),
                              tooltip: 'Menu Opsi',
                              onPressed: onOptionsTap,
                            ),
                          ],
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
    );
  }
}
