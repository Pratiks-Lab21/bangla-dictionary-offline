Place your generated SQLite file here as:

assets/dictionary.db

Expected table:
dictionary(
  id INTEGER PRIMARY KEY,
  word TEXT,
  word_normalized TEXT,
  bangla TEXT,
  pronunciation TEXT,
  part_of_speech TEXT,
  example TEXT,
  search_rank INTEGER
)
