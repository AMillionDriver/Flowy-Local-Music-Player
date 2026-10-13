import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/track.dart';

class TrackArtwork extends StatelessWidget {
  final Track track;
  final double size;
  final BorderRadius borderRadius;
  final Widget? overlay;
  final List<BoxShadow>? boxShadow;
  final BoxBorder? border;

  const TrackArtwork({
    super.key,
    required this.track,
    this.size = 48,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.overlay,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final artworkChild = _buildArtworkContent();

    Widget content = SizedBox(
      width: size,
      height: size,
      child: overlay != null
          ? Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                artworkChild,
                overlay!,
              ],
            )
          : artworkChild,
    );

    if (boxShadow != null || border != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
          border: border,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return content;
  }

  /// Deteksi thumbnail secara bertingkat:
  /// 1. Deteksi thumbnail dari berkas audio (ArtworkType.AUDIO).
  /// 2. Jika tidak ada, deteksi dari metadata album (ArtworkType.ALBUM).
  /// 3. Jika belum ada thumbnail di dalam file, gunakan gambar default Flowy.
  Widget _buildArtworkContent() {
    // Bounded decoding: batasi resolusi decode thumbnail (60-140px)
    // Mencegah alokasi bitmap mentah 4MB per artwork yang dapat meledakkan RAM 3GB
    final cacheDimension = (size * 2).toInt().clamp(60, 140);

    if (track.localMediaId != null) {
      return QueryArtworkWidget(
        id: track.localMediaId!,
        type: ArtworkType.AUDIO,
        size: cacheDimension,
        artworkWidth: size,
        artworkHeight: size,
        artworkBorder: borderRadius,
        artworkFit: BoxFit.cover,
        artworkQuality: FilterQuality.low,
        keepOldArtwork: true,
        nullArtworkWidget: _buildAlbumOrFallback(cacheDimension),
        errorBuilder: (context, exception, stackTrace) => _buildAlbumOrFallback(cacheDimension),
      );
    }

    if (track.coverAsset != null && track.coverAsset!.isNotEmpty) {
      final isNetwork = track.coverAsset!.startsWith('http://') || track.coverAsset!.startsWith('https://');
      return ClipRRect(
        borderRadius: borderRadius,
        child: isNetwork
            ? Image.network(
                track.coverAsset!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultCover();
                },
              )
            : Image.asset(
                track.coverAsset!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
              ),
      );
    }

    return _buildDefaultCover();
  }

  Widget _buildAlbumOrFallback(int cacheDimension) {
    if (track.albumId != null) {
      return QueryArtworkWidget(
        id: track.albumId!,
        type: ArtworkType.ALBUM,
        size: cacheDimension,
        artworkWidth: size,
        artworkHeight: size,
        artworkBorder: borderRadius,
        artworkFit: BoxFit.cover,
        artworkQuality: FilterQuality.low,
        keepOldArtwork: true,
        nullArtworkWidget: _buildDefaultCover(),
        errorBuilder: (context, exception, stackTrace) => _buildDefaultCover(),
      );
    }
    return _buildDefaultCover();
  }

  /// Gambar default elegan saat file audio tidak memiliki cover embedded
  Widget _buildDefaultCover() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D2530),
            Color(0xFF081820),
            Color(0xFF030A0E),
          ],
        ),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: Image.asset(
            'assets/images/logo_flowy.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.music_note_rounded,
                color: AppColors.primary,
                size: size * 0.45,
              );
            },
          ),
        ),
      ),
    );
  }
}
