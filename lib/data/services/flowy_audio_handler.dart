import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class FlowyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  // Antrean lagu & status pemutaran dikelola 100% mandiri di level AudioHandler
  List<Track> _playlist = [];
  int _currentIndex = -1;
  Track? _currentTrack;
  bool _isShuffle = false;
  bool _isRepeat = false;

  VoidCallback? onStop;

  FlowyAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _initAudioStreams();
  }

  AudioPlayer get player => _player;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  Track? get currentTrack => _currentTrack;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;

  void updatePlaylist(List<Track> tracks, {int? activeIndex}) {
    _playlist = List<Track>.from(tracks);
    if (activeIndex != null && activeIndex >= 0 && activeIndex < _playlist.length) {
      _currentIndex = activeIndex;
      _currentTrack = _playlist[_currentIndex];
    } else if (_currentTrack != null) {
      final foundIdx = _playlist.indexWhere((t) => t.id == _currentTrack!.id);
      if (foundIdx != -1) {
        _currentIndex = foundIdx;
      }
    }
  }

  void setShuffle(bool shuffle) {
    _isShuffle = shuffle;
  }

  void setRepeat(bool repeat) {
    _isRepeat = repeat;
    _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
  }

  void _initAudioStreams() {
    // 1. Transformasi dan broadcast event playback just_audio ke Android MediaSession / Notification
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2], // Prev (0), Play/Pause (1), Next (2) di compact view
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    // 2. Auto-advance mandiri: lanjut ke lagu berikutnya saat selesai, bahkan saat app di-kill
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_isRepeat) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });
  }

  /// Memutar lagu pada index tertentu dari antrean internal
  Future<bool> playAtIndex(int index) async {
    if (_playlist.isEmpty) return false;
    if (index < 0 || index >= _playlist.length) {
      index = 0;
    }
    _currentIndex = index;
    return await playTrack(_playlist[_currentIndex]);
  }

  /// Memutar lagu dan otomatis meng-update Media Notification di Status Bar & Lock Screen
  Future<bool> playTrack(Track track) async {
    try {
      _currentTrack = track;

      // Sinkronkan ke antrean jika belum ada
      final foundIdx = _playlist.indexWhere((t) => t.id == track.id);
      if (foundIdx != -1) {
        _currentIndex = foundIdx;
      } else {
        _playlist.insert(0, track);
        _currentIndex = 0;
      }

      // 1. Hitung durasi awal untuk MediaItem notifikasi
      Duration? itemDuration;
      if (track.durationMs != null && track.durationMs! > 0) {
        itemDuration = Duration(milliseconds: track.durationMs!);
      } else {
        final parts = track.duration.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = int.tryParse(parts[1]) ?? 0;
          itemDuration = Duration(seconds: m * 60 + s);
        }
      }

      // 2. Siapkan MediaItem untuk ditampilkan di Status Bar / Notification Shade / Lock Screen
      Uri? resolvedArtUri;
      if (track.coverAsset != null && track.coverAsset!.isNotEmpty) {
        if (track.coverAsset!.startsWith('http://') || track.coverAsset!.startsWith('https://')) {
          resolvedArtUri = Uri.parse(track.coverAsset!);
        } else if (track.coverAsset!.startsWith('file://')) {
          resolvedArtUri = Uri.parse(track.coverAsset!);
        } else if (track.coverAsset!.startsWith('/')) {
          resolvedArtUri = Uri.file(track.coverAsset!);
        }
      }
      resolvedArtUri ??= (track.localMediaId != null
          ? Uri.parse('content://media/external/audio/media/${track.localMediaId}/albumart')
          : null);

      final item = MediaItem(
        id: track.id.toString(),
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: itemDuration,
        artUri: resolvedArtUri,
      );
      mediaItem.add(item);

      // 3. Load & Play Audio (Content URI First untuk Scoped Storage Android 11+)
      if (Platform.isAndroid) {
        final contentUri = (track.contentUri != null && track.contentUri!.isNotEmpty)
            ? track.contentUri!
            : (track.localMediaId != null
                ? 'content://media/external/audio/media/${track.localMediaId}'
                : null);

        if (contentUri != null) {
          try {
            await _player.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
            await _player.play();
            return true;
          } catch (contentError) {
            debugPrint('Content URI gagal dimuat ($contentUri): $contentError');
          }
        }
      }

      // Fallback: File Path
      if (track.filePath != null && track.filePath!.isNotEmpty) {
        final file = File(track.filePath!);
        if (await file.exists()) {
          try {
            await _player.setFilePath(track.filePath!);
            await _player.play();
            return true;
          } catch (fileError) {
            debugPrint('setFilePath fallback gagal: $fileError');
          }
        }
      }

      // Fallback alternatif
      if (track.contentUri != null && track.contentUri!.isNotEmpty) {
        try {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(track.contentUri!)));
          await _player.play();
          return true;
        } catch (uriError) {
          debugPrint('AudioSource.uri fallback gagal: $uriError');
        }
      }

      debugPrint('FlowyAudioHandler: Gagal memutar audio untuk "${track.title}"');
      return false;
    } catch (e) {
      debugPrint('FlowyAudioHandler error saat memutar "${track.title}": $e');
      return false;
    }
  }

  // --- Implementasi Callback Kontrol Sistem (Notifikasi, Lock Screen & Headset) ---

  @override
  Future<void> play() async => await _player.play();

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [],
    ));
    if (onStop != null) {
      onStop!();
    }
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle && _playlist.length > 1) {
      final random = Random();
      int nextIdx = random.nextInt(_playlist.length);
      while (_currentIndex != -1 && nextIdx == _currentIndex && _playlist.length > 1) {
        nextIdx = random.nextInt(_playlist.length);
      }
      await playAtIndex(nextIdx);
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        nextIndex = 0; // Loop kembali ke awal antrean
      }
      await playAtIndex(nextIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;

    // Jika posisi putar sudah lebih dari 3 detik, restart lagu saat ini
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _playlist.length - 1;
    }
    await playAtIndex(prevIndex);
  }

  Future<void> setLoop(bool loop) async {
    setRepeat(loop);
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}
