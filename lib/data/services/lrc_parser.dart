import '../models/lyric_line.dart';

/// Parser berkas lirik standar .lrc dan fallback plain-text lyrics.
class LrcParser {
  /// Regular expression untuk menangkap tag waktu LRC:
  /// Contoh yang didukung:
  /// - [00:15.50]
  /// - [01:05.123]
  /// - [02:30]
  /// - [00:15:50]
  static final RegExp _timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{2,3}))?\]');

  /// Parse string format berkas .lrc menjadi list [LyricLine] yang terurut kronologis.
  static List<LyricLine> parse(String lrcContent) {
    if (lrcContent.trim().isEmpty) return [];

    final lines = lrcContent.split(RegExp(r'\r?\n'));
    final List<LyricLine> parsedLyrics = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Temukan semua tag timestamp pada baris (menangani multi-timestamp seperti [00:12.50][01:05.20] Reff)
      final matches = _timestampRegex.allMatches(line).toList();
      if (matches.isEmpty) {
        // Baris tanpa tag waktu (misal metadata atau plain text baris)
        continue;
      }

      // Ambil teks setelah tag waktu terakhir
      final lastMatch = matches.last;
      final text = line.substring(lastMatch.end).trim();

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final rawFraction = match.group(3);

        int milliseconds = 0;
        if (rawFraction != null) {
          if (rawFraction.length == 2) {
            // Standar .lrc desimal 2 digit: .50 = 500ms, bukan 50ms!
            milliseconds = (int.tryParse(rawFraction) ?? 0) * 10;
          } else if (rawFraction.length == 3) {
            milliseconds = int.tryParse(rawFraction) ?? 0;
          } else if (rawFraction.length == 1) {
            milliseconds = (int.tryParse(rawFraction) ?? 0) * 100;
          }
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        parsedLyrics.add(LyricLine(
          timestamp: duration,
          text: text,
        ));
      }
    }

    // Urutkan secara kronologis berdasarkan waktu
    parsedLyrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return parsedLyrics;
  }

  /// Binary Search (O(log N)) untuk menemukan indeks lirik aktif berdasarkan posisi pemutaran.
  /// Sangat hemat siklus CPU Helio G35 (Oppo A16) dibandingkan linear loop O(N).
  static int findActiveIndex(List<LyricLine> lyrics, Duration currentPosition) {
    if (lyrics.isEmpty) return -1;
    if (currentPosition < lyrics.first.timestamp) return 0;
    if (currentPosition >= lyrics.last.timestamp) return lyrics.length - 1;

    int low = 0;
    int high = lyrics.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lyrics[mid].timestamp <= currentPosition) {
        result = mid;
        low = mid + 1; // Cari yang paling mendekati di sebelah kanan
      } else {
        high = mid - 1;
      }
    }

    return result;
  }

  /// Fallback parser untuk lirik polos tanpa penanda waktu (plain text).
  /// Menghasilkan durasi merata jika totalDurasi diketahui.
  static List<LyricLine> parsePlainText(String plainText, {Duration? totalDuration}) {
    final lines = plainText
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final stepMs = (totalDuration != null && totalDuration.inMilliseconds > 0)
        ? totalDuration.inMilliseconds ~/ lines.length
        : 3000;

    return List.generate(lines.length, (i) {
      return LyricLine(
        timestamp: Duration(milliseconds: i * stepMs),
        text: lines[i],
      );
    });
  }
}
