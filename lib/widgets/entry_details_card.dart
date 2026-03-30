import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dictionary_entry.dart';

class EntryDetailsCard extends StatelessWidget {
  const EntryDetailsCard({
    super.key,
    required this.entry,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final DictionaryEntry? entry;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (entry == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202833) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF344150) : const Color(0xFFE7E1DA),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Search in English or Bangla to see both meanings.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF5E5A55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202833) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF344150) : const Color(0xFFE7E1DA),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x12000000),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry!.word,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF102542),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _copyEntry(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (entry!.bangla.isNotEmpty)
              Text(
                entry!.bangla,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF5A2D0C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            if (entry!.pronunciation.isNotEmpty)
              Text(
                '/${entry!.pronunciation}/',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? const Color(0xFFD2DBE5) : const Color(0xFF6D7D8C),
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 20),
            _InfoBlock(label: 'English Word', value: entry!.word),
            const SizedBox(height: 16),
            _InfoBlock(label: 'Bangla Meaning', value: entry!.bangla),
            if (entry!.partOfSpeech.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoBlock(label: 'Part of Speech', value: entry!.partOfSpeech),
            ],
            if (entry!.example.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoBlock(label: 'Example', value: entry!.example),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyEntry(BuildContext context) async {
    final text = [
      'English: ${entry!.word}',
      'Bangla: ${entry!.bangla}',
      if (entry!.pronunciation.isNotEmpty)
        'Pronunciation: ${entry!.pronunciation}',
      if (entry!.partOfSpeech.isNotEmpty)
        'Part of speech: ${entry!.partOfSpeech}',
      if (entry!.example.isNotEmpty) 'Example: ${entry!.example}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isDark ? const Color(0xFFD2DBE5) : const Color(0xFF8D8072),
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDark ? Colors.white : const Color(0xFF1C1B1A),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
