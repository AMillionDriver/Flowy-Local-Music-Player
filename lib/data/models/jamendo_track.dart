class JamendoTrack {
  final String id;
  final String name;
  final String artistName;
  final String albumName;
  final int duration; // durasi dalam detik
  final String audioUrl;
  final String imageUrl;
  final String shareUrl;
  final List<String> tags;
  final bool isDownloaded;
  final String? lyricsText;

  const JamendoTrack({
    required this.id,
    required this.name,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.audioUrl,
    required this.imageUrl,
    required this.shareUrl,
    this.tags = const [],
    this.isDownloaded = false,
    this.lyricsText,
  });

  String get formattedDuration {
    final m = (duration ~/ 60).toString().padLeft(2, '0');
    final s = (duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory JamendoTrack.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['musicinfo'] != null && json['musicinfo']['tags'] != null) {
      final tagsJson = json['musicinfo']['tags'];
      if (tagsJson is Map<String, dynamic>) {
        final genres = tagsJson['genres'];
        if (genres is List) {
          parsedTags.addAll(genres.map((e) => e.toString()));
        }
      }
    }

    return JamendoTrack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Lagu Tanpa Judul',
      artistName: json['artist_name']?.toString() ?? 'Artis Independen',
      albumName: json['album_name']?.toString() ?? 'Katalog Jamendo',
      duration: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      audioUrl: json['audio']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? json['album_image']?.toString() ?? '',
      shareUrl: json['shareurl']?.toString() ?? '',
      tags: parsedTags,
      lyricsText: json['lyrics']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist_name': artistName,
      'album_name': albumName,
      'duration': duration,
      'audio': audioUrl,
      'image': imageUrl,
      'shareurl': shareUrl,
      'lyrics': lyricsText,
      'musicinfo': {
        'tags': {
          'genres': tags,
        }
      },
    };
  }

  JamendoTrack copyWith({
    bool? isDownloaded,
    String? lyricsText,
  }) {
    return JamendoTrack(
      id: id,
      name: name,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
      audioUrl: audioUrl,
      imageUrl: imageUrl,
      shareUrl: shareUrl,
      tags: tags,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      lyricsText: lyricsText ?? this.lyricsText,
    );
  }
}
