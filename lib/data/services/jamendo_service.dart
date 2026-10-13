import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/jamendo_track.dart';
import '../../core/utils/fuzzy_search.dart';

class JamendoService {
  // Official active Jamendo developer client ID for free streaming & metadata
  static const String _clientId = '9e640720';
  static const String _baseUrl = 'https://api.jamendo.com/v3.0';
  static const Duration _timeout = Duration(seconds: 12);

  final Directory? _customCacheDir;

  JamendoService({Directory? dir}) : _customCacheDir = dir;

  Future<File> _getCatalogCacheFile() async {
    final customDir = _customCacheDir;
    if (customDir != null) {
      return File('${customDir.path}/jamendo_catalog.json');
    }
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/jamendo_catalog.json');
  }

  /// Membaca katalog dari cache JSON lokal di App Data.
  /// Jika cache lokal belum ada, otomatis membaca seed catalog terkurasi dari asset bundle
  /// dan menyimpannya ke cache lokal (Instant Zero-Latency & Offline-First).
  Future<List<JamendoTrack>> getCachedCatalog() async {
    try {
      final file = await _getCatalogCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            final tracks = decoded
                .map((item) => JamendoTrack.fromJson(item as Map<String, dynamic>))
                .where((t) => t.audioUrl.isNotEmpty)
                .toList();
            if (tracks.isNotEmpty) {
              return tracks;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('JamendoService: Gagal membaca cache katalog dari disk: $e');
    }

    // Fallback ke seed catalog di asset jika cache file belum tercipta
    return await _loadSeedCatalogFromAsset();
  }

  /// Memuat katalog seed bawaan dari asset
  Future<List<JamendoTrack>> _loadSeedCatalogFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/data/catalog_seed.json');
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final tracks = decoded
              .map((item) => JamendoTrack.fromJson(item as Map<String, dynamic>))
              .where((t) => t.audioUrl.isNotEmpty)
              .toList();
          if (tracks.isNotEmpty) {
            // Simpan ke cache lokal agar pembacaan berikutnya instan dari App Data
            await saveCatalogToCache(tracks);
            return tracks;
          }
        }
      }
    } catch (e) {
      debugPrint('JamendoService: Info seed asset fallback: $e');
    }
    return [];
  }

  /// Menyimpan daftar lagu ke berkas jamendo_catalog.json di App Data
  Future<void> saveCatalogToCache(List<JamendoTrack> tracks) async {
    try {
      final file = await _getCatalogCacheFile();
      final jsonString = jsonEncode(tracks.map((t) => t.toJson()).toList());
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      debugPrint('JamendoService: Gagal menyimpan cache katalog: $e');
    }
  }

  /// Mengambil katalog musik populer dari Jamendo API sekali panggil.
  /// Otomatis menyimpan hasil ke cache JSON lokal.
  Future<List<JamendoTrack>> fetchAndCacheCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedCatalog();
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    final freshTracks = await fetchTracksOnline(
      offset: 0,
      limit: 35,
      order: 'popularity_month',
    );

    if (freshTracks.isNotEmpty) {
      await saveCatalogToCache(freshTracks);
      return freshTracks;
    }

    // Jika koneksi gagal, kembalikan data cache lokal atau asset seed
    return await getCachedCatalog();
  }

  /// Mengambil daftar trek dari Jamendo API secara dinamis dengan pagination / search query
  Future<List<JamendoTrack>> fetchTracksOnline({
    int offset = 0,
    int limit = 25,
    String? search,
    String? fuzzyTags,
    String order = 'popularity_month',
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final queryParams = <String, String>{
        'client_id': _clientId,
        'format': 'json',
        'limit': limit.toString(),
        'offset': offset.toString(),
        'order': order,
        'include': 'musicinfo+lyrics',
      };

      if (search != null && search.trim().isNotEmpty) {
        queryParams['namesearch'] = search.trim();
      }
      if (fuzzyTags != null && fuzzyTags.trim().isNotEmpty && fuzzyTags.toLowerCase() != 'semua') {
        queryParams['fuzzytags'] = fuzzyTags.trim().toLowerCase();
      }

      final uri = Uri.parse('$_baseUrl/tracks').replace(queryParameters: queryParams);
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set('User-Agent', 'FlowyMusic/1.0 (Android)');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results
              .map((item) => JamendoTrack.fromJson(item as Map<String, dynamic>))
              .where((t) => t.audioUrl.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('JamendoService: Gagal fetch online tracks: $e');
    } finally {
      client.close();
    }
    return [];
  }

  /// Mencari lagu di dalam data JSON lokal (Fuzzy Search dengan toleransi typo ala Fuse.js)
  List<JamendoTrack> searchInLocalCatalog(List<JamendoTrack> catalog, String query) {
    if (query.trim().isEmpty) return catalog;
    final q = query.trim();
    final scored = <MapEntry<JamendoTrack, double>>[];
    for (final track in catalog) {
      final score = FuzzySearchEngine.scoreItem(
        query: q,
        title: track.name,
        artist: track.artistName,
        album: track.albumName,
        tags: track.tags,
      );
      if (score >= 0.50) {
        scored.add(MapEntry(track, score));
      }
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
