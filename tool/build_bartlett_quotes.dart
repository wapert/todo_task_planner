import 'dart:io';

/// Converts the public-domain Project Gutenberg text of Bartlett's Familiar
/// Quotations (ebook 27889) into compact Dart data for offline use.
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'usage: dart run tool/build_bartlett_quotes.dart input.txt output.dart',
    );
    exitCode = 64;
    return;
  }

  final lines = File(arguments[0]).readAsLinesSync();
  final heading = RegExp(
    r"^([A-Z][A-Z .,'()’\-]+)\.(?:\[\d+(?:-\d+)?\])? (?:\d{3,4}|\d{2,4}\(\?\)|B\. C\.)",
  );
  final footnote = RegExp(r'\[\d+(?:-\d+)?\]');
  final quotes = <({String text, String author})>[];
  final seen = <String>{};
  String? author;
  final block = <String>[];

  void saveBlock() {
    if (author == null || block.isEmpty) {
      block.clear();
      return;
    }
    final isQuotation =
        block.first.startsWith('    ') &&
        !block.first.trimLeft().startsWith('FOOTNOTES:');
    if (!isQuotation) {
      block.clear();
      return;
    }
    var text = block
        .map((line) => line.trim())
        .join(' ')
        .replaceAll(footnote, '')
        .replaceAll('_', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length < 35 || text.length > 220 || text.contains('http')) {
      block.clear();
      return;
    }
    final key = text.toLowerCase();
    if (seen.add(key)) quotes.add((text: text, author: author!));
    block.clear();
  }

  for (final line in lines) {
    final match = heading.firstMatch(line);
    if (match != null) {
      saveBlock();
      author = _displayName(match.group(1)!);
      continue;
    }
    if (line.trim().isEmpty) {
      saveBlock();
    } else {
      block.add(line);
    }
  }
  saveBlock();

  // Round-robin by author so the result spans eras and countries instead of
  // being dominated by authors with the longest sections.
  final byAuthor = <String, List<({String text, String author})>>{};
  for (final quote in quotes) {
    byAuthor.putIfAbsent(quote.author, () => []).add(quote);
  }
  final selected = <({String text, String author})>[];
  for (var round = 0; selected.length < 650; round++) {
    var added = false;
    for (final authorQuotes in byAuthor.values) {
      if (round < authorQuotes.length) {
        selected.add(authorQuotes[round]);
        added = true;
        if (selected.length == 650) break;
      }
    }
    if (!added) break;
  }
  if (selected.length < 500) {
    stderr.writeln('Only ${selected.length} suitable quotations found.');
    exitCode = 1;
    return;
  }

  final output = StringBuffer()
    ..writeln('// Generated from Project Gutenberg ebook 27889.')
    ..writeln(
      '// Bartlett, Familiar Quotations, 9th edition (1905), public domain.',
    )
    ..writeln('// Do not edit manually; run tool/build_bartlett_quotes.dart.')
    ..writeln("import '../models/quote.dart';")
    ..writeln()
    ..writeln('const westernWisdomQuotes = <DailyQuote>[');
  for (final quote in selected) {
    output.writeln(
      "  DailyQuote(text: '${_escape(quote.text)}', author: '${_escape(quote.author)}'),",
    );
  }
  output.writeln('];');
  File(arguments[1]).writeAsStringSync(output.toString());
  stdout.writeln('Generated ${selected.length} quotations.');
}

String _displayName(String value) => value
    .toLowerCase()
    .split(' ')
    .map(
      (word) => word.isEmpty
          ? word
          : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
