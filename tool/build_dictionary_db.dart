import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final inputPath = _readOption(args, 'input');
  final outputPath = _readOption(args, 'output') ?? 'assets/dictionary.db';

  if (inputPath == null) {
    stdout.writeln(
      'Usage: dart run tool/build_dictionary_db.dart --input=dataset.csv --output=assets/dictionary.db',
    );
    exit(1);
  }

  final inputFile = File(p.normalize(p.absolute(inputPath)));
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${inputFile.path}');
    exit(1);
  }

  final outputFile = File(p.normalize(p.absolute(outputPath)));
  if (outputFile.existsSync()) {
    outputFile.deleteSync();
  }
  outputFile.parent.createSync(recursive: true);

  final db = await databaseFactory.openDatabase(outputFile.path);
  await _createSchema(db);

  final csvText = await inputFile.readAsString();
  final rows = const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(csvText);

  if (rows.isEmpty) {
    stderr.writeln('The CSV file is empty.');
    await db.close();
    exit(1);
  }

  final headers = rows.first
      .map((cell) => cell.toString().trim().toLowerCase())
      .toList(growable: false);

  final hasHeader = _looksLikeHeader(headers);
  final wordIndex = hasHeader ? _findHeaderIndex(headers, _englishAliases) : 0;
  final banglaIndex = hasHeader ? _findHeaderIndex(headers, _banglaAliases) : 1;
  final pronunciationIndex =
      hasHeader ? _findHeaderIndex(headers, _pronunciationAliases) : -1;
  final posIndex = hasHeader ? _findHeaderIndex(headers, _posAliases) : -1;
  final exampleIndex = hasHeader ? _findHeaderIndex(headers, _exampleAliases) : -1;
  final rankIndex = hasHeader ? _findHeaderIndex(headers, _rankAliases) : -1;

  if (wordIndex == -1 || banglaIndex == -1) {
    stderr.writeln(
      'Could not detect English and Bangla columns. Use headers like english,bangla or put them as the first two columns.',
    );
    await db.close();
    exit(1);
  }

  var inserted = 0;
  var skipped = 0;

  await db.transaction((txn) async {
    for (var rowIndex = hasHeader ? 1 : 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final word = _safeCell(row, wordIndex);
      final bangla = _safeCell(row, banglaIndex);

      if (word.isEmpty || bangla.isEmpty) {
        skipped++;
        continue;
      }

      await txn.insert('dictionary', {
        'word': word,
        'word_normalized': _normalize(word),
        'bangla': bangla,
        'pronunciation':
            pronunciationIndex == -1 ? '' : _safeCell(row, pronunciationIndex),
        'part_of_speech': posIndex == -1 ? '' : _safeCell(row, posIndex),
        'example': exampleIndex == -1 ? '' : _safeCell(row, exampleIndex),
        'search_rank': rankIndex == -1
            ? inserted
            : int.tryParse(_safeCell(row, rankIndex)) ?? inserted,
      });

      inserted++;

      if (inserted % 1000 == 0) {
        stdout.writeln('Inserted $inserted entries...');
      }
    }
  });

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_dictionary_word_normalized ON dictionary(word_normalized)',
  );

  await db.close();

  stdout.writeln('Done.');
  stdout.writeln('Inserted: $inserted');
  stdout.writeln('Skipped: $skipped');
  stdout.writeln('Database: ${p.normalize(outputFile.path)}');
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

  await db.execute('DELETE FROM dictionary');
}

String? _readOption(List<String> args, String key) {
  final prefix = '--$key=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

const _englishAliases = [
  'english',
  'word',
  'en',
  'english_word',
  'headword',
];

const _banglaAliases = [
  'bangla',
  'bengali',
  'bn',
  'meaning',
  'translation',
  'bangla_meaning',
  'bengali_meaning',
];

const _pronunciationAliases = [
  'pronunciation',
  'pronounce',
  'phonetic',
];

const _posAliases = [
  'part_of_speech',
  'pos',
  'type',
];

const _exampleAliases = [
  'example',
  'sentence',
  'usage',
];

const _rankAliases = [
  'search_rank',
  'rank',
  'priority',
];

int _findHeaderIndex(List<String> headers, List<String> aliases) {
  for (final alias in aliases) {
    final index = headers.indexOf(alias);
    if (index != -1) {
      return index;
    }
  }
  return -1;
}

bool _looksLikeHeader(List<String> headers) {
  final known = {
    ..._englishAliases,
    ..._banglaAliases,
    ..._pronunciationAliases,
    ..._posAliases,
    ..._exampleAliases,
    ..._rankAliases,
  };

  return headers.any(known.contains);
}

String _safeCell(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index].toString().trim();
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
