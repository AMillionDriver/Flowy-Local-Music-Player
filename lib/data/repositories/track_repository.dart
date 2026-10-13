import '../models/track.dart';
import '../services/local_audio_service.dart';
import '../services/download_manifest_storage.dart';

class TrackRepository {
  final LocalAudioService _localAudioService;
  final DownloadManifestStorage _manifestStorage;
  final Set<int> _hiddenTrackIds = {};
  List<Track> _localTracks = [];

  TrackRepository({
    LocalAudioService? localAudioService,
    DownloadManifestStorage? manifestStorage,
    List<Track>? initialTracks,
  })  : _localAudioService = localAudioService ?? LocalAudioService(),
        _manifestStorage = manifestStorage ?? DownloadManifestStorage(),
        _localTracks = initialTracks != null ? List<Track>.from(initialTracks) : [];

  Set<int> get hiddenTrackIds => Set.unmodifiable(_hiddenTrackIds);
  DownloadManifestStorage get manifestStorage => _manifestStorage;

  void hideTrack(int id) {
    _hiddenTrackIds.add(id);
  }

  void unhideAll() {
    _hiddenTrackIds.clear();
  }

  /// Memindai lagu nyata dari penyimpanan perangkat (Internal Storage & MicroSD Card)
  /// secara hybrid: memadukan berkas unduhan dari manifest persisten dengan hasil query MediaStore.
  Future<List<Track>> scanLocalTracks() async {
    // 1. Muat seluruh lagu yang telah diunduh (terjamin instan & valid)
    final downloaded = await _manifestStorage.loadTracks();

    // 2. Muat seluruh lagu lokal di MediaStore perangkat
    final scanned = await _localAudioService.queryDeviceTracks();

    // 3. Gabungkan dan deduplikasi (Prioritaskan lagu unduhan Flowy yang memiliki cover & lirik)
    final existingPaths = downloaded
        .where((d) => d.filePath != null)
        .map((d) => d.filePath!.toLowerCase())
        .toSet();
    final existingSignatures = downloaded
        .map((d) => '${d.title.trim().toLowerCase()} - ${d.artist.trim().toLowerCase()}')
        .toSet();

    final merged = List<Track>.from(downloaded);

    for (final track in scanned) {
      final p = track.filePath?.toLowerCase();
      final sig = '${track.title.trim().toLowerCase()} - ${track.artist.trim().toLowerCase()}';
      if ((p != null && existingPaths.contains(p)) || existingSignatures.contains(sig)) {
        continue; // Abaikan duplikat dari MediaStore
      }
      merged.add(track);
    }

    _localTracks = merged;
    return getTracks();
  }

  /// Mendaftarkan lagu baru yang diunduh ke manifest persisten dan memori repository
  Future<void> addDownloadedTrack(Track track) async {
    await _manifestStorage.saveTrack(track);
    _localTracks.removeWhere((t) =>
        t.id == track.id ||
        (t.filePath != null && track.filePath != null && t.filePath == track.filePath));
    _localTracks.insert(0, track);
  }

  /// Menghapus lagu unduhan dari manifest persisten dan memori repository
  Future<void> removeDownloadedTrack(int id, {String? filePath}) async {
    await _manifestStorage.removeTrack(id, filePath: filePath);
    _localTracks.removeWhere((t) =>
        t.id == id ||
        (filePath != null && t.filePath != null && t.filePath == filePath));
  }

  /// Mengembalikan seluruh lagu yang aktif (tidak disembunyikan).
  List<Track> getTracks() {
    return _localTracks.where((t) => !_hiddenTrackIds.contains(t.id)).toList();
  }
}
