import 'package:flutter/material.dart';

import '../localization/app_locale.dart';

/// Lead times offered for a task reminder. null is the "off" option.
const List<int?> reminderLeadChoices = [null, 0, 5, 10, 30, 60, 1440];

String reminderLeadLabel(BuildContext context, int? minutes) {
  return switch (minutes) {
    null => context.tr('不提醒', 'No reminder'),
    0 => context.tr('準時提醒', 'At start time'),
    60 => context.tr('1 小時前', '1 hour before'),
    1440 => context.tr('1 天前', '1 day before'),
    final value => context.tr('$value 分鐘前', '$value minutes before'),
  };
}

/// Reminder picker for the task form.
///
/// A reminder is anchored to a task's clock time, so this also has to say
/// when it cannot fire — a task with no time set would otherwise look like
/// it had a working alarm.
class TaskReminderField extends StatelessWidget {
  const TaskReminderField({
    super.key,
    required this.minutesBefore,
    required this.onChanged,
    required this.hasAnyTime,
  });

  final int? minutesBefore;
  final ValueChanged<int?> onChanged;

  /// Whether any of the task's days carries a time.
  final bool hasAnyTime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: Color(0xFF586174),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('提醒', 'Reminder'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final choice in reminderLeadChoices)
                  ChoiceChip(
                    label: Text(reminderLeadLabel(context, choice)),
                    selected: minutesBefore == choice,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onChanged(choice),
                  ),
              ],
            ),
            if (minutesBefore != null && !hasAnyTime) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  '這個任務還沒有設定時間，請先設定時間才會收到提醒。',
                  'This task has no time set yet. Set a time to receive the reminder.',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB42318),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
