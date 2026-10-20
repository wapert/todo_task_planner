import '../data/chinese_wisdom_quotes.dart';
import '../data/modern_celebrity_quotes.dart';
import '../data/western_wisdom_quotes.dart';
import 'quote.dart';

/// Alternates language every calendar day. Each language advances only on its
/// own day, so every quotation in that language is shown before it repeats.
DailyQuote quoteForDate(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final dayNumber = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  final pool = dayNumber.isEven ? chineseWisdomQuotes : englishDailyQuotes;
  return pool[(dayNumber ~/ 2) % pool.length];
}

const englishDailyQuotes = <DailyQuote>[
  ...westernWisdomQuotes,
  ...modernCelebrityQuotes,
];
