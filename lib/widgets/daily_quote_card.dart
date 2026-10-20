import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_quote.dart';
import '../providers/task_provider.dart';

class DailyQuoteCard extends StatelessWidget {
  const DailyQuoteCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final quote = quoteForDate(date);
    final provider = context.watch<TaskProvider>();
    final accent = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: '每日一句，${quote.text}，${quote.author}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: provider.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote_rounded, color: accent, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.text,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— ${quote.author}${quote.category == null ? '' : ' · ${quote.category}'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
