import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/jamendo_track.dart';
import '../controllers/player_controller.dart';
import '../widgets/catalog/bento_card.dart';
import '../../core/utils/fuzzy_search.dart';

class CatalogView extends StatefulWidget {
  final PlayerController controller;

  const CatalogView({super.key, required this.controller});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedGenre = 'Semua';
  final List<String> _genres = [
    'Semua',
    'Lofi',
    'Electronic',
    'Acoustic',
    'Ambient',
    'Rock',
    'Chillout',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.controller.jamendoCatalog.isEmpty) {
      widget.controller.loadJamendoCatalog();
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (!widget.controller.isCatalogLoadingMore &&
          widget.controller.hasMoreCatalog &&
          widget.controller.catalogSearchQuery.isEmpty) {
        widget.controller.loadMoreJamendoCatalog(
          genre: _selectedGenre == 'Semua' ? null : _selectedGenre,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.controller.jamendoCatalog;
    final isLoading = widget.controller.isCatalogLoading;

    if (isLoading && catalog.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Menghubungkan ke Katalog Jamendo...',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.outline),
              const SizedBox(height: 16),
              const Text(
                'Katalog Online Belum Termuat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan koneksi internet aktif untuk mengunduh daftar katalog sekali saja.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Muat Katalog Sekarang'),
                onPressed: () {
                  widget.controller.loadJamendoCatalog(forceRefresh: true);
                },
              ),
            ],
          ),
        ),
      );
    }

    final isSearching = widget.controller.catalogSearchQuery.isNotEmpty;
    final searchResults = widget.controller.catalogSearchResults;

    // Filter berdasarkan genre jika dipilih (hanya aktif di mode eksplorasi biasa)
    final filteredCatalog = _selectedGenre == 'Semua'
        ? catalog
        : catalog.where((t) {
            final q = _selectedGenre.toLowerCase();
            return t.name.toLowerCase().contains(q) ||
                t.tags.any((tag) => tag.toLowerCase().contains(q));
          }).toList();

    final featured = catalog.first;
    final trending1 = catalog.length > 1 ? catalog[1] : null;
    final trending2 = catalog.length > 2 ? catalog[2] : null;
    final moreTracks = filteredCatalog.skip(3).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerHigh,
      onRefresh: () async {
        await widget.controller.loadJamendoCatalog(forceRefresh: true);
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 96),
        children: [
          // Header Jelajah
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jelajah Musik Bebas Royalti',
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryFixed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Katalog Legal • Single-Call Cache • Siap Unduh',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Perbarui Katalog',
                icon: const Icon(Icons.sync, color: AppColors.primary, size: 22),
                onPressed: () {
                  widget.controller.loadJamendoCatalog(forceRefresh: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Bar Katalog Online
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari judul lagu, artis, atau genre di Jamendo...',
                hintStyle: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          widget.controller.clearCatalogSearch();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {});
                widget.controller.searchJamendo(
                  val,
                  genre: _selectedGenre == 'Semua' ? null : _selectedGenre,
                );
              },
            ),
          ),
          if (widget.controller.isCatalogSearching) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: AppColors.primary,
              minHeight: 2,
            ),
          ],
          // Suggestion Chips (Toleransi Typo ala Fuse Search)
          Builder(
            builder: (context) {
              final q = _searchController.text.trim();
              if (q.length < 2) return const SizedBox.shrink();
              final suggestions = FuzzySearchEngine.getSuggestions(
                query: q,
                candidatePhrases: {
                  ...catalog.map((t) => t.name),
                  ...catalog.map((t) => t.artistName),
                  ..._genres.where((g) => g != 'Semua'),
                },
                maxSuggestions: 3,
              );
              if (suggestions.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final sug = suggestions[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _searchController.text = sug;
                          widget.controller.searchJamendo(
                            sug,
                            genre: _selectedGenre == 'Semua' ? null : _selectedGenre,
                          );
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppColors.primaryFixed,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                sug,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primaryFixed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Jika sedang mencari lagu secara spesifik:
          if (isSearching) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hasil Pencarian Online',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${searchResults.length} Ditemukan',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (searchResults.isEmpty && !widget.controller.isCatalogSearching)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 40, color: AppColors.outline),
                    SizedBox(height: 8),
                    Text(
                      'Tidak ada lagu yang cocok dengan pencarian.',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(searchResults.length, (index) {
                return _buildTrackListTile(searchResults[index]);
              }),
          ] else ...[
            // Mode Normal: Genre Pill Chips Horizontal
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _genres.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final genre = _genres[index];
                  final isSelected = genre == _selectedGenre;
                  return ChoiceChip(
                    label: Text(genre),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedGenre = genre;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Bento Section: Populer Unggulan
            BentoFeaturedCard(
              track: featured,
              onPlayTap: () => widget.controller.playJamendoTrack(featured),
              onDownloadTap: () => _downloadTrack(featured),
              downloadProgress: widget.controller.downloadProgress[featured.id],
            ),
            const SizedBox(height: 14),

            // Bento Section: 2 Kartu Tren Berdampingan
            if (trending1 != null && trending2 != null)
              Row(
                children: [
                  Expanded(
                    child: BentoMiniCard(
                      track: trending1,
                      onPlayTap: () => widget.controller.playJamendoTrack(trending1),
                      onDownloadTap: () => _downloadTrack(trending1),
                      downloadProgress: widget.controller.downloadProgress[trending1.id],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BentoMiniCard(
                      track: trending2,
                      onPlayTap: () => widget.controller.playJamendoTrack(trending2),
                      onDownloadTap: () => _downloadTrack(trending2),
                      downloadProgress: widget.controller.downloadProgress[trending2.id],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Section Header: Koleksi Terpilih
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Koleksi Terpilih',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${moreTracks.length} Lagu',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // More Tracks List Tile Vertikal
            ...List.generate(moreTracks.length, (index) {
              return _buildTrackListTile(moreTracks[index]);
            }),

            // Load More / Pagination Area
            if (widget.controller.isCatalogLoadingMore) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Memuat lagu berikutnya dari Jamendo...',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (widget.controller.hasMoreCatalog) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Muat Lebih Banyak Lagu'),
                    onPressed: () {
                      widget.controller.loadMoreJamendoCatalog(
                        genre: _selectedGenre == 'Semua' ? null : _selectedGenre,
                      );
                    },
                  ),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Semua lagu untuk kategori ini telah dimuat',
                    style: TextStyle(color: AppColors.outline, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTrackListTile(JamendoTrack track) {
    final p = widget.controller.downloadProgress[track.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.imageUrl.isNotEmpty
              ? Image.network(
                  track.imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _listFallback(),
                )
              : _listFallback(),
        ),
        title: Text(
          track.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${track.artistName} • ${track.formattedDuration}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Download Button / Progress
            if (p != null && p > 0 && p < 1)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: p,
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              IconButton(
                tooltip: 'Unduh Lagu',
                icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.outline),
                onPressed: () => _downloadTrack(track),
              ),
            // Play Stream Button
            IconButton(
              tooltip: 'Putar Lagu',
              icon: const Icon(Icons.play_circle_fill, size: 28, color: AppColors.primary),
              onPressed: () => widget.controller.playJamendoTrack(track),
            ),
          ],
        ),
        onTap: () => widget.controller.playJamendoTrack(track),
      ),
    );
  }

  void _downloadTrack(JamendoTrack track) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengunduh "${track.name}" ke folder Musik perangkat...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final success = await widget.controller.downloadJamendoTrack(track);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil! "${track.name}" tersimpan di folder Music/Flowy dan langsung muncul di koleksi.'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _listFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: AppColors.primary, size: 22),
    );
  }
}
