import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models/dictionary_entry.dart';
import 'services/dictionary_database.dart';
import 'widgets/entry_details_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await DictionaryDatabase.instance.initialize();
  runApp(const DictionaryApp());
}

class DictionaryApp extends StatelessWidget {
  const DictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bangla Dictionary Offline',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB7410E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F2EC),
      ),
      home: const DictionaryHomePage(),
    );
  }
}

class DictionaryHomePage extends StatefulWidget {
  const DictionaryHomePage({super.key});

  @override
  State<DictionaryHomePage> createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ThemeMode _themeMode = ThemeMode.light;
  List<DictionaryEntry> _results = const [];
  DictionaryEntry? _selectedEntry;
  final List<DictionaryEntry> _history = [];
  final List<DictionaryEntry> _favorites = [];
  Timer? _debounce;
  bool _isSearching = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _runSearch(_controller.text);
    });
  }

  Future<void> _runSearch(String query) async {
    final currentToken = ++_searchToken;
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const [];
        _selectedEntry = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await DictionaryDatabase.instance.searchWords(trimmed);

    if (!mounted || currentToken != _searchToken) {
      return;
    }

    setState(() {
      _results = results;
      _selectedEntry = results.isEmpty ? null : results.first;
      _isSearching = false;
    });

    if (results.isNotEmpty) {
      _rememberEntry(results.first);
    }
  }

  void _rememberEntry(DictionaryEntry entry) {
    setState(() {
      _history.removeWhere((item) => item.id == entry.id);
      _history.insert(0, entry);
      if (_history.length > 20) {
        _history.removeLast();
      }
    });
  }

  void _selectEntry(DictionaryEntry entry) {
    setState(() {
      _selectedEntry = entry;
    });
    _rememberEntry(entry);
  }

  void _toggleFavorite() {
    final entry = _selectedEntry;
    if (entry == null) {
      return;
    }

    setState(() {
      final index = _favorites.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        _favorites.insert(0, entry);
      } else {
        _favorites.removeAt(index);
      }
    });
  }

  bool _isFavorite(DictionaryEntry? entry) {
    if (entry == null) {
      return false;
    }
    return _favorites.any((item) => item.id == entry.id);
  }

  Future<void> _openCollectionPage({
    required String title,
    required IconData icon,
    required List<DictionaryEntry> entries,
  }) async {
    final selected = await Navigator.of(context).push<DictionaryEntry>(
      MaterialPageRoute(
        builder: (context) => CollectionPage(
          title: title,
          icon: icon,
          entries: List<DictionaryEntry>.from(entries),
          isDarkMode: _themeMode == ThemeMode.dark,
        ),
      ),
    );

    if (selected != null) {
      _selectEntry(selected);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;
    final themeData = isDark
        ? ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFDE7A22),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF111827),
          )
        : ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB7410E),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F2EC),
          );

    return Theme(
      data: themeData,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF151A22),
                      Color(0xFF111827),
                      Color(0xFF1B2430),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF6EEDF),
                      Color(0xFFF5F8FA),
                      Color(0xFFEFF3F6),
                    ],
                  ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopBar(
                        themeMode: _themeMode,
                        onToggleTheme: () {
                          setState(() {
                            _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
                          });
                        },
                        onOpenFavorites: () => _openCollectionPage(
                          title: 'Favourites',
                          icon: Icons.favorite_rounded,
                          entries: _favorites,
                        ),
                        onOpenHistory: () => _openCollectionPage(
                          title: 'History',
                          icon: Icons.history_rounded,
                          entries: _history,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SearchBarCard(
                        controller: _controller,
                        focusNode: _focusNode,
                        isSearching: _isSearching,
                        onClear: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: compact
                            ? Column(
                                children: [
                                  Expanded(
                                    child: ResultsPanel(
                                      results: _results,
                                      selectedEntry: _selectedEntry,
                                      query: _controller.text,
                                      onTap: _selectEntry,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: EntryDetailsCard(
                                      entry: _selectedEntry,
                                      isFavorite: _isFavorite(_selectedEntry),
                                      onToggleFavorite: _toggleFavorite,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  SizedBox(
                                    width: 380,
                                    child: ResultsPanel(
                                      results: _results,
                                      selectedEntry: _selectedEntry,
                                      query: _controller.text,
                                      onTap: _selectEntry,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: EntryDetailsCard(
                                      entry: _selectedEntry,
                                      isFavorite: _isFavorite(_selectedEntry),
                                      onToggleFavorite: _toggleFavorite,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onOpenFavorites,
    required this.onOpenHistory,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'English <> Bangla Dictionary',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF13293D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Developed by Pratik's Lab with 90k+ datasets",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? const Color(0xFFE3B684) : const Color(0xFF9B4D0C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 10,
          children: [
            IconButton.filledTonal(
              onPressed: onOpenFavorites,
              tooltip: 'Favourites',
              icon: const Icon(Icons.favorite_rounded),
            ),
            IconButton.filledTonal(
              onPressed: onOpenHistory,
              tooltip: 'History',
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton.filledTonal(
              onPressed: onToggleTheme,
              tooltip: 'Toggle theme',
              icon: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SearchBarCard extends StatelessWidget {
  const SearchBarCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202833) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF344150) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x15000000),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: 'Type English or Bangla words like book, car, বই, গাড়ি...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFFB8C3CF) : const Color(0xFF7A7066),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white : null,
          ),
          suffixIcon: controller.text.isEmpty
              ? (isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null)
              : IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white : null,
                  ),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.results,
    required this.selectedEntry,
    required this.query,
    required this.onTap,
  });

  final List<DictionaryEntry> results;
  final DictionaryEntry? selectedEntry;
  final String query;
  final ValueChanged<DictionaryEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202833) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF344150) : const Color(0xFFE7E1DA),
        ),
      ),
      child: results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  query.trim().isEmpty
                      ? 'Start typing in English or Bangla to search your local dictionary.'
                      : 'No result found for "$query".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF6E6A67),
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = results[index];
                final selected = selectedEntry?.id == entry.id;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onTap(entry),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark
                              ? const Color(0xFF2C3A4A)
                              : const Color(0xFFFBE7D6))
                          : (isDark
                              ? const Color(0xFF253140)
                              : const Color(0xFFF9F9F7)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFB7410E)
                            : (isDark
                                ? const Color(0xFF344150)
                                : const Color(0xFFE7E1DA)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF14213D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.bangla,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white : const Color(0xFF44413E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entry.pronunciation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '/${entry.pronunciation}/',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? const Color(0xFFD2DBE5)
                                  : const Color(0xFF7A7066),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (entry.partOfSpeech.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2E3947)
                                  : const Color(0xFFF1EEE9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              entry.partOfSpeech,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isDark ? Colors.white : const Color(0xFF7A6C5E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.title,
    required this.icon,
    required this.entries,
    required this.isDarkMode,
  });

  final String title;
  final IconData icon;
  final List<DictionaryEntry> entries;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final panelColor = isDarkMode ? const Color(0xFF202833) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF344150) : const Color(0xFFE7E1DA);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF14213D);

    return Theme(
      data: isDarkMode
          ? ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFDE7A22),
                brightness: Brightness.dark,
              ),
            )
          : ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFB7410E),
                brightness: Brightness.light,
              ),
            ),
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF151A22),
                      Color(0xFF111827),
                      Color(0xFF1B2430),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF6EEDF),
                      Color(0xFFF5F8FA),
                      Color(0xFFEFF3F6),
                    ],
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'No saved items yet.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDarkMode
                                  ? const Color(0xFFE8EDF3)
                                  : const Color(0xFF5E5A55),
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(entry),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: borderColor),
                          ),
                          tileColor: isDarkMode
                              ? const Color(0xFF253140)
                              : const Color(0xFFF9F9F7),
                          leading: CircleAvatar(
                            backgroundColor: isDarkMode
                                ? const Color(0x333F8CFF)
                                : const Color(0x1AB7410E),
                            child: Icon(
                              icon,
                              color: isDarkMode ? Colors.white : const Color(0xFF9B4D0C),
                            ),
                          ),
                          title: Text(
                            entry.word,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            entry.bangla,
                            style: TextStyle(
                              color: isDarkMode
                                  ? const Color(0xFFE8EDF3)
                                  : const Color(0xFF4C4741),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
