import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flowy/main.dart';
import 'package:flowy/data/models/track.dart';
import 'package:flowy/presentation/controllers/player_controller.dart';
import 'package:flowy/data/repositories/track_repository.dart';
import 'package:flowy/data/services/audio_player_service.dart';

List<Track> _createSampleTestTracks() {
  return [
    Track(
      id: 1,
      orderNumber: '01',
      title: 'Cahaya Malam Tersisa',
      artist: 'Kalandra Senja',
      album: 'Resonansi Hening Vol. 1',
      audioFormat: 'FLAC Lossless',
      sampleRate: '24bit / 96kHz',
      duration: '04:18',
      isFavorite: false,
      tags: ['flac', 'lossless', 'recent'],
      lyrics: [
        'Di sudut sunyi malam yang temaram',
        'Detik waktu terhenti perlahan',
      ],
      activeLyricIndex: 0,
      sourceType: TrackSourceType.localDevice,
      filePath: '/storage/emulated/0/Music/track_1.flac',
      localMediaId: 101,
    ),
    Track(
      id: 2,
      orderNumber: '02',
      title: 'Hujan Tengah Malam di Kyoto',
      artist: 'Renata & The Strings',
      album: 'Midnight Whispers',
      audioFormat: 'FLAC Lossless',
      sampleRate: '24bit / 192kHz',
      duration: '03:45',
      isFavorite: true,
      tags: ['flac', 'playlist'],
      lyrics: ['Rintik hujan membasahi jendela', 'Kenangan kembali menyapa'],
      activeLyricIndex: 0,
      sourceType: TrackSourceType.localDevice,
      filePath: '/storage/emulated/0/Music/track_2.flac',
      localMediaId: 102,
    ),
  ];
}

void main() {
  testWidgets('FlowyApp smoke test and Now Playing modal interaction',
      (WidgetTester tester) async {
    final sampleTracks = _createSampleTestTracks();
    final repo = TrackRepository(initialTracks: sampleTracks);
    final controller = PlayerController(repository: repo, autoScan: false);

    await tester.pumpWidget(FlowyApp(controller: controller));
    await tester.pump();

    // Verify Brand title is rendered
    expect(find.text('Flowy'), findsOneWidget);

    // Verify Filter chips & BottomNav rendered ('Semua' appears in filter chip)
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Baru Ditambahkan'), findsOneWidget);

    // Verify Shuffle button is rendered
    expect(find.text('Putar Acak'), findsOneWidget);

    // Verify active track title is rendered
    expect(find.text('Cahaya Malam Tersisa'), findsWidgets);

    // Verify 3-tab navigation bar labels
    expect(find.text('Koleksi'), findsOneWidget);
    expect(find.text('Jelajah'), findsOneWidget);
    expect(find.text('Favorit'), findsOneWidget);

    // Tap on Mini Player to open the Spotify-like Now Playing popup modal
    final miniPlayerFinder = find.byTooltip('Buka Pemutar Lengkap');
    expect(miniPlayerFinder, findsOneWidget);
    await tester.tap(miniPlayerFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Now Playing Modal components are displayed
    expect(find.text('MEMUTAR DARI DAFTAR PUTAR'), findsOneWidget);
    expect(find.text('Daftar Putar Pribadi'), findsOneWidget);
    expect(find.text('Lirik'), findsOneWidget);
    expect(find.text('Di sudut sunyi malam yang temaram'), findsOneWidget);
    expect(find.text('DAC Eksternal • 96kHz'), findsOneWidget);

    // Close Now Playing sheet via dismiss button
    final closeBtnFinder = find.byTooltip('Tutup Pemutar');
    expect(closeBtnFinder, findsOneWidget);
    await tester.tap(closeBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify modal is closed and HomeScreen is back in view
    expect(find.text('MEMUTAR DARI DAFTAR PUTAR'), findsNothing);
  });

  test('PlayerController unit test for playback, scrubbing, and modal controls', () async {
    final sampleTracks = _createSampleTestTracks();
    final repo = TrackRepository(initialTracks: sampleTracks);
    final controller = PlayerController(repository: repo, autoScan: false);

    // Initial state
    expect(controller.currentTrack?.title, 'Cahaya Malam Tersisa');
    expect(controller.isPlaying, isFalse);
    expect(controller.filteredTracks.length, 2);
    expect(controller.selectedAudioOutput, 'DAC Eksternal • 96kHz');

    // Filter by FLAC Lossless
    controller.setFilter('flac');
    expect(controller.filteredTracks.every((t) => t.tags.contains('flac')), isTrue);

    // Reset filter and test search filtering
    controller.setFilter('all');
    controller.setSearchQuery('Kyoto');
    expect(controller.filteredTracks.length, 1);
    expect(controller.filteredTracks.first.title, 'Hujan Tengah Malam di Kyoto');

    // Clear search
    controller.clearSearch();
    expect(controller.searchQuery, isEmpty);

    // Toggle play/pause
    controller.togglePlayPause();
    expect(controller.isPlaying, isTrue);
    controller.togglePlayPause();
    expect(controller.isPlaying, isFalse);

    // Favorite toggle
    final initialFav = controller.currentTrack!.isFavorite;
    controller.toggleFavorite(controller.currentTrack!.id);
    expect(controller.currentTrack!.isFavorite, !initialFav);

    // Scrubbing / SeekTo
    controller.seekTo(0.5);
    expect(controller.playbackProgress, 0.5);
    expect(controller.formattedElapsedTime, '02:09');

    // Shuffle & Repeat toggles
    expect(controller.isShuffle, isFalse);
    controller.toggleShuffle();
    expect(controller.isShuffle, isTrue);

    expect(controller.isRepeat, isFalse);
    controller.toggleRepeat();
    expect(controller.isRepeat, isTrue);

    // Audio Output routing
    controller.setAudioOutput('Bluetooth LDAC • 24bit/96kHz');
    expect(controller.selectedAudioOutput, 'Bluetooth LDAC • 24bit/96kHz');

    // Sleep Timer
    controller.setSleepTimer(30);
    expect(controller.sleepTimerMinutes, 30);

    // Soft Delete (remove from app list only)
    final initialCount = controller.filteredTracks.length;
    final trackToDeleteId = controller.currentTrack!.id;
    controller.removeTrackFromListOnly(trackToDeleteId);
    expect(controller.filteredTracks.length, initialCount - 1);
    expect(controller.hiddenTracksCount, 1);

    // Restore hidden tracks
    controller.restoreHiddenTracks();
    expect(controller.hiddenTracksCount, 0);

    // Lifecycle state (0% CPU background optimization)
    expect(controller.isAppForeground, isTrue);
    controller.setAppForegroundState(false);
    expect(controller.isAppForeground, isFalse);
    controller.setAppForegroundState(true);
    expect(controller.isAppForeground, isTrue);
  });

  test('PlayerController preserves playing track during background scanLocalAudio', () async {
    final fakeAudio = FakeAudioPlayerService();
    final repo = TrackRepository(initialTracks: _createSampleTestTracks());
    final controller = PlayerController(
      repository: repo,
      audioService: fakeAudio,
      autoScan: false,
    );

    final onlineTrack = Track(
      id: 999988,
      orderNumber: '99',
      title: 'Online Stream Track',
      artist: 'Jamendo Artist',
      album: 'Jamendo Album',
      audioFormat: 'MP3',
      duration: '03:10',
      contentUri: 'https://mp3d.jamendo.com/stream/999988',
      tags: ['online', 'jamendo'],
    );

    await controller.playTrack(onlineTrack);
    expect(controller.currentTrack?.id, 999988);
    expect(controller.isPlaying, isTrue);

    // Jalankan scan lokal saat lagu online sedang diputar
    await controller.scanLocalAudio();

    // Pastikan _currentTrack TETAP lagu online yang sedang diputar, TIDAK lompat ke lagu lokal pertama!
    expect(controller.currentTrack?.id, 999988);
    expect(controller.currentTrack?.title, 'Online Stream Track');
  });
}

class FakeAudioPlayerService extends AudioPlayerService {
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  bool _mockPlaying = false;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  bool get isPlaying => _mockPlaying;

  @override
  Future<bool> playTrack(Track track) async {
    _mockPlaying = true;
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
    return true;
  }

  @override
  Future<void> pause() async {
    _mockPlaying = false;
    _playerStateController.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> resume() async {
    _mockPlaying = true;
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {
    _mockPlaying = false;
    _playerStateController.add(PlayerState(false, ProcessingState.idle));
  }
}
