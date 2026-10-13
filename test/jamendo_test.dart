import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowy/data/models/jamendo_track.dart';
import 'package:flowy/data/services/jamendo_service.dart';

void main() {
  group('JamendoTrack & JamendoService Tests', () {
    test('Deserializes Jamendo JSON response properly', () {
      final sampleJson = {
        'id': '1982736',
        'name': 'Midnight Reverie',
        'artist_name': 'Acoustic Soul',
        'album_name': 'Solitude Dreams',
        'duration': 185,
        'audio': 'https://prod-1.storage.jamendo.com/?trackid=1982736',
        'image': 'https://usercontent.jamendo.com?type=album&id=123',
        'shareurl': 'https://www.jamendo.com/track/1982736',
        'musicinfo': {
          'tags': {
            'genres': ['acoustic', 'lofi', 'chill'],
          }
        }
      };

      final track = JamendoTrack.fromJson(sampleJson);

      expect(track.id, '1982736');
      expect(track.name, 'Midnight Reverie');
      expect(track.artistName, 'Acoustic Soul');
      expect(track.duration, 185);
      expect(track.formattedDuration, '03:05');
      expect(track.tags, contains('lofi'));
    });

    test('Single-call JSON cache stores and retrieves catalog cleanly', () async {
      final tempDir = Directory.systemTemp.createTempSync('flowy_jamendo_test_');
      final service = JamendoService(dir: tempDir);

      final mockTracks = [
        const JamendoTrack(
          id: '1',
          name: 'Song One',
          artistName: 'Artist A',
          albumName: 'Album A',
          duration: 120,
          audioUrl: 'https://example.com/audio1.mp3',
          imageUrl: '',
          shareUrl: '',
          tags: ['lofi'],
        ),
        const JamendoTrack(
          id: '2',
          name: 'Song Two',
          artistName: 'Artist B',
          albumName: 'Album B',
          duration: 200,
          audioUrl: 'https://example.com/audio2.mp3',
          imageUrl: '',
          shareUrl: '',
          tags: ['electronic'],
        ),
      ];

      // Simpan ke file JSON lokal
      await service.saveCatalogToCache(mockTracks);

      // Ambil kembali secara offline
      final cached = await service.getCachedCatalog();

      expect(cached.length, 2);
      expect(cached[0].name, 'Song One');
      expect(cached[1].artistName, 'Artist B');

      // Pencarian di dalam JSON lokal tanpa kuota
      final searchResult = service.searchInLocalCatalog(cached, 'Song Two');
      expect(searchResult.length, 1);
      expect(searchResult.first.id, '2');

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
