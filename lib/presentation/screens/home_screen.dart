import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/music_filter.dart';
import '../controllers/player_controller.dart';
import '../widgets/controls/quick_action_bar.dart';
import '../widgets/header/flowy_app_bar.dart';
import '../widgets/navigation/flowy_bottom_nav.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/player/now_playing_sheet.dart';
import '../widgets/search/filter_chips_row.dart';
import '../widgets/search/search_bar_widget.dart';
import '../widgets/track_list/active_track_card.dart';
import '../widgets/track_list/track_list_tile.dart';
import '../widgets/track_list/track_section_header.dart';
import 'catalog_view.dart';

class HomeScreen extends StatefulWidget {
  final PlayerController controller;

  const HomeScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PlayerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.detached:
        // Saat aplikasi di-kill dari recent apps: jika sedang pause, bersihkan notifikasi total
        if (!_controller.isPlaying) {
          _controller.audioService.stop();
        }
        _controller.setAppForegroundState(false);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Masuk Background (0% CPU & Memori Purgasi):
        _controller.setAppForegroundState(false);
        // Purgasi total cache gambar GPU Skia untuk membebaskan RAM bagi LMKD ColorOS
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        break;
      case AppLifecycleState.resumed:
        // Kembali ke Foreground:
        _controller.setAppForegroundState(true);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tracks = _controller.filteredTracks;
        final currentTrack = _controller.currentTrack;

        final isCatalogTab = _controller.currentNavIndex == 1;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              if (isCatalogTab)
                SafeArea(
                  bottom: false,
                  child: CatalogView(controller: _controller),
                )
              else
                // Scrollable Local Collection Content
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                  // App Bar with Wave & Stars Animation
                  SliverToBoxAdapter(
                    child: FlowyAppBar(
                      onTuneTap: () => _showFilterDialog(context),
                      onEqualizerTap: () => _showEqualizerDialog(context),
                    ),
                  ),

                  // Search Bar Container
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: SearchBarWidget(
                        initialValue: _controller.searchQuery,
                        suggestions: _controller.searchSuggestions,
                        onChanged: _controller.setSearchQuery,
                        onClear: _controller.clearSearch,
                      ),
                    ),
                  ),

                  // Horizontal Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilterChipsRow(
                        filters: MusicFilter.defaults,
                        activeFilterId: _controller.activeFilterId,
                        onFilterSelected: _controller.setFilter,
                      ),
                    ),
                  ),

                  // Quick Action Controls (Shuffle + Sort + Scan)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: QuickActionBar(
                        onShuffleTap: _controller.shuffleAll,
                        onSortTap: _controller.toggleSort,
                        sortLabel: _controller.sortLabel,
                        onScanTap: () => _scanLocalFiles(context),
                        isScanning: _controller.isScanning,
                      ),
                    ),
                  ),

                  // Active Track Section
                  if (currentTrack != null && tracks.any((t) => t.id == currentTrack.id)) ...[
                    const SliverToBoxAdapter(
                      child: TrackSectionHeader(
                        leftText: 'Sedang • Diputar',
                        rightText: 'Hi-Res Audio Engine',
                        isHiResAccent: true,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ActiveTrackCard(
                        track: currentTrack,
                        isPlaying: _controller.isPlaying,
                        onTap: _controller.togglePlayPause,
                        onFavoriteTap: () =>
                            _controller.toggleFavorite(currentTrack.id),
                        onOptionsTap: () => _showTrackOptions(context, currentTrack),
                      ),
                    ),
                  ],

                  // Secondary Track Section Divider
                  if (tracks.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: TrackSectionHeader(
                          leftText: 'Daftar Putar Pribadi',
                          rightText: 'Format Bebas Kompresi',
                        ),
                      ),
                    ),

                    // Inactive Tracks List
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = tracks[index];
                          // Skip active track in secondary list if it's already shown as active card
                          if (currentTrack != null && track.id == currentTrack.id) {
                            return const SizedBox.shrink();
                          }

                          return TrackListTile(
                            track: track,
                            onTap: () => _controller.playTrack(track),
                            onFavoriteTap: () =>
                                _controller.toggleFavorite(track.id),
                            onOptionsTap: () =>
                                _showTrackOptions(context, track),
                          );
                        },
                        childCount: tracks.length,
                      ),
                    ),
                  ] else ...[
                    // Empty State (Anti-Slop Resilience R-27)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _controller.tracks.isEmpty
                                      ? Icons.folder_open_rounded
                                      : Icons.music_off,
                                  color: AppColors.outline,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _controller.tracks.isEmpty
                                    ? 'Belum Ada Lagu di Penyimpanan'
                                    : 'Tidak Ada Lagu Ditemukan',
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _controller.tracks.isEmpty
                                    ? 'Pindai berkas audio lokal di memori internal atau kartu SD Anda.'
                                    : 'Coba sesuaikan kata kunci atau filter pencarian Anda.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.outline,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_controller.tracks.isEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Pindai Berkas Audio'),
                                  onPressed: () => _scanLocalFiles(context),
                                )
                              else ...[
                                if (_controller.searchQuery.isNotEmpty) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryContainer,
                                      foregroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                    ),
                                    icon: const Icon(Icons.explore, size: 18),
                                    label: const Text('Cari di Katalog Jamendo'),
                                    onPressed: () {
                                      _controller.setNavIndex(1);
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primaryContainer,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Reset Filter & Pencarian'),
                                  onPressed: () {
                                    _controller.clearSearch();
                                    _controller.setFilter('all');
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Padding to avoid mini-player and bottom navigation overlap
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 140),
                  ),
                ],
              ),

              // Bottom Overlay: Mini Player & Navigation Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentTrack != null)
                      MiniPlayer(
                        track: currentTrack,
                        isPlaying: _controller.isPlaying,
                        progress: _controller.playbackProgress,
                        onPlayPauseTap: _controller.togglePlayPause,
                        onNextTap: _controller.nextTrack,
                        onPreviousTap: _controller.previousTrack,
                        onTap: () => _showNowPlayingSheet(context),
                      ),
                    const SizedBox(height: 8),
                    FlowyBottomNav(
                      currentIndex: _controller.currentNavIndex,
                      onTabSelected: _controller.setNavIndex,
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

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter Koleksi Musik', style: AppTypography.headlineSm),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha, color: AppColors.primary),
                  title: const Text('Urutkan berdasarkan Judul'),
                  onTap: () {
                    if (_controller.sortMode != SortMode.title) {
                      _controller.toggleSort();
                    }
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer, color: AppColors.primary),
                  title: const Text('Urutkan berdasarkan Durasi'),
                  onTap: () {
                    if (_controller.sortMode != SortMode.duration) {
                      _controller.toggleSort();
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEqualizerDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hi-Res Audio Engine: 24-bit / 96kHz Lossless Active'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _scanLocalFiles(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('Memindai penyimpanan internal & kartu SD...'),
          ],
        ),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final count = await _controller.scanLocalAudio();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Berhasil menemukan $count lagu di perangkat.'
              : 'Pemindaian selesai: Tidak ada berkas musik baru yang ditemukan.',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: count > 0 ? AppColors.surfaceContainerHighest : AppColors.surfaceContainerHigh,
      ),
    );
  }

  void _showTrackOptions(BuildContext context, dynamic track) {
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
                Text(track.title, style: AppTypography.headlineSm),
                const SizedBox(height: 2),
                Text(
                  '${track.artist} • ${track.audioFormat}${track.filePath != null ? ' • Lokal' : ''}',
                  style: AppTypography.bodySm,
                ),
                const Divider(height: 24, color: AppColors.surfaceContainerHighest),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.playlist_add, color: AppColors.primary),
                  title: const Text('Tambahkan ke Daftar Putar'),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline, color: AppColors.secondary),
                  title: const Text('Rincian Audio Hi-Res'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTrackDetailsDialog(context, track);
                  },
                ),
                // Opsi Hapus Lagu
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text(
                    'Hapus Lagu...',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTrackDeleteModal(context, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTrackDetailsDialog(BuildContext context, dynamic track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(track.title, style: AppTypography.headlineSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Artis: ${track.artist}', style: AppTypography.bodyMd),
            Text('Album: ${track.album}', style: AppTypography.bodyMd),
            Text('Format: ${track.audioFormat}', style: AppTypography.bodyMd),
            Text('Durasi: ${track.duration}', style: AppTypography.bodyMd),
            if (track.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lokasi Berkas:\n${track.filePath}',
                style: AppTypography.monoTag.copyWith(fontSize: 10, color: AppColors.outline),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showTrackDeleteModal(BuildContext context, dynamic track) {
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
                  'Pilih metode penghapusan untuk "${track.title}":',
                  style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                ),
                const SizedBox(height: 18),

                // Pilihan 1: Hapus dari daftar aplikasi saja (Soft delete)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_remove, color: Colors.amberAccent),
                    ),
                    title: const Text(
                      'Hapus dari Daftar Putar Saja',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Berkas fisik tetap tersimpan aman di memori perangkat.',
                      style: AppTypography.bodySm.copyWith(fontSize: 12, color: AppColors.outline),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _controller.removeTrackFromListOnly(track.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${track.title}" disembunyikan dari daftar.'),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'Urungkan',
                            textColor: AppColors.primary,
                            onPressed: () => _controller.restoreHiddenTracks(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Pilihan 2: Hapus permanen dari memori HP / SD Card (Hard delete)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    ),
                    title: const Text(
                      'Hapus Permanen dari Perangkat',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Berkas audio asli akan dihapus dari penyimpanan HP atau kartu SD.',
                      style: AppTypography.bodySm.copyWith(fontSize: 12, color: AppColors.outline),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmHardDelete(context, track);
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

  void _confirmHardDelete(BuildContext context, dynamic track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 10),
            Text('Hapus Berkas Asli?'),
          ],
        ),
        content: Text(
          'Tindakan ini akan menghapus berkas "${track.title}" dari penyimpanan perangkat Anda secara permanen. Apakah Anda yakin?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final isSuccess = await _controller.deleteTrackPermanently(track);
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isSuccess
                        ? 'Berkas "${track.title}" berhasil dihapus dari perangkat.'
                        : 'Penghapusan dibatalkan atau izin tidak diberikan.',
                  ),
                  backgroundColor: isSuccess ? Colors.green[800] : AppColors.surfaceContainerHighest,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  void _showNowPlayingSheet(BuildContext context) {
    NowPlayingSheet.show(context, _controller);
  }
}
