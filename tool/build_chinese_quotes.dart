import 'dart:io';

const _sources = <String, String>{
  'lunyu.txt': '孔子《論語》',
  'mengzi.txt': '孟子《孟子》',
  'laozi.txt': '老子《道德經》',
  'mozi.txt': '墨子《墨子》',
  'huainanzi.txt': '劉安《淮南子》',
};

/// Extracts concise passages from public-domain Traditional Chinese Project
/// Gutenberg texts. Input filenames must match [_sources].
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'usage: dart run tool/build_chinese_quotes.dart input_dir output.dart',
    );
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments[0]);
  final bySource = <String, List<String>>{};
  final seen = <String>{};
  for (final entry in _sources.entries) {
    var text = File('${directory.path}/${entry.key}').readAsStringSync();
    final start = text.indexOf('*** START OF THE PROJECT GUTENBERG EBOOK');
    final end = text.indexOf('*** END OF THE PROJECT GUTENBERG EBOOK');
    if (start >= 0) text = text.substring(text.indexOf('\n', start) + 1);
    if (end >= 0) text = text.substring(0, text.indexOf('*** END OF'));
    if (entry.key == 'lunyu.txt') {
      text = text.substring(text.indexOf('學而第一'));
    }
    final body = text
        .replaceAll(RegExp(r'[\r\n\t ]+'), '')
        .replaceAll(RegExp(r'第[一二三四五六七八九十百]+[章篇]'), '');
    final passages = <String>[];
    final buffer = StringBuffer();
    for (final rune in body.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(character);
      if ('。！？'.contains(character)) {
        var passage = buffer.toString();
        buffer.clear();
        passage = passage
            .replaceFirst(RegExp(r'^.*?(?:子曰|曰|云)：「?'), '')
            .replaceFirst(RegExp(r'^\d+[\.、]?'), '')
            .replaceFirst(RegExp(r'^[^，。！？；]{1,12}[:：]'), '')
            .replaceAll(RegExp(r'^[「『（【“”‘’]+|[」』）】“”‘’]+$'), '')
            .trim();
        final chineseCount = RegExp(
          r'[\u3400-\u9fff]',
        ).allMatches(passage).length;
        if (chineseCount >= 8 &&
            chineseCount <= 90 &&
            !RegExp(r'[A-Za-z]').hasMatch(passage) &&
            !passage.contains('ProjectGutenberg') &&
            seen.add(passage)) {
          passages.add(passage);
        }
      }
    }
    bySource[entry.value] = passages;
  }

  final selected = <({String text, String author})>[];
  for (var round = 0; selected.length < 650; round++) {
    var added = false;
    for (final entry in bySource.entries) {
      if (round < entry.value.length) {
        selected.add((text: entry.value[round], author: entry.key));
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
    ..writeln(
      '// Generated from public-domain Project Gutenberg Chinese classics.',
    )
    ..writeln('// Do not edit manually; run tool/build_chinese_quotes.dart.')
    ..writeln("import '../models/quote.dart';")
    ..writeln()
    ..writeln('const chineseWisdomQuotes = <DailyQuote>[');
  for (final quote in selected) {
    output.writeln(
      "  DailyQuote(text: '${_escape(quote.text)}', author: '${_escape(quote.author)}'),",
    );
  }
  output.writeln('];');
  File(arguments[1]).writeAsStringSync(output.toString());
  stdout.writeln('Generated ${selected.length} Chinese quotations.');
}

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
