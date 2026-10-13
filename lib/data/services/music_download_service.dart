import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/jamendo_track.dart';

class MusicDownloadService {
  static const Duration _timeout = Duration(seconds: 45);
  static const MethodChannel _channel = MethodChannel('com.flowy.music/media_manager');

  final Directory? _customDownloadDir;

  MusicDownloadService({Directory? dir}) : _customDownloadDir = dir;

  /// Mendapatkan direktori penyimpanan file musik hasil unduhan (Folder Publik HP /Music/Flowy)
  Future<Directory> _getMusicDirectory() async {
    final customDir = _customDownloadDir;
    if (customDir != null) return customDir;

    if (Platform.isAndroid) {
      try {
        final String? publicPath = await _channel.invokeMethod<String>('getPublicMusicDir');
        if (publicPath != null && publicPath.isNotEmpty) {
          final dir = Directory(publicPath);
          if (await dir.exists() || await dir.create(recursive: true).then((_) => true).catchError((_) => false)) {
            return dir;
          }
        }
      } catch (e) {
        debugPrint('MusicDownloadService: MethodChannel getPublicMusicDir fallback: $e');
      }

      // Coba path eksternal standar Android
      final candidates = [
        Directory('/storage/emulated/0/Music/Flowy'),
        Directory('/storage/emulated/0/Download/Flowy'),
      ];
      for (final candidate in candidates) {
        try {
          if (!await candidate.exists()) {
            await candidate.create(recursive: true);
          }
          return candidate;
        } catch (_) {}
      }

      // Fallback via getExternalStorageDirectories
      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extDirs != null && extDirs.isNotEmpty) {
          return extDirs.first;
        }
      } catch (_) {}
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final downloadedDir = Directory('${appDocDir.path}/downloaded_music');
    if (!await downloadedDir.exists()) {
      await downloadedDir.create(recursive: true);
    }
    return downloadedDir;
  }

  /// Membuat nama file yang aman dari judul lagu
  String _safeFileName(String trackName, String artistName) {
    final raw = '${artistName.trim()} - ${trackName.trim()}';
    final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$safe.mp3';
  }

  /// Memeriksa apakah lagu Jamendo sudah pernah diunduh ke memori
  Future<bool> isTrackDownloaded(JamendoTrack track) async {
    try {
      final musicDir = await _getMusicDirectory();
      final fileName = _safeFileName(track.name, track.artistName);
      final file = File('${musicDir.path}/$fileName');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Mengunduh audio stream dari Jamendo dan menyimpannya sebagai file .mp3 di memori HP,
  /// lalu otomatis mendaftarkannya ke Android MediaStore via MediaScannerConnection.
  Future<File?> downloadTrack({
    required JamendoTrack track,
    Function(double progress)? onProgress,
  }) async {
    if (track.audioUrl.isEmpty) return null;

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final musicDir = await _getMusicDirectory();
      final fileName = _safeFileName(track.name, track.artistName);
      final targetFile = File('${musicDir.path}/$fileName');

      // Jika sudah ada sebelumnya, lakukan scan ulang untuk memastikan terindeks di MediaStore
      if (await targetFile.exists()) {
        await _scanFileToMediaStore(targetFile.path);
        return targetFile;
      }

      final uri = Uri.parse(track.audioUrl);
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set('User-Agent', 'FlowyMusic/1.0 (Android)');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength;
        int receivedBytes = 0;

        final sink = targetFile.openWrite();
        await response.listen(
          (chunk) {
            receivedBytes += chunk.length;
            sink.add(chunk);
            if (totalBytes > 0 && onProgress != null) {
              final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
              onProgress(progress);
            }
          },
          cancelOnError: true,
        ).asFuture();

        await sink.flush();
        await sink.close();

        // Daftarkan file baru ke Android MediaStore agar langsung terdeteksi oleh on_audio_query dan player
        await _scanFileToMediaStore(targetFile.path);

        return targetFile;
      }
    } catch (e) {
      debugPrint('MusicDownloadService: Gagal mengunduh lagu ${track.name}: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// Memicu MediaScannerConnection Android agar file langsung terindeks tanpa reboot perangkat
  Future<void> _scanFileToMediaStore(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanMediaFile', {'filePath': filePath});
      debugPrint('MusicDownloadService: Berhasil memicu MediaScanner untuk $filePath');
    } catch (e) {
      debugPrint('MusicDownloadService: MediaScanner warning: $e');
    }
  }
}
