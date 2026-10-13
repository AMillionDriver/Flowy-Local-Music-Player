import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'flowy_audio_handler.dart';

class AudioPlayerService {
  final FlowyAudioHandler _handler;

  AudioPlayerService({FlowyAudioHandler? handler})
      : _handler = handler ?? FlowyAudioHandler();

  FlowyAudioHandler get handler => _handler;
  AudioPlayer get player => _handler.player;
  Stream<Duration> get positionStream => _handler.player.positionStream;
  Stream<Duration?> get durationStream => _handler.player.durationStream;
  Stream<PlayerState> get playerStateStream => _handler.player.playerStateStream;

  Duration get currentPosition => _handler.player.position;
  Duration? get duration => _handler.player.duration;
  bool get isPlaying => _handler.player.playing;

  Future<bool> playTrack(Track track) async => await _handler.playTrack(track);

  Future<void> pause() async => await _handler.pause();

  Future<void> resume() async => await _handler.play();

  Future<void> seek(Duration position) async => await _handler.seek(position);

  Future<void> stop() async => await _handler.stop();

  Future<void> setLoop(bool loop) async => await _handler.setLoop(loop);

  void dispose() {
    _handler.disposePlayer();
  }
}
