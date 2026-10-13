import 'dart:io';
import 'package:flutter/services.dart';

class MediaDeletionService {
  static const MethodChannel _channel = MethodChannel('com.flowy.music/media_manager');

  /// Menghapus file audio secara fisik dari perangkat (Internal Storage / SD Card).
  /// Mengembalikan `true` jika disetujui dan berhasil dihapus, `false` jika dibatalkan atau gagal.
  static Future<bool> deletePermanently({
    required int mediaId,
    String? filePath,
  }) async {
    try {
      // 1. Coba hapus langsung jika path lokal ada dan aplikasi memiliki hak akses langsung
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          try {
            await file.delete();
            return true;
          } catch (_) {
            // Jika Android melempar FileSystemException (Scoped Storage),
            // lanjutkan ke pemanggilan dialog sistem Android via Platform Channel di bawah
          }
        }
      }

      // 2. Panggil dialog konfirmasi OS Android (MediaStore.createDeleteRequest)
      final bool? isDeleted = await _channel.invokeMethod<bool>('deleteAudioMedia', {
        'mediaId': mediaId,
        'filePath': filePath,
      });

      return isDeleted ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
