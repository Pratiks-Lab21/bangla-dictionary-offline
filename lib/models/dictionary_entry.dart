class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.word,
    required this.bangla,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.example,
    required this.searchRank,
  });

  final int id;
  final String word;
  final String bangla;
  final String pronunciation;
  final String partOfSpeech;
  final String example;
  final int searchRank;

  factory DictionaryEntry.fromMap(Map<String, Object?> map) {
    return DictionaryEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      word: (map['word'] as String? ?? '').trim(),
      bangla: (map['bangla'] as String? ?? '').trim(),
      pronunciation: (map['pronunciation'] as String? ?? '').trim(),
      partOfSpeech: (map['part_of_speech'] as String? ?? '').trim(),
      example: (map['example'] as String? ?? '').trim(),
      searchRank: (map['search_rank'] as num?)?.toInt() ?? 999999,
    );
  }
}
