class DailyQuote {
  const DailyQuote({
    required this.text,
    required this.author,
    this.category,
    this.source,
  });

  final String text;
  final String author;
  final String? category;
  final String? source;
}
