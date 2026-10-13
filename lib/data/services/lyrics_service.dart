import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import 'lrc_parser.dart';

enum LyricsSource {
  localSidecar,
  internalCache,
  lrclibSynced,
  lrclibPlain,
  jamendo,
  none,
}

class LyricsResult {
  final List<LyricLine> lines;
  final LyricsSource source;
  final bool isInstrumental;

  const LyricsResult({
    required this.lines,
    required this.source,
    this.isInstrumental = false,
  });

  static const empty = LyricsResult(
    lines: [],
    source: LyricsSource.none,
  );
}

/// Service untuk mengambil lirik lagu dengan arsitektur 4-Tier Waterfall:
/// Tier 1: Berkas .lrc lokal di samping berkas audio fisik.
/// Tier 2: Cache internal di penyimpanan aplikasi.
/// Tier 3: LRCLIB API /api/get (Exact Match).
/// Tier 4: LRCLIB API /api/search (Fuzzy / Search Match).
class LyricsService {
  static const String _lrclibBaseUrl = 'https://lrclib.net/api';
  static const String _userAgent = 'Flowy Music Player/1.0 (https://github.com/flowy-music)';
  static const Duration _networkTimeout = Duration(seconds: 5);

  Directory? _cacheDir;

  LyricsService({Directory? customCacheDir}) : _cacheDir = customCacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final lyricsDir = Directory('${appDir.path}/lyrics_cache');
    if (!await lyricsDir.exists()) {
      await lyricsDir.create(recursive: true);
    }
    _cacheDir = lyricsDir;
    return lyricsDir;
  }

  /// Membuat hash unik yang aman untuk nama berkas cache berdasarkan title dan artist.
  String _cacheKey(String title, String artist) {
    final raw = '${title.toLowerCase().trim()}_${artist.toLowerCase().trim()}';
    return raw.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  /// Kunci alternatif berbasis ID MediaStore lokal untuk memastikan kecocokan 100%
  String _mediaIdKey(int mediaId) {
    return 'media_id_$mediaId';
  }

  /// Membersihkan judul lagu dari teks tambahan seperti "(Official Audio)", "[Remastered]", ".mp3"
  String sanitizeTitle(String title) {
    var cleaned = title
        .replaceAll(RegExp(r'\.(mp3|flac|wav|m4a|aac|ogg)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?(official|audio|video|lyric|remaster|hd|4k).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?(official|audio|video|lyric|remaster|hd|4k).*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+ft\.?\s+.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+feat\.?\s+.*', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// Memeriksa dan memuat lirik offline secara cepat (Tier 1 & Tier 2) tanpa network request
  Future<LyricsResult?> getOfflineLyrics(Track track) async {
    // 1. Cek Tier 1: Berkas .lrc sidecar di sebelah berkas audio fisik
    if (track.filePath != null && track.filePath!.isNotEmpty) {
      try {
        final audioPath = track.filePath!;
        final dotIndex = audioPath.lastIndexOf('.');
        if (dotIndex != -1) {
          final lrcPath = '${audioPath.substring(0, dotIndex)}.lrc';
          final lrcFile = File(lrcPath);
          if (await lrcFile.exists()) {
            final content = await lrcFile.readAsString();
            final parsed = LrcParser.parse(content);
            if (parsed.isNotEmpty) {
              return LyricsResult(
                lines: parsed,
                source: LyricsSource.localSidecar,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('LyricsService: Tier 1 fast check error: $e');
      }
    }

    // 2. Cek Tier 2: Berkas cache internal di App Documents
    try {
      final cacheDir = await _getCacheDirectory();
      final cleanTitle = sanitizeTitle(track.title);
      final key = _cacheKey(cleanTitle, track.artist);

      // Cek berdasarkan key teks
      File cachedFile = File('${cacheDir.path}/$key.lrc');
      if (!await cachedFile.exists() && track.localMediaId != null) {
        // Fallback: Cek berdasarkan key media ID
        final altKey = _mediaIdKey(track.localMediaId!);
        final altFile = File('${cacheDir.path}/$altKey.lrc');
        if (await altFile.exists()) {
          cachedFile = altFile;
        }
      }

      if (await cachedFile.exists()) {
        final content = await cachedFile.readAsString();
        if (content.startsWith('#INSTRUMENTAL#')) {
          return const LyricsResult(
            lines: [],
            source: LyricsSource.internalCache,
            isInstrumental: true,
          );
        }
        final parsed = LrcParser.parse(content);
        if (parsed.isNotEmpty) {
          return LyricsResult(
            lines: parsed,
            source: LyricsSource.internalCache,
          );
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Tier 2 fast check error: $e');
    }

    return null;
  }

  /// Mengambil lirik lagu berdasarkan prioritas waterfall
  Future<LyricsResult> getLyricsForTrack(Track track) async {
    // Cek cache offline terlebih dahulu (Tier 1 & Tier 2)
    final offlineResult = await getOfflineLyrics(track);
    if (offlineResult != null) {
      return offlineResult;
    }

    final cleanTitle = sanitizeTitle(track.title);

    // -------------------------------------------------------------
    // TIER 3 & 4: Panggil LRCLIB API via dart:io HttpClient
    // -------------------------------------------------------------
    try {
      final networkResult = await _fetchFromLrclib(
        cleanTitle: cleanTitle,
        artist: track.artist,
        album: track.album,
        durationSeconds: track.durationMs != null ? (track.durationMs! ~/ 1000) : null,
      );

      if (networkResult != null) {
        // Simpan permanen ke internal storage dan sidecar jika memungkinkan
        await saveLyricsPermanently(track, networkResult);
        return networkResult;
      }
    } catch (e) {
      debugPrint('LyricsService: Network fetch failed: $e');
    }

    return LyricsResult.empty;
  }

  /// Menyimpan lirik secara permanen ke internal storage (multi-key) dan berkas sidecar .lrc
  Future<void> saveLyricsPermanently(Track track, LyricsResult result) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cleanTitle = sanitizeTitle(track.title);
      final key = _cacheKey(cleanTitle, track.artist);

      String content = '';
      if (result.isInstrumental) {
        content = '#INSTRUMENTAL#\n';
      } else if (result.lines.isNotEmpty) {
        final lrcBuffer = StringBuffer();
        lrcBuffer.writeln('[ti:${track.title}]');
        lrcBuffer.writeln('[ar:${track.artist}]');
        lrcBuffer.writeln('[al:${track.album}]');
        for (final line in result.lines) {
          lrcBuffer.writeln(line.toString());
        }
        content = lrcBuffer.toString();
      }

      if (content.isEmpty) return;

      // 1. Simpan ke Tier 2: App Documents Storage dengan key judul & artis
      final primaryCachedFile = File('${cacheDir.path}/$key.lrc');
      await primaryCachedFile.writeAsString(content, flush: true);

      // 2. Simpan juga dengan index localMediaId jika tersedia untuk deduplikasi cepat
      if (track.localMediaId != null) {
        final altKey = _mediaIdKey(track.localMediaId!);
        final altCachedFile = File('${cacheDir.path}/$altKey.lrc');
        await altCachedFile.writeAsString(content, flush: true);
      }

      // 3. Simpan ke Tier 1: Coba simpan file sidecar .lrc di sebelah audio fisik (jika diizinkan OS)
      if (track.filePath != null && track.filePath!.isNotEmpty) {
        try {
          final audioPath = track.filePath!;
          final dotIndex = audioPath.lastIndexOf('.');
          if (dotIndex != -1) {
            final sidecarPath = '${audioPath.substring(0, dotIndex)}.lrc';
            final sidecarFile = File(sidecarPath);
            await sidecarFile.writeAsString(content, flush: true);
          }
        } catch (_) {
          // Normal jika Android Scoped Storage menolak penulisan langsung di folder musik sistem
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Failed to save lyrics permanently: $e');
    }
  }

  /// Panggilan HTTP native ke LRCLIB
  Future<LyricsResult?> _fetchFromLrclib({
    required String cleanTitle,
    required String artist,
    String? album,
    int? durationSeconds,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = _networkTimeout;

    try {
      // 1. TIER 3: Exact Match via /api/get
      final queryParams = <String, String>{
        'track_name': cleanTitle,
      };
      final hasValidArtist = artist.isNotEmpty &&
          artist != '<unknown>' &&
          artist != 'Artis Tidak Diketahui' &&
          artist != 'Unknown Artist';
      if (hasValidArtist) {
        queryParams['artist_name'] = artist;
      }
      final hasValidAlbum = album != null &&
          album.isNotEmpty &&
          album != '<unknown>' &&
          album != 'Penyimpanan Lokal' &&
          album != 'Unknown Album';
      if (hasValidAlbum) {
        queryParams['album_name'] = album;
      }
      if (durationSeconds != null && durationSeconds > 0) {
        queryParams['duration'] = durationSeconds.toString();
      }

      final getUri = Uri.parse('$_lrclibBaseUrl/get').replace(queryParameters: queryParams);
      final getResult = await _executeHttp(client, getUri);

      if (getResult != null) {
        final parsed = _parseLrclibResponse(getResult);
        if (parsed != null) return parsed;
      }

      // 2. TIER 4: Fallback Search via /api/search
      final searchQuery = hasValidArtist ? '$cleanTitle $artist'.trim() : cleanTitle;
      final searchUri = Uri.parse('$_lrclibBaseUrl/search').replace(
        queryParameters: {'q': searchQuery},
      );
      final searchResult = await _executeHttp(client, searchUri);

      if (searchResult != null) {
        final decoded = jsonDecode(searchResult);
        if (decoded is List && decoded.isNotEmpty) {
          // Ambil hasil pertama yang memiliki syncedLyrics atau instrumental
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final parsed = _parseLrclibResponse(jsonEncode(item));
              if (parsed != null) return parsed;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('LyricsService: LRCLIB HTTP error: $e');
    } finally {
      client.close();
    }

    return null;
  }

  Future<String?> _executeHttp(HttpClient client, Uri uri) async {
    try {
      final request = await client.getUrl(uri).timeout(_networkTimeout);
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
    } catch (e) {
      // Timeout atau connection error
    }
    return null;
  }

  LyricsResult? _parseLrclibResponse(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final bool instrumental = data['instrumental'] == true;
      if (instrumental) {
        return const LyricsResult(
          lines: [],
          source: LyricsSource.lrclibSynced,
          isInstrumental: true,
        );
      }

      final String? syncedLyricsStr = data['syncedLyrics'];
      if (syncedLyricsStr != null && syncedLyricsStr.isNotEmpty) {
        final parsed = LrcParser.parse(syncedLyricsStr);
        if (parsed.isNotEmpty) {
          return LyricsResult(
            lines: parsed,
            source: LyricsSource.lrclibSynced,
          );
        }
      }

      final String? plainLyricsStr = data['plainLyrics'];
      if (plainLyricsStr != null && plainLyricsStr.isNotEmpty) {
        final parsed = LrcParser.parsePlainText(plainLyricsStr);
        if (parsed.isNotEmpty) {
          return LyricsResult(
            lines: parsed,
            source: LyricsSource.lrclibPlain,
          );
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Error decoding response: $e');
    }
    return null;
  }
}
