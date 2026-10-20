import 'package:flutter_test/flutter_test.dart';
import 'package:todo_task_planner/data/chinese_wisdom_quotes.dart';
import 'package:todo_task_planner/data/modern_celebrity_quotes.dart';
import 'package:todo_task_planner/models/daily_quote.dart';

void main() {
  test('quote remains stable throughout the same day', () {
    final morning = quoteForDate(DateTime(2026, 8, 13, 8));
    final evening = quoteForDate(DateTime(2026, 8, 13, 22));

    expect(identical(morning, evening), isTrue);
  });

  test('quote changes on the following day', () {
    final first = quoteForDate(DateTime(2026, 8, 13));
    final next = quoteForDate(DateTime(2026, 8, 14));

    expect(identical(first, next), isFalse);
  });

  test('Chinese and English quotations strictly alternate', () {
    final first = quoteForDate(DateTime(2026, 8, 13));
    final next = quoteForDate(DateTime(2026, 8, 14));
    final afterNext = quoteForDate(DateTime(2026, 8, 15));
    final chinese = RegExp(r'[\u3400-\u9fff]');

    expect(chinese.hasMatch(first.text), isNot(chinese.hasMatch(next.text)));
    expect(chinese.hasMatch(first.text), chinese.hasMatch(afterNext.text));
  });

  test('both language libraries contain 500 unique quotations', () {
    for (final quotes in [chineseWisdomQuotes, englishDailyQuotes]) {
      expect(quotes.length, greaterThan(500));
      expect(
        quotes.map((quote) => quote.text.toLowerCase()).toSet().length,
        quotes.length,
      );
    }
  });

  test('modern collection covers requested celebrity fields', () {
    final categories = modernCelebrityQuotes
        .map((quote) => quote.category)
        .toSet();
    expect(
      categories,
      containsAll([
        'Business',
        'Investor',
        'Athlete',
        'Movie star',
        'Artist',
        'Scientist',
      ]),
    );
    expect(
      modernCelebrityQuotes.every((quote) => quote.source != null),
      isTrue,
    );
  });
}
