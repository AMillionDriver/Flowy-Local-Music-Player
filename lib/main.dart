import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'data/services/audio_player_service.dart';
import 'data/services/flowy_audio_handler.dart';
import 'presentation/controllers/player_controller.dart';
import 'presentation/screens/home_screen.dart';

AudioHandler? _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimasi RAM Low-End (Oppo A16 / 3GB RAM):
  // Batasi cache gambar Skia/Engine hanya maks 30 gambar & 15 MB (default Flutter 100 MB)
  PaintingBinding.instance.imageCache.maximumSize = 30;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 15 * 1024 * 1024;

  try {
    _audioHandler = await AudioService.init(
      builder: () => FlowyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.flowy.music.channel.audio',
        androidNotificationChannelName: 'Pemutar Musik Flowy',
        androidNotificationChannelDescription: 'Menampilkan kontrol pemutaran media Flowy',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: false, // Hemat memori bitmap badge
        androidStopForegroundOnPause: true, // Notifikasi bisa di-swipe hilang saat dipause & foreground service dilepas bersih
      ),
    );
  } catch (e) {
    debugPrint('AudioService.init lewati inisialisasi: $e');
  }
  runApp(const FlowyApp());
}

class FlowyApp extends StatefulWidget {
  final PlayerController? controller;

  const FlowyApp({super.key, this.controller});

  @override
  State<FlowyApp> createState() => _FlowyAppState();
}

class _FlowyAppState extends State<FlowyApp> {
  late final PlayerController _playerController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _playerController = widget.controller!;
    } else {
      final audioService = AudioPlayerService(
        handler: _audioHandler is FlowyAudioHandler
            ? (_audioHandler as FlowyAudioHandler)
            : null,
      );
      _playerController = PlayerController(audioService: audioService);
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _playerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(controller: _playerController),
    );
  }
}
