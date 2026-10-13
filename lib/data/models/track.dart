import 'lyric_line.dart';
import '../services/lyrics_service.dart';

enum TrackSourceType {
  bundled,
  localDevice,
}

class Track {
  final int id;
  final String orderNumber;
  final String title;
  final String artist;
  final String album;
  final String audioFormat;
  final String? sampleRate;
  final String duration;
  final int? durationMs;
  final String? coverAsset;
  final bool isFavorite;
  final List<String> tags;
  final List<LyricLine> syncedLyrics;
  final LyricsSource lyricsSource;
  final bool isInstrumental;
  final int activeLyricIndex;

  // Multi-source & Storage metadata
  final TrackSourceType sourceType;
  final String? filePath;
  final String? contentUri;
  final int? localMediaId;
  final int? albumId;

  Track({
    required this.id,
    required this.orderNumber,
    required this.title,
    required this.artist,
    required this.album,
    required this.audioFormat,
    this.sampleRate,
    required this.duration,
    this.durationMs,
    this.coverAsset,
    this.isFavorite = false,
    this.tags = const [],
    List<LyricLine>? syncedLyrics,
    List<String>? lyrics,
    this.lyricsSource = LyricsSource.none,
    this.isInstrumental = false,
    this.activeLyricIndex = 0,
    this.sourceType = TrackSourceType.localDevice,
    this.filePath,
    this.contentUri,
    this.localMediaId,
    this.albumId,
  }) : syncedLyrics = syncedLyrics ??
            (lyrics != null
                ? lyrics.map((l) => LyricLine(timestamp: Duration.zero, text: l)).toList()
                : const []);

  /// Getter backward compatibility untuk kode yang masih membaca `List<String> lyrics`
  List<String> get lyrics => syncedLyrics.map((l) => l.text).toList();

  Track copyWith({
    int? id,
    String? orderNumber,
    String? title,
    String? artist,
    String? album,
    String? audioFormat,
    String? sampleRate,
    String? duration,
    int? durationMs,
    String? coverAsset,
    bool? isFavorite,
    List<String>? tags,
    List<LyricLine>? syncedLyrics,
    LyricsSource? lyricsSource,
    bool? isInstrumental,
    int? activeLyricIndex,
    TrackSourceType? sourceType,
    String? filePath,
    String? contentUri,
    int? localMediaId,
    int? albumId,
  }) {
    return Track(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      audioFormat: audioFormat ?? this.audioFormat,
      sampleRate: sampleRate ?? this.sampleRate,
      duration: duration ?? this.duration,
      durationMs: durationMs ?? this.durationMs,
      coverAsset: coverAsset ?? this.coverAsset,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      syncedLyrics: syncedLyrics ?? this.syncedLyrics,
      lyricsSource: lyricsSource ?? this.lyricsSource,
      isInstrumental: isInstrumental ?? this.isInstrumental,
      activeLyricIndex: activeLyricIndex ?? this.activeLyricIndex,
      sourceType: sourceType ?? this.sourceType,
      filePath: filePath ?? this.filePath,
      contentUri: contentUri ?? this.contentUri,
      localMediaId: localMediaId ?? this.localMediaId,
      albumId: albumId ?? this.albumId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'title': title,
        'artist': artist,
        'album': album,
        'audioFormat': audioFormat,
        'sampleRate': sampleRate,
        'duration': duration,
        'durationMs': durationMs,
        'coverAsset': coverAsset,
        'isFavorite': isFavorite,
        'tags': tags,
        'syncedLyrics': syncedLyrics.map((l) => l.toJson()).toList(),
        'lyricsSource': lyricsSource.name,
        'isInstrumental': isInstrumental,
        'activeLyricIndex': activeLyricIndex,
        'sourceType': sourceType.name,
        'filePath': filePath,
        'contentUri': contentUri,
        'localMediaId': localMediaId,
        'albumId': albumId,
      };

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int? ?? 0,
      orderNumber: json['orderNumber'] as String? ?? '01',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      audioFormat: json['audioFormat'] as String? ?? 'MP3',
      sampleRate: json['sampleRate'] as String?,
      duration: json['duration'] as String? ?? '00:00',
      durationMs: json['durationMs'] as int?,
      coverAsset: json['coverAsset'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      syncedLyrics: (json['syncedLyrics'] as List?)
              ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lyricsSource: LyricsSource.values.firstWhere(
        (e) => e.name == json['lyricsSource'],
        orElse: () => LyricsSource.none,
      ),
      isInstrumental: json['isInstrumental'] as bool? ?? false,
      activeLyricIndex: json['activeLyricIndex'] as int? ?? 0,
      sourceType: TrackSourceType.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => TrackSourceType.localDevice,
      ),
      filePath: json['filePath'] as String?,
      contentUri: json['contentUri'] as String?,
      localMediaId: json['localMediaId'] as int?,
      albumId: json['albumId'] as int?,
    );
  }
}
