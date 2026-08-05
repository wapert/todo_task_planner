import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

/// Horizontal strip of day cards showing each day's task count, with the
/// current day circled in red and the selected day outlined.
class WeekDayStrip extends StatelessWidget {
  const WeekDayStrip({
    super.key,
    required this.days,
    required this.today,
    required this.selectedDay,
    required this.compact,
    required this.taskCountFor,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime selectedDay;
  final bool compact;
  final int Function(DateTime day) taskCountFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final cardWidth = compact ? 72.0 : 88.0;
    final cardHeight = compact ? 70.0 : 82.0;
    final weekdayFontSize = compact ? 11.0 : 12.0;
    final dateFontSize = compact ? 10.0 : 11.0;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = isSameDay(day, selectedDay);
          final isToday = isSameDay(day, today);
          final count = taskCountFor(day);
          return SizedBox(
            width: cardWidth,
            child: InkWell(
              key: ValueKey('weekday-$index'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(day),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: weekdayCardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? flaggedColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 4 : 5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _WeekdayCheckMark(selected: selected),
                          const SizedBox(width: 4),
                          Text(
                            weekdayShort(day),
                            style: TextStyle(
                              fontSize: weekdayFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: isToday
                            ? const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              )
                            : null,
                        child: Text(
                          '${day.month}/${day.day}',
                          style: TextStyle(
                            fontSize: dateFontSize,
                            color: isToday ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$count tasks',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekdayCheckMark extends StatelessWidget {
  const _WeekdayCheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? flaggedColor : const Color(0xFFCBD5E1),
        ),
      ),
      child: SizedBox(
        width: 12,
        height: 12,
        child: selected
            ? const Icon(Icons.check, size: 8, color: flaggedColor)
            : null,
      ),
    );
  }
}
