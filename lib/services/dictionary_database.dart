import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/dictionary_entry.dart';

class DictionaryDatabase {
  DictionaryDatabase._();

  static final DictionaryDatabase instance = DictionaryDatabase._();

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    final appSupportDir = await getApplicationSupportDirectory();
    final databaseDir =
        Directory(p.join(appSupportDir.path, 'english_bangla_dictionary'));

    if (!databaseDir.existsSync()) {
      databaseDir.createSync(recursive: true);
    }

    final databasePath = p.join(databaseDir.path, 'dictionary.db');
    final databaseFile = File(databasePath);

    if (!databaseFile.existsSync()) {
      await _prepareInitialDatabase(databaseFile);
    } else {
      await _replaceEmptyDatabaseIfAssetExists(databaseFile);
    }

    _database = await databaseFactory.openDatabase(databasePath);
  }

  Future<void> _prepareInitialDatabase(File databaseFile) async {
    try {
      final bytes = await rootBundle.load('assets/dictionary.db');
      await databaseFile.writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );
      return;
    } catch (_) {
      final db = await databaseFactory.openDatabase(databaseFile.path);
      await _createSchema(db);
      await db.close();
    }
  }

  Future<void> _replaceEmptyDatabaseIfAssetExists(File databaseFile) async {
    final existingDb = await databaseFactory.openDatabase(databaseFile.path);
    try {
      final result = await existingDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='dictionary'",
      );

      if (result.isEmpty) {
        return;
      }

      final total = await existingDb.rawQuery(
        'SELECT COUNT(*) AS total FROM dictionary',
      );
      final count = (total.first['total'] as num?)?.toInt() ?? 0;

      if (count > 0) {
        return;
      }
    } finally {
      await existingDb.close();
    }

    try {
      final bytes = await rootBundle.load('assets/dictionary.db');
      await databaseFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } catch (_) {
      // Keep the existing empty database if no asset is bundled yet.
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        word_normalized TEXT NOT NULL COLLATE NOCASE,
        bangla TEXT NOT NULL,
        pronunciation TEXT DEFAULT '',
        part_of_speech TEXT DEFAULT '',
        example TEXT DEFAULT '',
        search_rank INTEGER DEFAULT 999999
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dictionary_word_normalized
      ON dictionary(word_normalized);
    ''');
  }

  Future<int> totalEntries() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM dictionary',
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<DictionaryEntry>> searchWords(
    String rawQuery, {
    int limit = 200,
  }) async {
    final query = _normalize(rawQuery);
    if (query.isEmpty) {
      return const [];
    }

    final db = await _db;
    final upperBound = '$query\uffff';
    final banglaLike = '%${rawQuery.trim()}%';

    final rows = await db.rawQuery(
      '''
      SELECT
        id,
        word,
        bangla,
        pronunciation,
        part_of_speech,
        example,
        search_rank
      FROM dictionary
      WHERE
        (word_normalized >= ? AND word_normalized < ?)
        OR bangla LIKE ?
      ORDER BY
        CASE
          WHEN word_normalized = ? THEN 0
          WHEN word_normalized LIKE ? THEN 1
          WHEN bangla = ? THEN 2
          WHEN bangla LIKE ? THEN 3
          ELSE 4
        END,
        search_rank ASC,
        LENGTH(word) ASC,
        word ASC
      LIMIT ?
      ''',
      [query, upperBound, banglaLike, query, '$query%', rawQuery.trim(), banglaLike, limit],
    );

    if (rows.isNotEmpty) {
      return rows.map(DictionaryEntry.fromMap).toList(growable: false);
    }

    final fallbackRows = await db.rawQuery(
      '''
      SELECT
        id,
        word,
        bangla,
        pronunciation,
        part_of_speech,
        example,
        search_rank
      FROM dictionary
      WHERE word_normalized LIKE ? OR bangla LIKE ?
      ORDER BY search_rank ASC, LENGTH(word) ASC, word ASC
      LIMIT ?
      ''',
      ['%$query%', banglaLike, limit],
    );

    return fallbackRows.map(DictionaryEntry.fromMap).toList(growable: false);
  }

  Future<Database> get _db async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
