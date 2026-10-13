import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

/// Service persisten untuk menyimpan dan memuat metadata lagu yang telah diunduh
/// ke berkas `downloaded_tracks.json` di App Data directory.
/// Memastikan lagu yang diunduh langsung terdeteksi 100% tanpa bergantung pada jeda scan MediaStore.
class DownloadManifestStorage {
  static const String _fileName = 'downloaded_tracks.json';
  final Directory? customDir;

  DownloadManifestStorage({this.customDir});

  Future<File> _getFile() async {
    final custom = customDir;
    if (custom != null) {
      return File('${custom.path}/$_fileName');
    }
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/$_fileName');
  }

  /// Memuat daftar lagu unduhan yang valid (memverifikasi berkas fisik masih ada di storage)
  Future<List<Track>> loadTracks() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final decoded = jsonDecode(content);
      if (decoded is! List) return [];

      final validTracks = <Track>[];
      bool hadMissingFiles = false;

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            final track = Track.fromJson(item);
            // Validasi keberadaan fisik file di storage perangkat
            if (track.filePath != null && track.filePath!.isNotEmpty) {
              final physicalFile = File(track.filePath!);
              if (await physicalFile.exists()) {
                validTracks.add(track);
              } else {
                hadMissingFiles = true;
              }
            } else {
              validTracks.add(track);
            }
          } catch (e) {
            debugPrint('DownloadManifestStorage: Gagal parse item track: $e');
          }
        }
      }

      // Bersihkan manifest jika ada berkas yang telah dihapus user secara eksternal
      if (hadMissingFiles) {
        await _saveToFile(file, validTracks);
      }

      return validTracks;
    } catch (e) {
      debugPrint('DownloadManifestStorage: Gagal membaca manifest unduhan: $e');
      return [];
    }
  }

  /// Menyimpan atau memperbarui track ke manifest unduhan
  Future<void> saveTrack(Track track) async {
    try {
      final file = await _getFile();
      final tracks = await loadTracks();

      // Hapus entri lama jika ID atau file path sama
      tracks.removeWhere((t) =>
          t.id == track.id ||
          (t.filePath != null && track.filePath != null && t.filePath == track.filePath));

      // Sisipkan di posisi teratas sebagai yang paling baru diunduh
      tracks.insert(0, track);

      await _saveToFile(file, tracks);
    } catch (e) {
      debugPrint('DownloadManifestStorage: Gagal menyimpan track ke manifest: $e');
    }
  }

  /// Menghapus track dari manifest
  Future<void> removeTrack(int trackId, {String? filePath}) async {
    try {
      final file = await _getFile();
      final tracks = await loadTracks();
      tracks.removeWhere((t) =>
          t.id == trackId ||
          (filePath != null && t.filePath != null && t.filePath == filePath));
      await _saveToFile(file, tracks);
    } catch (e) {
      debugPrint('DownloadManifestStorage: Gagal menghapus track dari manifest: $e');
    }
  }

  Future<void> _saveToFile(File file, List<Track> tracks) async {
    final jsonList = tracks.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList), flush: true);
  }
}
