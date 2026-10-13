import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowy/data/models/track.dart';
import 'package:flowy/data/services/download_manifest_storage.dart';
import 'package:flowy/data/services/local_audio_service.dart';
import 'package:flowy/data/repositories/track_repository.dart';

class FakeLocalAudioService extends LocalAudioService {
  final List<Track> tracksToReturn;
  FakeLocalAudioService(this.tracksToReturn);

  @override
  Future<List<Track>> queryDeviceTracks() async => tracksToReturn;
}

void main() {
  late Directory tempDir;
  late DownloadManifestStorage manifestStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_manifest_test');
    manifestStorage = DownloadManifestStorage(customDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DownloadManifestStorage Tests', () {
    test('Saves and loads tracks cleanly when physical file exists', () async {
      // Buat file fisik simulasi di direktori temp
      final dummyAudioFile = File('${tempDir.path}/test_song.mp3');
      await dummyAudioFile.writeAsString('audio content');

      final track = Track(
        id: 777123,
        orderNumber: '01',
        title: 'Cyberpunk Skyline',
        artist: 'Neon Wave',
        album: 'Future Beats',
        audioFormat: 'MP3 • Jamendo',
        duration: '03:30',
        durationMs: 210000,
        filePath: dummyAudioFile.path,
        contentUri: 'file://${dummyAudioFile.path}',
        tags: ['downloaded', 'synthwave'],
      );

      await manifestStorage.saveTrack(track);

      final loaded = await manifestStorage.loadTracks();
      expect(loaded.length, 1);
      expect(loaded.first.id, 777123);
      expect(loaded.first.title, 'Cyberpunk Skyline');
      expect(loaded.first.artist, 'Neon Wave');
      expect(loaded.first.filePath, dummyAudioFile.path);
    });

    test('Automatically filters out missing/deleted files from manifest', () async {
      final nonExistentFilePath = '${tempDir.path}/deleted_by_user.mp3';

      final track = Track(
        id: 888456,
        orderNumber: '02',
        title: 'Deleted Track',
        artist: 'Ghost Artist',
        album: 'Void',
        audioFormat: 'MP3',
        duration: '02:15',
        filePath: nonExistentFilePath,
      );

      await manifestStorage.saveTrack(track);

      final loaded = await manifestStorage.loadTracks();
      // Harus kosong karena berkas fisiknya tidak ada
      expect(loaded.isEmpty, isTrue);
    });

    test('TrackRepository merges downloaded manifest with scanned tracks without duplicate', () async {
      final dummyAudioFile = File('${tempDir.path}/downloaded.mp3');
      await dummyAudioFile.writeAsString('audio data');

      final downloadedTrack = Track(
        id: 999001,
        orderNumber: '01',
        title: 'Chill Sunset',
        artist: 'Lofi Producer',
        album: 'Lofi Tape',
        audioFormat: 'MP3 • Jamendo',
        duration: '02:45',
        coverAsset: 'https://jamendo.com/cover.jpg',
        filePath: dummyAudioFile.path,
        tags: ['downloaded', 'lofi'],
      );

      await manifestStorage.saveTrack(downloadedTrack);

      final scannedMediaStoreTrack = Track(
        id: 1234, // ID MediaStore beda
        orderNumber: '02',
        title: 'Chill Sunset', // Judul & artis sama
        artist: 'Lofi Producer',
        album: 'Unknown',
        audioFormat: 'MP3',
        duration: '02:45',
        filePath: dummyAudioFile.path,
      );

      final otherLocalTrack = Track(
        id: 5678,
        orderNumber: '03',
        title: 'Local Rock',
        artist: 'Garage Band',
        album: 'Album A',
        audioFormat: 'FLAC',
        duration: '04:10',
      );

      final fakeAudioService = FakeLocalAudioService([scannedMediaStoreTrack, otherLocalTrack]);

      final repository = TrackRepository(
        manifestStorage: manifestStorage,
        localAudioService: fakeAudioService,
      );

      final tracks = await repository.scanLocalTracks();

      // Harus ada 2 trek: 'Chill Sunset' (versi unduhan dengan cover) dan 'Local Rock'
      expect(tracks.length, 2);
      expect(tracks.any((t) => t.id == 999001), isTrue);
      expect(tracks.any((t) => t.id == 5678), isTrue);
      // Track unduhan Jamendo harus mempertahankan coverAsset-nya
      final chill = tracks.firstWhere((t) => t.id == 999001);
      expect(chill.coverAsset, 'https://jamendo.com/cover.jpg');
    });
  });
}
