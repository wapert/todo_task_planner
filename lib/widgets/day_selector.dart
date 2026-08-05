import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

/// Compact chip-based picker for choosing which days (of a given week) a
/// task applies to, plus a per-selected-day time chip.
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.days,
    required this.selectedDays,
    required this.timesByDay,
    required this.onChanged,
    required this.onTimeChanged,
  });

  final List<DateTime> days;
  final Set<DateTime> selectedDays;
  final Map<DateTime, TimeOfDay> timesByDay;
  final void Function(DateTime day, bool selected) onChanged;
  final void Function(DateTime day, TimeOfDay? time) onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final selectedInOrder = days
        .map(dateOnly)
        .where(
          (day) =>
              selectedDays.any((selectedDay) => isSameDay(selectedDay, day)),
        )
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本週日期',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days.map((day) {
                final normalizedDay = dateOnly(day);
                final selected = selectedDays.any(
                  (selectedDay) => isSameDay(selectedDay, normalizedDay),
                );
                return ChoiceChip(
                  label: Text(dayLabel(day)),
                  selected: selected,
                  onSelected: (checked) => onChanged(normalizedDay, checked),
                  selectedColor: flaggedColor,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                  side: BorderSide(
                    color: selected ? flaggedColor : const Color(0xFFCBD5E1),
                  ),
                );
              }).toList(),
            ),
            if (selectedInOrder.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedInOrder.map((day) {
                  return DayTimeChip(
                    day: day,
                    dayLabel: dayLabel(day),
                    time: timesByDay[day],
                    onChanged: onTimeChanged,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DayTimeChip extends StatelessWidget {
  const DayTimeChip({
    super.key,
    required this.day,
    required this.dayLabel,
    required this.time,
    required this.onChanged,
  });

  final DateTime day;
  final String dayLabel;
  final TimeOfDay? time;
  final void Function(DateTime day, TimeOfDay? time) onChanged;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.schedule, size: 16),
      label: Text('$dayLabel：${time == null ? '設定時間' : time!.format(context)}'),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) {
          onChanged(day, picked);
        }
      },
      onDeleted: time == null ? null : () => onChanged(day, null),
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }
}
