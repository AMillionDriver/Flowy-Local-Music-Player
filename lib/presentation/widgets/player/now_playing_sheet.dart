import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../../../data/services/lyrics_service.dart';
import '../../controllers/player_controller.dart';
import '../common/track_artwork.dart';

class NowPlayingSheet extends StatefulWidget {
  final PlayerController controller;

  const NowPlayingSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, PlayerController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      enableDrag: true,
      builder: (context) => NowPlayingSheet(controller: controller),
    );
  }

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isLyricsExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final track = widget.controller.currentTrack;
        final screenHeight = MediaQuery.sizeOf(context).height;

        if (track == null) {
          return Container(
            height: 240,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const Center(
              child: Text('Tidak ada lagu yang sedang diputar'),
            ),
          );
        }

        return Container(
          height: screenHeight * 0.94,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
                AppColors.surface,
                AppColors.background,
              ],
            ),
          ),
          child: Stack(
            children: [
              // 1. Ambient Glow Orbs in background
              _buildAmbientGlowOrbs(),

              // 2. Main Content
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Drag Handle Indicator
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Top App Bar / Header
                    _buildTopHeader(context),

                    // Scrollable Player Body
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),

                            // Artwork with subtle gradient and glow
                            _buildArtwork(track),

                            const SizedBox(height: 20),

                            // Track Title, Artist, Hi-Res Badge & Favorite/Share
                            _buildMetadataSection(track),

                            const SizedBox(height: 16),

                            // Scrubber / Progress Bar & Timers
                            _buildScrubber(),

                            const SizedBox(height: 8),

                            // Playback Controls Row (Shuffle, Prev, Play/Pause, Next, Repeat)
                            _buildPlaybackControls(),

                            const SizedBox(height: 20),

                            // Synced Lyrics Card (interactive)
                            _buildLyricsCard(track),

                            const SizedBox(height: 16),

                            // Audio Output Selector & Sleep Timer Footer
                            _buildAudioToolsFooter(context),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmbientGlowOrbs() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top Ambient Glow
            Positioned(
              top: -80,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryContainer.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Mid Left Glow
            Positioned(
              top: 180,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondaryContainer.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Right Glow
            Positioned(
              bottom: 60,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            tooltip: 'Tutup Pemutar',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: AppColors.onSurfaceVariant),
            onPressed: () => Navigator.pop(context),
          ),

          // Header Center Title
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MEMUTAR DARI DAFTAR PUTAR',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outline,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Daftar Putar Pribadi',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // More Options button
          IconButton(
            tooltip: 'Opsi Pemutaran',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.more_vert, size: 24, color: AppColors.onSurfaceVariant),
            onPressed: () => _showMoreSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(Track track) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artSize = (screenWidth - 48).clamp(240.0, 330.0);

    return Center(
      child: TrackArtwork(
        track: track,
        size: artSize,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF051015).withValues(alpha: 0.8),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildMetadataSection(dynamic track) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Track Title, Artist, & Hi-Res Badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: AppTypography.headlineLg.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      track.artist,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${track.audioFormat}${track.sampleRate != null ? ' • ${track.sampleRate}' : ''}',
                      style: AppTypography.monoMetric.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryFixed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Actions: Favorite and Share
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: track.isFavorite ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  track.isFavorite ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey<bool>(track.isFavorite),
                  color: track.isFavorite ? AppColors.primary : AppColors.outline,
                  size: 26,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.controller.toggleFavorite(track.id);
              },
            ),
            IconButton(
              tooltip: 'Bagikan Musik',
              icon: const Icon(Icons.share_outlined, color: AppColors.outline, size: 22),
              onPressed: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tautan lagu "${track.title}" disalin ke papan klip.'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.surfaceContainerHigh,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScrubber() {
    final progress = widget.controller.playbackProgress;
    final elapsed = widget.controller.formattedElapsedTime;
    final total = widget.controller.formattedTotalDuration;

    return Column(
      children: [
        // Slider widget with customized theme matching Stitch progress track
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.surfaceContainerHighest,
            thumbColor: AppColors.primaryFixed,
            overlayColor: AppColors.primary.withValues(alpha: 0.16),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: (val) {
              widget.controller.seekTo(val);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                elapsed,
                style: AppTypography.monoMetric.copyWith(
                  fontSize: 12,
                  color: AppColors.outline,
                ),
              ),
              Text(
                total,
                style: AppTypography.monoMetric.copyWith(
                  fontSize: 12,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final isPlaying = widget.controller.isPlaying;
    final isShuffle = widget.controller.isShuffle;
    final isRepeat = widget.controller.isRepeat;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle Toggle
        IconButton(
          tooltip: 'Putar Acak',
          icon: Icon(
            Icons.shuffle,
            size: 22,
            color: isShuffle ? AppColors.primary : AppColors.outline,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.controller.toggleShuffle();
          },
        ),

        // Previous
        IconButton(
          tooltip: 'Sebelumnya',
          icon: const Icon(
            Icons.skip_previous,
            size: 34,
            color: AppColors.onSurface,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.controller.previousTrack();
          },
        ),

        // Large Play/Pause FAB
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.controller.togglePlayPause();
              },
              child: Center(
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 36,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ),

        // Next
        IconButton(
          tooltip: 'Berikutnya',
          icon: const Icon(
            Icons.skip_next,
            size: 34,
            color: AppColors.onSurface,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.controller.nextTrack();
          },
        ),

        // Repeat Toggle
        IconButton(
          tooltip: 'Ulangi',
          icon: Icon(
            Icons.repeat,
            size: 22,
            color: isRepeat ? AppColors.primary : AppColors.outline,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.controller.toggleRepeat();
          },
        ),
      ],
    );
  }

  Widget _buildLyricsCard(Track track) {
    final syncedLyrics = track.syncedLyrics;
    final activeIndex = widget.controller.currentLyricIndex;
    final isLoading = widget.controller.isLyricsLoading;

    // Jika lagu instrumental
    if (track.isInstrumental) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Lagu Instrumental • Tanpa Lirik Vokal',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Jika sedang loading dan belum ada lirik
    if (isLoading && syncedLyrics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Mencari lirik sinkron di LRCLIB...',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (syncedLyrics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lyrics_outlined, color: AppColors.outline, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lirik belum tersedia untuk lagu ini.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cari Ulang Lirik',
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
              onPressed: () {
                widget.controller.fetchLyricsManual();
              },
            ),
          ],
        ),
      );
    }

    // Badge label sumber lirik
    String sourceLabel = 'Lirik Tersinkronisasi';
    IconData sourceIcon = Icons.sync;
    if (track.lyricsSource == LyricsSource.localSidecar) {
      sourceLabel = 'Lirik Lokal (.lrc)';
      sourceIcon = Icons.sd_storage_outlined;
    } else if (track.lyricsSource == LyricsSource.lrclibSynced) {
      sourceLabel = 'Tersinkronisasi • LRCLIB';
      sourceIcon = Icons.cloud_done_outlined;
    } else if (track.lyricsSource == LyricsSource.internalCache) {
      sourceLabel = 'Tersimpan Offline';
      sourceIcon = Icons.offline_pin_outlined;
    } else if (track.lyricsSource == LyricsSource.lrclibPlain) {
      sourceLabel = 'Lirik Teks • LRCLIB';
      sourceIcon = Icons.text_snippet_outlined;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF051015).withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Lirik dengan Badge Sumber & Tombol Expand
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lyrics, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lirik',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Source Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sourceIcon, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          sourceLabel,
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: _isLyricsExpanded ? 'Perkecil Lirik' : 'Perbesar Lirik',
                icon: Icon(
                  _isLyricsExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: AppColors.outline,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isLyricsExpanded = !_isLyricsExpanded;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Baris-baris lirik dengan efek pendar & tap-to-seek interaktif
          ...List.generate(syncedLyrics.length, (index) {
            final isCurrent = index == activeIndex;
            // Mode ringkas (collapsed): tampilkan baris di sekitar baris aktif
            if (!_isLyricsExpanded && syncedLyrics.length > 6 && (index < activeIndex - 1 || index > activeIndex + 3)) {
              return const SizedBox.shrink();
            }

            final line = syncedLyrics[index];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.selectionClick();
                widget.controller.seekToLyric(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isCurrent) ...[
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        line.text,
                        style: isCurrent
                            ? AppTypography.headlineSm.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryFixed,
                                height: 1.4,
                                shadows: [
                                  Shadow(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              )
                            : AppTypography.bodyMd.copyWith(
                                fontSize: 15,
                                color: AppColors.outline.withValues(alpha: 0.75),
                                height: 1.4,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAudioToolsFooter(BuildContext context) {
    final selectedOutput = widget.controller.selectedAudioOutput;
    final sleepTimerMinutes = widget.controller.sleepTimerMinutes;

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Audio Output Device Pill
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAudioOutputSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speaker_group, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    selectedOutput,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tools: Sleep Timer & Queue Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: sleepTimerMinutes > 0
                    ? 'Timer Tidur Aktif ($sleepTimerMinutes menit)'
                    : 'Timer Tidur',
                icon: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: sleepTimerMinutes > 0 ? AppColors.primary : AppColors.outline,
                ),
                onPressed: () => _showSleepTimerSheet(context),
              ),
              IconButton(
                tooltip: 'Antrean Pemutaran',
                icon: const Icon(Icons.queue_music, size: 20, color: AppColors.outline),
                onPressed: () => _showQueueSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAudioOutputSheet(BuildContext context) {
    final outputs = [
      'DAC Eksternal • 96kHz',
      'Speaker Perangkat (Bawaan)',
      'Bluetooth LDAC • 24bit/96kHz',
      'USB Bit-Perfect Mode',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perutean Output Audio',
                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...outputs.map((out) {
                  final isSelected = widget.controller.selectedAudioOutput == out;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      out.contains('DAC')
                          ? Icons.speaker_group
                          : out.contains('Bluetooth')
                              ? Icons.bluetooth_audio
                              : Icons.smartphone,
                      color: isSelected ? AppColors.primary : AppColors.outline,
                    ),
                    title: Text(
                      out,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      widget.controller.setAudioOutput(out);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    final durations = [0, 15, 30, 45, 60];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timer Tidur Otomatis',
                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...durations.map((mins) {
                  final isSelected = widget.controller.sleepTimerMinutes == mins;
                  final label = mins == 0 ? 'Matikan Timer Tidur' : '$mins Menit';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      mins == 0 ? Icons.timer_off_outlined : Icons.timer_outlined,
                      color: isSelected ? AppColors.primary : AppColors.outline,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                        : null,
                    onTap: () {
                      widget.controller.setSleepTimer(mins);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(mins == 0
                              ? 'Timer tidur dinonaktifkan.'
                              : 'Pemutaran akan berhenti dalam $mins menit.'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.surfaceContainerHighest,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueueSheet(BuildContext context) {
    final tracks = widget.controller.filteredTracks;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Antrean Berikutnya',
                    style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, idx) {
                      final t = tracks[idx];
                      final isCurrent = t.id == widget.controller.currentTrack?.id;
                      return ListTile(
                        leading: TrackArtwork(
                          track: t,
                          size: 40,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        title: Text(
                          t.title,
                          style: TextStyle(
                            color: isCurrent ? AppColors.primary : AppColors.onSurface,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${t.artist} • ${t.duration}',
                          style: AppTypography.bodySm,
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.graphic_eq, color: AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          widget.controller.playTrack(t);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreSheet(BuildContext context) {
    final track = widget.controller.currentTrack;
    if (track == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.album_outlined, color: AppColors.primary),
                  title: Text('Lihat Album "${track.album}"'),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.equalizer, color: AppColors.secondary),
                  title: const Text('Pengaturan Equalizer 10-Band'),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: AppColors.onSurfaceVariant),
                  title: const Text('Tambahkan ke Daftar Putar Lain'),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text(
                    'Hapus Lagu...',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(context, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hapus Lagu',
                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih tindakan penghapusan untuk "${track.title}":',
                  style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                ),
                const SizedBox(height: 18),
                ListTile(
                  tileColor: AppColors.surfaceContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.playlist_remove, color: Colors.amberAccent),
                  title: const Text('Hapus dari Daftar Putar Saja', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Berkas fisik tetap aman di memori perangkat.', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.removeTrackFromListOnly(track.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${track.title}" disembunyikan dari daftar.')),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.red.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Hapus Permanen dari Perangkat', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Berkas fisik akan dihapus dari penyimpanan HP atau kartu SD.', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await widget.controller.deleteTrackPermanently(track);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Berkas "${track.title}" berhasil dihapus dari perangkat.'
                              : 'Penghapusan dibatalkan.',
                        ),
                        backgroundColor: success ? Colors.green[800] : AppColors.surfaceContainerHighest,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
