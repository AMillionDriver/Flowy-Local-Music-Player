import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

class LocalAudioService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Meminta izin audio sesuai versi Android.
  Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Coba via method bawaan on_audio_query
    final bool hasPermission = await _audioQuery.permissionsStatus();
    if (hasPermission) return true;

    final bool requested = await _audioQuery.permissionsRequest();
    if (requested) return true;

    // 2. Fallback via permission_handler
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Memindai seluruh berkas audio di Internal Storage dan MicroSD Card.
  Future<List<Track>> queryDeviceTracks() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return [];

      // Query seluruh file audio dari MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
      final List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final List<Track> tracks = [];
      int order = 1;

      for (final song in songs) {
        // Filter: Hanya berkas musik dengan durasi > 15 detik (abaikan ringtone / voice note)
        final isMusic = song.isMusic ?? true;
        final durationMs = song.duration ?? 0;
        if (!isMusic || durationMs < 15000) continue;

        // Ekstraksi format audio dari ekstensi berkas
        final ext = (song.fileExtension).toUpperCase();
        final formatLabel = ext.isNotEmpty ? ext : 'AUDIO';

        // Format durasi MM:SS
        final totalSeconds = (durationMs / 1000).round();
        final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        final durationString = '$minutes:$seconds';

        // Pastikan Content URI selalu valid dan deterministik untuk Android Scoped Storage
        final contentUriString = (song.uri != null && song.uri!.isNotEmpty)
            ? song.uri!
            : 'content://media/external/audio/media/${song.id}';

        tracks.add(
          Track(
            id: song.id,
            orderNumber: order.toString().padLeft(2, '0'),
            title: song.title.isNotEmpty ? song.title : 'Lagu Tanpa Judul',
            artist: (song.artist != null && song.artist != '<unknown>')
                ? song.artist!
                : 'Artis Tidak Diketahui',
            album: (song.album != null && song.album != '<unknown>')
                ? song.album!
                : 'Penyimpanan Lokal',
            audioFormat: formatLabel,
            sampleRate: ext == 'FLAC' ? 'Hi-Res' : null,
            duration: durationString,
            durationMs: durationMs,
            coverAsset: null,
            sourceType: TrackSourceType.localDevice,
            filePath: song.data,
            contentUri: contentUriString,
            localMediaId: song.id,
            albumId: song.albumId,
            tags: [
              'all',
              'local',
              if (ext == 'FLAC') 'flac',
            ],
            syncedLyrics: const [],
            activeLyricIndex: 0,
          ),
        );
        order++;
      }

      return tracks;
    } catch (_) {
      return [];
    }
  }
}
