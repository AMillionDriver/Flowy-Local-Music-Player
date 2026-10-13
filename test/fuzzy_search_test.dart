import 'package:flutter_test/flutter_test.dart';
import 'package:flowy/core/utils/fuzzy_search.dart';

void main() {
  group('FuzzySearchEngine Tests', () {
    test('Levenshtein distance calculates edit distance correctly', () {
      expect(FuzzySearchEngine.levenshteinDistance('kitten', 'sitting'), 3);
      expect(FuzzySearchEngine.levenshteinDistance('chill', 'cill'), 1);
      expect(FuzzySearchEngine.levenshteinDistance('adele', 'adlee'), 2);
      expect(FuzzySearchEngine.levenshteinDistance('same', 'same'), 0);
    });

    test('Word similarity matches typos with high tolerance', () {
      final simChill = FuzzySearchEngine.wordSimilarity('cill', 'chill');
      expect(simChill, greaterThan(0.70));

      final simAdele = FuzzySearchEngine.wordSimilarity('adlee', 'adele');
      expect(simAdele, greaterThan(0.55));

      final simLofi = FuzzySearchEngine.wordSimilarity('lofy', 'lofi');
      expect(simLofi, greaterThan(0.70));
    });

    test('Match score handles multi-word token queries with typos', () {
      final score = FuzzySearchEngine.matchScore('ed shran', 'Ed Sheeran - Perfect');
      expect(score, greaterThan(0.70));

      final exactScore = FuzzySearchEngine.matchScore('lofi', 'Lofi Hip Hop Beats');
      expect(exactScore, greaterThan(0.85));
    });

    test('Score item weights title and artist appropriately', () {
      final scoreTitle = FuzzySearchEngine.scoreItem(
        query: 'nightfall',
        title: 'Nightfall Serenade',
        artist: 'Acoustic Sound',
      );
      expect(scoreTitle, greaterThan(0.85));

      final scoreTypo = FuzzySearchEngine.scoreItem(
        query: 'nigtfall',
        title: 'Nightfall Serenade',
        artist: 'Acoustic Sound',
      );
      expect(scoreTypo, greaterThan(0.65));
    });

    test('Get suggestions proposes corrections for typo queries', () {
      final corpus = [
        'Adele',
        'Alan Walker',
        'Chillout Sunset',
        'Lofi Midnight',
        'Electronic Pulse',
        'Ed Sheeran',
      ];

      final suggestionsAdele = FuzzySearchEngine.getSuggestions(
        query: 'adlee',
        candidatePhrases: corpus,
      );
      expect(suggestionsAdele, contains('Adele'));

      final suggestionsChill = FuzzySearchEngine.getSuggestions(
        query: 'cill',
        candidatePhrases: corpus,
      );
      expect(suggestionsChill.any((s) => s.toLowerCase().contains('chill')), isTrue);
    });
  });
}
