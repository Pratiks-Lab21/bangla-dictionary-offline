# English to Bangla Dictionary Desktop App

Flutter desktop dictionary app for very large datasets using SQLite.

## Features

- Fast local search for 300k+ English words
- Bangla meaning panel
- Optional pronunciation, part of speech, and example
- Desktop-friendly split layout
- Offline database

## Project files

- `lib/main.dart`: app UI
- `lib/services/dictionary_database.dart`: database copy and search logic
- `lib/models/dictionary_entry.dart`: model
- `lib/widgets/entry_details_card.dart`: details panel
- `tool/build_dictionary_db.dart`: CSV to SQLite builder

## Required CSV headers

Your dataset should contain at least:

- `english`
- `bangla`

Optional headers:

- `pronunciation`
- `part_of_speech`
- `example`
- `search_rank`

## Output database

Generate this file before running the app:

- `assets/dictionary.db`

## Example CSV row

```csv
english,bangla,pronunciation,part_of_speech,example,search_rank
apple,আপেল,ap-uhl,noun,I ate an apple today,1
```

## Notes

- The app opens even if the database is missing, but search results will stay empty.
- For best performance with 300k+ rows, keep `word_normalized` indexed as created by the builder script.
