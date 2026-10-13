import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowy/data/models/lyric_line.dart';
import 'package:flowy/data/models/track.dart';
import 'package:flowy/data/services/lrc_parser.dart';
import 'package:flowy/data/services/lyrics_service.dart';

void main() {
  group('LrcParser Tests', () {
    test('Parse standard LRC formatted lyrics with 2-digit decimal calibration', () {
      const sampleLrc = '''
[ti:Sample Song]
[ar:Sample Artist]
[00:10.50]Line 1 at 10.5 seconds
[00:25.00]Line 2 at 25 seconds
[01:05.123]Line 3 at 1 min 5 sec 123 ms
''';

      final lyrics = LrcParser.parse(sampleLrc);

      expect(lyrics.length, 3);
      // 2-digit fraction .50 = 500ms
      expect(lyrics[0].timestamp, const Duration(seconds: 10, milliseconds: 500));
      expect(lyrics[0].text, 'Line 1 at 10.5 seconds');

      expect(lyrics[1].timestamp, const Duration(seconds: 25));
      expect(lyrics[1].text, 'Line 2 at 25 seconds');

      expect(lyrics[2].timestamp, const Duration(minutes: 1, seconds: 5, milliseconds: 123));
      expect(lyrics[2].text, 'Line 3 at 1 min 5 sec 123 ms');
    });

    test('Parse multi-timestamp lines properly and sort chronologically', () {
      const multiTagLrc = '''
[00:15.00][01:30.00]Chorus repeated twice
[00:05.00]Intro line
''';

      final lyrics = LrcParser.parse(multiTagLrc);

      expect(lyrics.length, 3);
      // Harus terurut kronologis: 00:05.00 -> 00:15.00 -> 01:30.00
      expect(lyrics[0].timestamp, const Duration(seconds: 5));
      expect(lyrics[0].text, 'Intro line');

      expect(lyrics[1].timestamp, const Duration(seconds: 15));
      expect(lyrics[1].text, 'Chorus repeated twice');

      expect(lyrics[2].timestamp, const Duration(minutes: 1, seconds: 30));
      expect(lyrics[2].text, 'Chorus repeated twice');
    });

    test('Binary search findActiveIndex accurately pinpoints active line', () {
      final lyrics = [
        const LyricLine(timestamp: Duration(seconds: 10), text: 'Line 1'),
        const LyricLine(timestamp: Duration(seconds: 20), text: 'Line 2'),
        const LyricLine(timestamp: Duration(seconds: 30), text: 'Line 3'),
      ];

      // Before first line
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 5)), 0);

      // Exactly at first line
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 10)), 0);

      // Between line 1 and line 2
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 15)), 0);

      // Exactly at line 2
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 20)), 1);

      // Between line 2 and line 3
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 25)), 1);

      // At or beyond last line
      expect(LrcParser.findActiveIndex(lyrics, const Duration(seconds: 35)), 2);
    });

    test('Parse plain text fallback evenly distributes durations', () {
      const plainText = '''
First verse line
Second verse line
Third chorus line
''';

      final lyrics = LrcParser.parsePlainText(
        plainText,
        totalDuration: const Duration(seconds: 30),
      );

      expect(lyrics.length, 3);
      // 30 seconds / 3 lines = 10s per line
      expect(lyrics[0].timestamp, Duration.zero);
      expect(lyrics[1].timestamp, const Duration(seconds: 10));
      expect(lyrics[2].timestamp, const Duration(seconds: 20));
    });
  });

  group('LyricsService & Track Model Tests', () {
    test('Sanitizes track titles cleanly for search', () {
      final service = LyricsService();

      expect(service.sanitizeTitle('Bohemian Rhapsody (Official Audio)'), 'Bohemian Rhapsody');
      expect(service.sanitizeTitle('Starboy [Remastered 2024]'), 'Starboy');
      expect(service.sanitizeTitle('Track Name.mp3'), 'Track Name');
      expect(service.sanitizeTitle('Closer feat. Halsey'), 'Closer');
      expect(service.sanitizeTitle('Stay ft. Justin Bieber'), 'Stay');
    });

    test('Track backward compatibility with legacy lyrics getter', () {
      final track = Track(
        id: 99,
        orderNumber: '99',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        audioFormat: 'MP3',
        duration: '03:00',
        syncedLyrics: const [
          LyricLine(timestamp: Duration(seconds: 0), text: 'Verse 1'),
          LyricLine(timestamp: Duration(seconds: 10), text: 'Verse 2'),
        ],
      );

      expect(track.lyrics, ['Verse 1', 'Verse 2']);
    });

    test('LyricsService offline persistence writes and retrieves cached lyrics properly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = Directory.systemTemp.createTempSync('flowy_lyrics_test_');
      final service = LyricsService(customCacheDir: tempDir);
      final track = Track(
        id: 101,
        localMediaId: 101,
        orderNumber: '01',
        title: 'Offline Masterpiece (Official Music Video)',
        artist: 'Flowy Artist',
        album: 'Acoustic Sessions',
        audioFormat: 'MP3',
        duration: '02:45',
      );

      const lyricsToSave = LyricsResult(
        lines: [
          LyricLine(timestamp: Duration(seconds: 0), text: 'Matahari terbenam perlahan'),
          LyricLine(timestamp: Duration(seconds: 15), text: 'Suara angin menenangkan'),
        ],
        source: LyricsSource.lrclibSynced,
      );

      // Simpan permanen ke cache storage
      await service.saveLyricsPermanently(track, lyricsToSave);

      // Ambil kembali via offline fast check
      final retrieved = await service.getOfflineLyrics(track);

      expect(retrieved, isNotNull);
      expect(retrieved!.source, LyricsSource.internalCache);
      expect(retrieved.lines.length, 2);
      expect(retrieved.lines[0].text, 'Matahari terbenam perlahan');
      expect(retrieved.lines[1].timestamp, const Duration(seconds: 15));

      // Bersihkan folder temp
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}

