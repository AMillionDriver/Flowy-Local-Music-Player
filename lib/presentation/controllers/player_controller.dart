import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/track.dart';
import '../../data/models/jamendo_track.dart';
import '../../data/models/lyric_line.dart';
import '../../data/repositories/track_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/lyrics_service.dart';
import '../../data/services/jamendo_service.dart';
import '../../data/services/music_download_service.dart';
import '../../data/services/lrc_parser.dart';
import '../../data/services/media_deletion_service.dart';
import '../../core/utils/fuzzy_search.dart';

enum SortMode {
  recent,
  title,
  duration,
}

class PlayerController extends ChangeNotifier {
  final TrackRepository _repository;
  final AudioPlayerService _audioService;
  final LyricsService _lyricsService;
  final JamendoService _jamendoService;
  final MusicDownloadService _downloadService;

  List<Track> _tracks = [];
  Track? _currentTrack;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration? _actualDuration;

  String _activeFilterId = 'all';
  String _searchQuery = '';
  int _currentNavIndex = 0; // 0 = Koleksi, 1 = Jelajah, 2 = Favorit
  SortMode _sortMode = SortMode.recent;

  bool _isShuffle = false;
  bool _isRepeat = false;
  String _selectedAudioOutput = 'DAC Eksternal • 96kHz';
  int _sleepTimerMinutes = 0;
  int _currentLyricIndex = 0;
  bool _isLyricsLoading = false;
  bool _isScanning = false;
  bool _isAppForeground = true;
  int _lastPositionNotifyMs = 0;

  // State Katalog Online Jamendo
  List<JamendoTrack> _jamendoCatalog = [];
  bool _isCatalogLoading = false;
  bool _isCatalogLoadingMore = false;
  bool _hasMoreCatalog = true;
  String _catalogSearchQuery = '';
  List<JamendoTrack> _catalogSearchResults = [];
  bool _isCatalogSearching = false;
  List<String> _searchSuggestions = [];
  final Map<String, double> _downloadProgress = {};
  final Map<int, int> _playCounts = {};

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  PlayerController({
    TrackRepository? repository,
    AudioPlayerService? audioService,
    LyricsService? lyricsService,
    JamendoService? jamendoService,
    MusicDownloadService? downloadService,
    bool autoScan = true,
  })  : _repository = repository ?? TrackRepository(),
        _audioService = audioService ?? AudioPlayerService(),
        _lyricsService = lyricsService ?? LyricsService(),
        _jamendoService = jamendoService ?? JamendoService(),
        _downloadService = downloadService ?? MusicDownloadService() {
    _tracks = List<Track>.from(_repository.getTracks());
    if (_tracks.isNotEmpty) {
      _currentTrack = _tracks.first;
      _currentLyricIndex = _currentTrack!.activeLyricIndex;
    }

    _setupAudioStreams();

    // Otomatis memindai lagu lokal perangkat saat aplikasi diinisialisasi jika autoScan aktif
    if (autoScan) {
      scanLocalAudio();
    }
  }

  void _setupAudioStreams() {
    _audioService.handler.onSkipToNext = () {
      nextTrack();
    };

    _audioService.handler.onSkipToPrevious = () {
      previousTrack();
    };

    _audioService.handler.onStop = () {
      _isPlaying = false;
      notifyListeners();
    };

    _positionSub = _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      final totalMs = _totalDurationMilliseconds;
      if (totalMs > 0) {
        _playbackProgress = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
      }

      bool lyricIndexChanged = false;
      // Sinkronisasi Lirik Realtime menggunakan Binary Search O(log N)
      if (_currentTrack != null && _currentTrack!.syncedLyrics.isNotEmpty) {
        final newIndex = LrcParser.findActiveIndex(_currentTrack!.syncedLyrics, pos);
        if (newIndex != _currentLyricIndex && newIndex >= 0) {
          _currentLyricIndex = newIndex;
          lyricIndexChanged = true;
        }
      }

      // Optimasi UI Thread (Mencegah ANR pada Oppo A16 Helio G35):
      // Hanya rebuild UI saat lirik berubah atau paling sering tiap 100ms (10 FPS)
      if (_isAppForeground) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (lyricIndexChanged || (nowMs - _lastPositionNotifyMs >= 100)) {
          _lastPositionNotifyMs = nowMs;
          notifyListeners();
        }
      }
    });

    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _actualDuration = dur;
        if (_isAppForeground) {
          notifyListeners();
        }
      }
    });

    _playerStateSub = _audioService.playerStateStream.listen((state) {
      final playing = state.playing && state.processingState != ProcessingState.completed;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }

      if (state.processingState == ProcessingState.completed) {
        if (_isRepeat) {
          _audioService.seek(Duration.zero);
          _audioService.resume();
        } else {
          nextTrack();
        }
      }
    });
  }

  List<Track> get tracks => _tracks;
  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  double get playbackProgress => _playbackProgress;
  Duration get currentPosition => _currentPosition;
  Duration? get actualDuration => _actualDuration;
  String get activeFilterId => _activeFilterId;
  String get searchQuery => _searchQuery;
  List<String> get searchSuggestions => _searchSuggestions;
  int get currentNavIndex => _currentNavIndex;
  SortMode get sortMode => _sortMode;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  String get selectedAudioOutput => _selectedAudioOutput;
  int get sleepTimerMinutes => _sleepTimerMinutes;
  int get currentLyricIndex => _currentLyricIndex;
  bool get isLyricsLoading => _isLyricsLoading;
  bool get isScanning => _isScanning;
  int get hiddenTracksCount => _repository.hiddenTrackIds.length;
  bool get isAppForeground => _isAppForeground;
  AudioPlayerService get audioService => _audioService;
  List<JamendoTrack> get jamendoCatalog => _jamendoCatalog;
  bool get isCatalogLoading => _isCatalogLoading;
  bool get isCatalogLoadingMore => _isCatalogLoadingMore;
  bool get hasMoreCatalog => _hasMoreCatalog;
  String get catalogSearchQuery => _catalogSearchQuery;
  List<JamendoTrack> get catalogSearchResults => _catalogSearchResults;
  bool get isCatalogSearching => _isCatalogSearching;
  Map<String, double> get downloadProgress => _downloadProgress;

  /// Memuat katalog lagu Jamendo (Single-Call: prioritaskan cache JSON lokal di App Data)
  Future<void> loadJamendoCatalog({bool forceRefresh = false}) async {
    _isCatalogLoading = true;
    notifyListeners();
    try {
      final catalog = await _jamendoService.fetchAndCacheCatalog(forceRefresh: forceRefresh);
      _jamendoCatalog = catalog;
      _hasMoreCatalog = catalog.isNotEmpty;
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// Memuat lebih banyak lagu dari Jamendo API (Load More / Infinite Scroll)
  Future<void> loadMoreJamendoCatalog({String? genre}) async {
    if (_isCatalogLoadingMore || !_hasMoreCatalog) return;

    _isCatalogLoadingMore = true;
    notifyListeners();

    try {
      final nextTracks = await _jamendoService.fetchTracksOnline(
        offset: _jamendoCatalog.length,
        limit: 25,
        fuzzyTags: genre,
      );

      if (nextTracks.isEmpty) {
        _hasMoreCatalog = false;
      } else {
        // Gabungkan tanpa duplikasi ID
        final existingIds = _jamendoCatalog.map((t) => t.id).toSet();
        final newItems = nextTracks.where((t) => !existingIds.contains(t.id)).toList();
        if (newItems.isNotEmpty) {
          _jamendoCatalog.addAll(newItems);
          // Perbarui disk cache lokal
          await _jamendoService.saveCatalogToCache(_jamendoCatalog);
        } else {
          _hasMoreCatalog = false;
        }
      }
    } catch (e) {
      debugPrint('Error saat load more catalog: $e');
    } finally {
      _isCatalogLoadingMore = false;
      notifyListeners();
    }
  }

  /// Melakukan pencarian lagu di katalog Jamendo (Lokal dulu, lalu Online)
  Future<void> searchJamendo(String query, {String? genre}) async {
    _catalogSearchQuery = query;
    if (query.trim().isEmpty) {
      _isCatalogSearching = false;
      _catalogSearchResults.clear();
      notifyListeners();
      return;
    }

    _isCatalogSearching = true;
    // Cari cepat di memori/cache lokal terlebih dahulu
    _catalogSearchResults = _jamendoService.searchInLocalCatalog(_jamendoCatalog, query);
    notifyListeners();

    try {
      // Ambil hasil pencarian live dari Jamendo API
      final onlineResults = await _jamendoService.fetchTracksOnline(
        offset: 0,
        limit: 30,
        search: query,
        fuzzyTags: genre,
      );

      if (onlineResults.isNotEmpty && _catalogSearchQuery == query) {
        final existingIds = _catalogSearchResults.map((t) => t.id).toSet();
        final combined = List<JamendoTrack>.from(_catalogSearchResults);
        for (final item in onlineResults) {
          if (!existingIds.contains(item.id)) {
            combined.add(item);
            existingIds.add(item.id);
          }
        }
        _catalogSearchResults = combined;
      }
    } catch (e) {
      debugPrint('Error search Jamendo online: $e');
    } finally {
      _isCatalogSearching = false;
      notifyListeners();
    }
  }

  void clearCatalogSearch() {
    _catalogSearchQuery = '';
    _catalogSearchResults.clear();
    _isCatalogSearching = false;
    notifyListeners();
  }

  /// Memutar lagu langsung dari Jamendo (Streaming URL) dengan cover dan lirik
  Future<void> playJamendoTrack(JamendoTrack jTrack) async {
    List<LyricLine> lyrics = [];
    if (jTrack.lyricsText != null && jTrack.lyricsText!.trim().isNotEmpty) {
      lyrics = LrcParser.parse(jTrack.lyricsText!);
    }

    final track = Track(
      id: int.tryParse(jTrack.id) ?? Random().nextInt(999999),
      orderNumber: '01',
      title: jTrack.name,
      artist: jTrack.artistName,
      album: jTrack.albumName,
      audioFormat: 'MP3 • Jamendo',
      duration: jTrack.formattedDuration,
      durationMs: jTrack.duration * 1000,
      coverAsset: jTrack.imageUrl.isNotEmpty ? jTrack.imageUrl : null,
      contentUri: jTrack.audioUrl,
      sourceType: TrackSourceType.localDevice,
      tags: ['online', 'jamendo', ...jTrack.tags],
      syncedLyrics: lyrics,
      lyricsSource: lyrics.isNotEmpty ? LyricsSource.jamendo : LyricsSource.none,
      isInstrumental: lyrics.isEmpty && (jTrack.lyricsText == null || jTrack.lyricsText!.trim().isEmpty),
    );

    await playTrack(track);
  }

  /// Mengunduh lagu Jamendo ke memori penyimpanan perangkat
  Future<bool> downloadJamendoTrack(JamendoTrack jTrack) async {
    _downloadProgress[jTrack.id] = 0.01;
    notifyListeners();

    try {
      final file = await _downloadService.downloadTrack(
        track: jTrack,
        onProgress: (p) {
          _downloadProgress[jTrack.id] = p;
          notifyListeners();
        },
      );

      if (file != null && await file.exists()) {
        _downloadProgress[jTrack.id] = 1.0;
        
        // Buat objek Track lokal dan tambahkan langsung ke daftar lagu jika belum ada
        final hasLyrics = jTrack.lyricsText != null && jTrack.lyricsText!.trim().isNotEmpty;
        final newLocalTrack = Track(
          id: int.tryParse(jTrack.id) ?? Random().nextInt(999999),
          orderNumber: (_tracks.length + 1).toString().padLeft(2, '0'),
          title: jTrack.name,
          artist: jTrack.artistName,
          album: jTrack.albumName,
          audioFormat: 'MP3 • Jamendo (Downloaded)',
          duration: jTrack.formattedDuration,
          durationMs: jTrack.duration * 1000,
          coverAsset: jTrack.imageUrl.isNotEmpty ? jTrack.imageUrl : null,
          filePath: file.path,
          contentUri: 'file://${file.path}',
          sourceType: TrackSourceType.localDevice,
          tags: ['all', 'local', 'downloaded', ...jTrack.tags],
          isInstrumental: !hasLyrics,
          syncedLyrics: hasLyrics ? LrcParser.parse(jTrack.lyricsText!) : const [],
          lyricsSource: hasLyrics ? LyricsSource.jamendo : LyricsSource.none,
        );

        // 1. Simpan ke manifest persisten repository agar terjamin tersimpan di App Data
        await _repository.addDownloadedTrack(newLocalTrack);

        // 2. Sisipkan di posisi teratas koleksi lokal memori secara instan
        _tracks.removeWhere((t) =>
            t.id == newLocalTrack.id ||
            (t.filePath != null && t.filePath == newLocalTrack.filePath));
        _tracks.insert(0, newLocalTrack);

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error saat mendownload lagu ${jTrack.name}: $e');
    } finally {
      // Hapus status progress setelah beberapa saat
      Future.delayed(const Duration(seconds: 2), () {
        _downloadProgress.remove(jTrack.id);
        notifyListeners();
      });
    }
    return false;
  }

  /// Sinkronisasi siklus hidup: menonaktifkan trigger rebuild widget tree saat app di background
  void setAppForegroundState(bool isForeground) {
    if (_isAppForeground == isForeground) return;
    _isAppForeground = isForeground;
    if (isForeground) {
      // Sinkronkan UI seketika saat aplikasi kembali ke foreground
      notifyListeners();
    }
  }

  String get sortLabel {
    switch (_sortMode) {
      case SortMode.recent:
        return 'Terbaru';
      case SortMode.title:
        return 'Judul';
      case SortMode.duration:
        return 'Durasi';
    }
  }

  int get _totalSeconds {
    if (_currentTrack == null) return 0;
    final parts = _currentTrack!.duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return 0;
  }

  int get _totalDurationMilliseconds {
    if (_actualDuration != null && _actualDuration!.inMilliseconds > 0) {
      return _actualDuration!.inMilliseconds;
    }
    if (_currentTrack?.durationMs != null && _currentTrack!.durationMs! > 0) {
      return _currentTrack!.durationMs!;
    }
    return _totalSeconds * 1000;
  }

  String get formattedTotalDuration {
    if (_actualDuration != null && _actualDuration!.inSeconds > 0) {
      final totalSec = _actualDuration!.inSeconds;
      final m = (totalSec ~/ 60).toString().padLeft(2, '0');
      final s = (totalSec % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return _currentTrack?.duration ?? '00:00';
  }

  String get formattedElapsedTime {
    final totalSec = _currentPosition.inSeconds;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<Track> get filteredTracks {
    List<Track> list = List<Track>.from(_tracks);

    // 1. Navigation tab filtering:
    // Tab 0 = Koleksi Lokal (seluruh lagu lokal)
    // Tab 1 = Jelajah Katalog (ditangani oleh CatalogView)
    // Tab 2 = Favorit (hanya lagu favorit)
    if (_currentNavIndex == 2) {
      list = list.where((t) => t.isFavorite).toList();
    }

    // 2. Filter chip filtering
    if (_activeFilterId != 'all') {
      switch (_activeFilterId) {
        case 'recent':
          // Baru Ditambahkan: Urutkan berdasarkan ID terbesar (terbaru ditambahkan di sistem MediaStore / baru diunduh)
          list.sort((a, b) => b.id.compareTo(a.id));
          break;
        case 'frequent':
          // Sering Diputar: Urutkan berdasarkan riwayat frekuensi pemutaran lagu
          final played = list.where((t) => (_playCounts[t.id] ?? 0) > 0).toList();
          if (played.isNotEmpty) {
            played.sort((a, b) => (_playCounts[b.id] ?? 0).compareTo(_playCounts[a.id] ?? 0));
            list = played;
          } else {
            // Jika belum ada riwayat putar sesi ini, tampilkan lagu favorit
            final favs = list.where((t) => t.isFavorite).toList();
            if (favs.isNotEmpty) {
              list = favs;
            }
          }
          break;
        case 'lofi':
          // Instrumen • Lofi: Cari trek santai / instrumental / ambient / lofi
          const lofiKeywords = [
            'lofi', 'lo-fi', 'instrument', 'ambient', 'chill', 'piano',
            'acoustic', 'relax', 'sleep', 'study', 'soundtrack', 'rain'
          ];
          list = list.where((t) {
            if (t.isInstrumental) return true;
            final searchSpace = '${t.title} ${t.artist} ${t.album} ${t.tags.join(" ")}'.toLowerCase();
            return lofiKeywords.any((kw) => searchSpace.contains(kw));
          }).toList();
          break;
        case 'flac':
          // FLAC Lossless / Studio Master Hi-Res Audio
          list = list.where((t) {
            final fmt = t.audioFormat.toLowerCase();
            return fmt.contains('flac') ||
                fmt.contains('lossless') ||
                fmt.contains('wav') ||
                fmt.contains('24bit') ||
                fmt.contains('hi-res') ||
                fmt.contains('96khz') ||
                fmt.contains('alac');
          }).toList();
          break;
        default:
          list = list.where((t) => t.tags.contains(_activeFilterId) || t.audioFormat.toLowerCase().contains(_activeFilterId)).toList();
          break;
      }
    }

    // 3. Search query filtering (Fuzzy Search dengan toleransi typo ala Fuse.js)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim();
      final scored = <MapEntry<Track, double>>[];
      for (final track in list) {
        final score = FuzzySearchEngine.scoreItem(
          query: query,
          title: track.title,
          artist: track.artist,
          album: track.album,
          tags: track.tags,
        );
        // Ambang batas toleransi typo: 0.50
        if (score >= 0.50) {
          scored.add(MapEntry(track, score));
        }
      }
      // Urutkan berdasarkan relevansi kecocokan tertinggi
      scored.sort((a, b) => b.value.compareTo(a.value));
      list = scored.map((e) => e.key).toList();
    }

    // 4. Sort mode
    switch (_sortMode) {
      case SortMode.recent:
        if (_activeFilterId != 'recent' && _activeFilterId != 'frequent') {
          // Tetap gunakan urutan asli atau urut id
        }
        break;
      case SortMode.title:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortMode.duration:
        list.sort((a, b) => a.duration.compareTo(b.duration));
        break;
    }

    return list;
  }

  Future<void> playTrack(Track track) async {
    _playCounts[track.id] = (_playCounts[track.id] ?? 0) + 1;
    _currentTrack = track;
    _currentPosition = Duration.zero;
    _actualDuration = null;
    _playbackProgress = 0.0;
    _currentLyricIndex = track.activeLyricIndex;
    _isPlaying = true;
    notifyListeners();

    // Sinkronkan antrean lagu mandiri ke background audio handler
    final activeIdx = _tracks.indexWhere((t) => t.id == track.id);
    _audioService.handler.updatePlaylist(_tracks, activeIndex: activeIdx != -1 ? activeIdx : 0);

    // Jalankan pemutaran audio
    final success = await _audioService.playTrack(track);
    if (!success) {
      _isPlaying = false;
      notifyListeners();
      return;
    }

    // Ambil lirik sinkron secara asinkron jika belum tersedia
    if (track.syncedLyrics.isEmpty && !track.isInstrumental) {
      _fetchLyricsForTrack(track);
    }
  }

  Future<void> _fetchLyricsForTrack(Track track) async {
    _isLyricsLoading = true;
    notifyListeners();

    try {
      final result = await _lyricsService.getLyricsForTrack(track);
      // Pastikan lagu yang sedang diputar masih lagu yang sama saat hasil unduhan selesai
      if (_currentTrack?.id == track.id) {
        final updatedTrack = track.copyWith(
          syncedLyrics: result.lines,
          lyricsSource: result.source,
          isInstrumental: result.isInstrumental,
        );
        _currentTrack = updatedTrack;

        // Perbarui juga data track pada daftar _tracks
        final index = _tracks.indexWhere((t) => t.id == track.id);
        if (index != -1) {
          _tracks[index] = updatedTrack;
        }

        if (result.lines.isNotEmpty) {
          final activeIdx = LrcParser.findActiveIndex(result.lines, _currentPosition);
          if (activeIdx >= 0) {
            _currentLyricIndex = activeIdx;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching lyrics for track ${track.title}: $e');
    } finally {
      _isLyricsLoading = false;
      notifyListeners();
    }
  }

  /// Memperbarui posisi audio langsung ke timestamp baris lirik yang diketuk (Tap-to-Seek)
  Future<void> seekToLyric(int index) async {
    if (_currentTrack == null || _currentTrack!.syncedLyrics.isEmpty) return;
    if (index < 0 || index >= _currentTrack!.syncedLyrics.length) return;

    final targetLine = _currentTrack!.syncedLyrics[index];
    _currentLyricIndex = index;
    _currentPosition = targetLine.timestamp;

    final totalMs = _totalDurationMilliseconds;
    if (totalMs > 0) {
      _playbackProgress = (targetLine.timestamp.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }

    notifyListeners();
    await _audioService.seek(targetLine.timestamp);
  }

  /// Pemicu manual untuk mengambil ulang lirik saat lirik belum tersedia
  Future<void> fetchLyricsManual() async {
    if (_currentTrack != null) {
      await _fetchLyricsForTrack(_currentTrack!);
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null) return;
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      await _audioService.pause();
    } else {
      _isPlaying = true;
      notifyListeners();
      bool success = true;
      if (_currentPosition == Duration.zero && !_audioService.isPlaying) {
        success = await _audioService.playTrack(_currentTrack!);
      } else {
        await _audioService.resume();
      }
      if (!success) {
        _isPlaying = false;
        notifyListeners();
      } else {
        // Otomatis sinkronkan lirik saat diputar jika belum ada
        if (_currentTrack!.syncedLyrics.isEmpty && !_currentTrack!.isInstrumental) {
          _fetchLyricsForTrack(_currentTrack!);
        }
      }
    }
  }

  Future<void> seekTo(double progress) async {
    if (_currentTrack == null) return;
    _playbackProgress = progress.clamp(0.0, 1.0);
    final totalMs = _totalDurationMilliseconds;
    if (totalMs > 0) {
      final targetMs = (_playbackProgress * totalMs).round();
      _currentPosition = Duration(milliseconds: targetMs);
      await _audioService.seek(_currentPosition);
    }
    if (_currentTrack!.lyrics.isNotEmpty) {
      final targetIndex = (_playbackProgress * _currentTrack!.lyrics.length).floor();
      _currentLyricIndex = targetIndex.clamp(0, _currentTrack!.lyrics.length - 1);
    }
    notifyListeners();
  }

  void nextTrack() {
    if (_tracks.isEmpty) return;
    if (_isShuffle && _tracks.length > 1) {
      final random = Random();
      int nextIdx = random.nextInt(_tracks.length);
      while (_currentTrack != null && _tracks[nextIdx].id == _currentTrack!.id) {
        nextIdx = random.nextInt(_tracks.length);
      }
      playTrack(_tracks[nextIdx]);
    } else {
      final currentIndex = _currentTrack == null
          ? -1
          : _tracks.indexWhere((t) => t.id == _currentTrack!.id);
      if (currentIndex != -1 && currentIndex < _tracks.length - 1) {
        playTrack(_tracks[currentIndex + 1]);
      } else {
        playTrack(_tracks.first);
      }
    }
  }

  void previousTrack() {
    if (_tracks.isEmpty) return;
    if (_currentPosition.inSeconds > 3) {
      seekTo(0.0);
      return;
    }
    final currentIndex = _currentTrack == null
        ? -1
        : _tracks.indexWhere((t) => t.id == _currentTrack!.id);
    if (currentIndex > 0) {
      playTrack(_tracks[currentIndex - 1]);
    } else {
      playTrack(_tracks.last);
    }
  }

  void toggleFavorite(int trackId) {
    final index = _tracks.indexWhere((t) => t.id == trackId);
    if (index != -1) {
      final track = _tracks[index];
      final updated = track.copyWith(isFavorite: !track.isFavorite);
      _tracks[index] = updated;
      if (_currentTrack?.id == trackId) {
        _currentTrack = updated;
      }
      notifyListeners();
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    _audioService.setLoop(_isRepeat);
    notifyListeners();
  }

  void setAudioOutput(String output) {
    _selectedAudioOutput = output;
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimerMinutes = minutes;
    notifyListeners();
  }

  void setLyricIndex(int index) {
    _currentLyricIndex = index;
    if (_currentTrack != null && _currentTrack!.lyrics.isNotEmpty) {
      _playbackProgress = (index / _currentTrack!.lyrics.length).clamp(0.0, 1.0);
    }
    notifyListeners();
  }

  void shuffleAll() {
    if (_tracks.isNotEmpty) {
      final random = Random();
      final shuffled = List<Track>.from(_tracks)..shuffle(random);
      _tracks = shuffled;
      playTrack(shuffled.first);
    }
  }

  void toggleSort() {
    switch (_sortMode) {
      case SortMode.recent:
        _sortMode = SortMode.title;
        break;
      case SortMode.title:
        _sortMode = SortMode.duration;
        break;
      case SortMode.duration:
        _sortMode = SortMode.recent;
        break;
    }
    notifyListeners();
  }

  void setFilter(String filterId) {
    if (_activeFilterId != filterId) {
      _activeFilterId = filterId;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;

      if (query.trim().length >= 2) {
        final candidates = <String>{};
        for (final t in _tracks) {
          if (t.artist.isNotEmpty) candidates.add(t.artist);
          if (t.title.isNotEmpty) candidates.add(t.title);
          if (t.album.isNotEmpty) candidates.add(t.album);
        }
        _searchSuggestions = FuzzySearchEngine.getSuggestions(
          query: query,
          candidatePhrases: candidates,
          maxSuggestions: 3,
        );
      } else {
        _searchSuggestions = [];
      }

      notifyListeners();
    }
  }

  void clearSearch() {
    if (_searchQuery.isNotEmpty || _searchSuggestions.isNotEmpty) {
      _searchQuery = '';
      _searchSuggestions = [];
      notifyListeners();
    }
  }

  void setNavIndex(int index) {
    if (_currentNavIndex != index) {
      _currentNavIndex = index;
      notifyListeners();
    }
  }

  /// Memindai seluruh berkas audio di Internal Storage & MicroSD Card.
  /// Otomatis memuat cache lirik offline yang sudah tersimpan di storage lokal.
  Future<int> scanLocalAudio() async {
    _isScanning = true;
    notifyListeners();
    try {
      final localTracks = await _repository.scanLocalTracks();
      
      // Pre-hydrate cache lirik offline lokal untuk setiap trek yang terdeteksi
      final List<Track> hydratedTracks = [];
      for (final track in localTracks) {
        if (track.syncedLyrics.isEmpty && !track.isInstrumental) {
          final cached = await _lyricsService.getOfflineLyrics(track);
          if (cached != null) {
            hydratedTracks.add(track.copyWith(
              syncedLyrics: cached.lines,
              lyricsSource: cached.source,
              isInstrumental: cached.isInstrumental,
            ));
            continue;
          }
        }
        hydratedTracks.add(track);
      }

      _tracks = hydratedTracks;

      // PLAYBACK STATE GUARD:
      // HANYA inisialisasi _currentTrack ke lagu pertama saat awal aplikasi terbuka
      // dan player sedang benar-benar KOSONG (idle / null), serta TIDAK sedang aktif memutar lagu.
      if (_currentTrack == null && !_isPlaying && _tracks.isNotEmpty) {
        _currentTrack = _tracks.first;
        if (_currentTrack!.syncedLyrics.isEmpty && !_currentTrack!.isInstrumental) {
          _fetchLyricsForTrack(_currentTrack!);
        }
      } else if (_currentTrack != null) {
        // Jika sedang ada lagu yang diputar (baik streaming online Jamendo maupun lokal),
        // PERTAHANKAN lagu yang sedang aktif diputar!
        // Hanya sinkronkan metadata jika objek lagu lokalnya ter-refresh di _tracks.
        final matchingIdx = _tracks.indexWhere((t) =>
            t.id == _currentTrack!.id ||
            (t.filePath != null && _currentTrack!.filePath != null && t.filePath == _currentTrack!.filePath));
        if (matchingIdx != -1) {
          _currentTrack = _tracks[matchingIdx];
        }
      }

      return hydratedTracks.length;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Opsi 1: Hapus dari daftar aplikasi saja (Soft delete / Hide)
  void removeTrackFromListOnly(int trackId) {
    _repository.hideTrack(trackId);
    _removeTrackFromState(trackId);
    notifyListeners();
  }

  /// Opsi 2: Hapus berkas fisik permanen dari perangkat (Hard delete)
  Future<bool> deleteTrackPermanently(Track track) async {
    final success = await MediaDeletionService.deletePermanently(
      mediaId: track.localMediaId ?? track.id,
      filePath: track.filePath,
    );

    if (success) {
      _repository.hideTrack(track.id);
      await _repository.removeDownloadedTrack(track.id, filePath: track.filePath);
      _removeTrackFromState(track.id);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Memulihkan seluruh lagu yang sebelumnya disembunyikan dari aplikasi
  Future<void> restoreHiddenTracks() async {
    _repository.unhideAll();
    _tracks = _repository.getTracks();
    if (_currentTrack == null && _tracks.isNotEmpty) {
      _currentTrack = _tracks.first;
    }
    notifyListeners();
  }

  void _removeTrackFromState(int trackId) {
    _tracks.removeWhere((t) => t.id == trackId);
    if (_currentTrack?.id == trackId) {
      if (_tracks.isNotEmpty) {
        playTrack(_tracks.first);
      } else {
        _currentTrack = null;
        _isPlaying = false;
        _audioService.stop();
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    // Jangan panggil _audioService.dispose() di sini agar Background Service tetap hidup saat UI ditutup!
    super.dispose();
  }
}
