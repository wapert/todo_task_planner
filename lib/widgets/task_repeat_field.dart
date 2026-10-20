import 'package:flutter/material.dart';

import '../localization/app_locale.dart';

/// Weekday picker + duration, for scheduling a task on the same weekdays over
/// the next several weeks.
///
/// This generates concrete dates rather than storing a recurrence rule — the
/// task model is a plain list of days, so every occurrence stays individually
/// editable and completable.
class TaskRepeatField extends StatefulWidget {
  const TaskRepeatField({
    super.key,
    required this.initialWeekday,
    required this.onApply,
  });

  /// [weekdays] uses DateTime's convention: 1 = Monday … 7 = Sunday.
  final int initialWeekday;
  final void Function(Set<int> weekdays, int weeks) onApply;

  @override
  State<TaskRepeatField> createState() => _TaskRepeatFieldState();
}

class _TaskRepeatFieldState extends State<TaskRepeatField> {
  /// Sunday-first, matching the rest of the app's week.
  static const _weekdayOrder = [7, 1, 2, 3, 4, 5, 6];
  static const _labels = {
    7: '日',
    1: '一',
    2: '二',
    3: '三',
    4: '四',
    5: '五',
    6: '六',
  };
  static const _englishLabels = {
    7: 'Sun',
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };

  final Set<int> _weekdays = {};
  int _weeks = 4;
  bool _enabled = false;

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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                context.tr('每週重複', 'Repeat weekly'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: _enabled,
              onChanged: (enabled) {
                setState(() {
                  _enabled = enabled;
                  _weekdays.clear();
                  if (enabled) _weekdays.add(widget.initialWeekday);
                });
                widget.onApply(_weekdays, _weeks);
              },
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final weekday in _weekdayOrder)
                    FilterChip(
                      label: Text(
                        (context.isEnglish
                            ? _englishLabels
                            : _labels)[weekday]!,
                      ),
                      selected: _weekdays.contains(weekday),
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weekdays.add(weekday);
                          } else {
                            _weekdays.remove(weekday);
                          }
                        });
                        widget.onApply(_weekdays, _weeks);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 4,
                    label: Text(context.tr('4 週', '4 weeks')),
                  ),
                  ButtonSegment(
                    value: 8,
                    label: Text(context.tr('8 週', '8 weeks')),
                  ),
                  ButtonSegment(
                    value: 12,
                    label: Text(context.tr('12 週', '12 weeks')),
                  ),
                ],
                selected: {_weeks},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (selection) {
                  setState(() => _weeks = selection.first);
                  widget.onApply(_weekdays, _weeks);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _weekdays.isEmpty
                    ? context.tr('請至少選擇一個星期', 'Select at least one weekday')
                    : context.tr(
                        '已加入未來 $_weeks 週的日期',
                        'Dates added for the next $_weeks weeks',
                      ),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9AA4B2)),
              ),
            ] else
              Text(
                context.tr(
                  '開啟後會自動選擇目前日期的星期',
                  'Turning this on selects the current weekday automatically',
                ),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9AA4B2)),
              ),
          ],
        ),
      ),
    );
  }
}
