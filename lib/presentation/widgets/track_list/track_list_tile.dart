import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../common/track_artwork.dart';

class TrackListTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOptionsTap;

  const TrackListTile({
    super.key,
    required this.track,
    required this.onTap,
    required this.onFavoriteTap,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Order Number
                SizedBox(
                  width: 22,
                  child: Text(
                    track.orderNumber,
                    textAlign: TextAlign.center,
                    style: AppTypography.monoMetric.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Cover Thumbnail
                TrackArtwork(
                  track: track,
                  size: 44,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                // Title and Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLg,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.artist} • ${track.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              track.audioFormat,
                              style: AppTypography.monoTag,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            track.duration,
                            style: AppTypography.monoMetric.copyWith(
                              color: AppColors.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Actions
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.outline,
                    size: 18,
                  ),
                  tooltip: 'Menu Opsi',
                  onPressed: onOptionsTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
