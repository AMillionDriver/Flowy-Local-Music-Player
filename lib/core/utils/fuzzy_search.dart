import 'dart:math';

/// Engine pencarian Fuzzy (Toleransi Typo) terinspirasi oleh Fuse.js.
/// Ringan, cepat, dan dioptimasi untuk perangkat low-end (O(N) pruning tanpa alokasi memori berlebih).
class FuzzySearchEngine {
  /// Menghitung jarak Levenshtein (jumlah edit minimal karakter) antara dua string
  static int levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Optimasi alokasi: gunakan 2 baris buffer alih-alih matriks NxM lengkap
    final lenA = a.length;
    final lenB = b.length;
    List<int> v0 = List<int>.generate(lenB + 1, (i) => i);
    List<int> v1 = List<int>.filled(lenB + 1, 0);

    for (int i = 0; i < lenA; i++) {
      v1[0] = i + 1;
      final charA = a.codeUnitAt(i);

      for (int j = 0; j < lenB; j++) {
        final cost = (charA == b.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(
          v1[j] + 1, // insertion
          min(
            v0[j + 1] + 1, // deletion
            v0[j] + cost, // substitution
          ),
        );
      }

      for (int j = 0; j <= lenB; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[lenB];
  }

  /// Menghitung derajat kemiripan antara dua kata (0.0 sampai 1.0)
  static double wordSimilarity(String s1, String s2) {
    final str1 = s1.toLowerCase().trim();
    final str2 = s2.toLowerCase().trim();

    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    // Jika salah satu adalah substring langsung
    if (str2.contains(str1)) {
      return 0.85 + (str1.length / str2.length) * 0.15;
    }
    if (str1.contains(str2)) {
      return 0.85 + (str2.length / str1.length) * 0.15;
    }

    final maxLen = max(str1.length, str2.length);
    if (maxLen == 0) return 1.0;

    // Cek kecocokan prefix jika salah satu kata lebih panjang (misal 'cill' vs 'chillout')
    if (str2.length > str1.length && str1.length >= 3) {
      final prefix = str2.substring(0, min(str2.length, str1.length + 1));
      final pDist = levenshteinDistance(str1, prefix);
      final pScore = 1.0 - (pDist / max(str1.length, prefix.length));
      if (pScore >= 0.75) {
        return pScore * 0.95;
      }
    } else if (str1.length > str2.length && str2.length >= 3) {
      final prefix = str1.substring(0, min(str1.length, str2.length + 1));
      final pDist = levenshteinDistance(str2, prefix);
      final pScore = 1.0 - (pDist / max(str2.length, prefix.length));
      if (pScore >= 0.75) {
        return pScore * 0.95;
      }
    }

    final dist = levenshteinDistance(str1, str2);
    // Kemiripan berbanding terbalik dengan jarak edit
    final score = 1.0 - (dist / maxLen);
    return max(0.0, score);
  }

  /// Menghitung kemiripan kueri multi-kata (Tokenized Query Matching)
  static double matchScore(String query, String target) {
    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();

    if (q.isEmpty || t.isEmpty) return 0.0;
    if (t == q) return 1.0;

    // Exact Substring match: prioritas tertinggi
    if (t.contains(q)) {
      return 0.90 + (q.length / t.length) * 0.10;
    }

    final queryTokens = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final targetTokens = t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    if (queryTokens.isEmpty || targetTokens.isEmpty) return 0.0;

    double totalScore = 0.0;

    for (final qToken in queryTokens) {
      double bestTokenScore = 0.0;

      // Cek apakah qToken adalah substring dari target
      if (t.contains(qToken)) {
        bestTokenScore = 0.90;
      } else {
        // Cek kemiripan fuzzy qToken terhadap setiap token di target
        for (final tToken in targetTokens) {
          final sim = wordSimilarity(qToken, tToken);
          if (sim > bestTokenScore) {
            bestTokenScore = sim;
          }
        }
      }

      totalScore += bestTokenScore;
    }

    return totalScore / queryTokens.length;
  }

  /// Menghitung skor gabungan dengan bobot untuk berbagai properti (Judul, Artis, Album, dll.)
  static double scoreItem({
    required String query,
    required String title,
    String? artist,
    String? album,
    List<String> tags = const [],
  }) {
    if (query.trim().isEmpty) return 1.0;

    final titleScore = matchScore(query, title) * 1.0;
    final artistScore = artist != null ? matchScore(query, artist) * 0.90 : 0.0;
    final albumScore = album != null ? matchScore(query, album) * 0.70 : 0.0;

    double tagScore = 0.0;
    for (final tag in tags) {
      final s = matchScore(query, tag) * 0.50;
      if (s > tagScore) tagScore = s;
    }

    return max(titleScore, max(artistScore, max(albumScore, tagScore)));
  }

  /// Menghasilkan saran kata / frasa ("Mungkin maksud Anda...") berdasarkan kata yang mirip di corpus
  static List<String> getSuggestions({
    required String query,
    required Iterable<String> candidatePhrases,
    int maxSuggestions = 3,
    double minSimilarity = 0.50,
  }) {
    final q = query.toLowerCase().trim();
    if (q.length < 2) return const [];

    final suggestions = <MapEntry<String, double>>[];
    final seen = <String>{};

    for (final phrase in candidatePhrases) {
      final pTrim = phrase.trim();
      final pLower = pTrim.toLowerCase();
      if (pTrim.isEmpty || pLower == q || seen.contains(pLower)) continue;

      final score = matchScore(q, pLower);
      if (score >= minSimilarity && score < 1.0) {
        suggestions.add(MapEntry(pTrim, score));
        seen.add(pLower);
      }
    }

    // Urutkan dari yang skornya paling mendekati kueri
    suggestions.sort((a, b) => b.value.compareTo(a.value));

    return suggestions.take(maxSuggestions).map((e) => e.key).toList();
  }
}
