import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../localization/app_locale.dart';
import '../utils/date_utils.dart';

/// Classic two-column hour/minute wheel, instead of the Material clock dial.
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context,
  TimeOfDay initial,
) {
  var selected = initial;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return SizedBox(
        height: 320,
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('取消', 'Cancel')),
                ),
                Expanded(
                  child: Text(
                    context.tr('選擇時間', 'Select time'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(context.tr('確定', 'Done')),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                // 24-hour keeps it to exactly two columns; 12-hour would add
                // an AM/PM wheel.
                use24hFormat: true,
                initialDateTime: DateTime(
                  2000,
                  1,
                  1,
                  initial.hour,
                  initial.minute,
                ),
                onDateTimeChanged: (value) => selected = TimeOfDay(
                  hour: value.hour,
                  minute: value.minute,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Date + time picker for a task, with no week boundary.
///
/// Replaces the old week-of-chips selector, which could only ever assign a
/// task to one of the seven days currently on screen.
class TaskDaysField extends StatefulWidget {
  const TaskDaysField({
    super.key,
    required this.days,
    required this.timesByDay,
    required this.onAddDay,
    required this.onPickSpan,
    required this.isSpan,
    required this.onRemoveDay,
    required this.onChangeDay,
    required this.onTimeChanged,
  });

  /// Selected days, already sorted.
  final List<DateTime> days;
  final Map<DateTime, TimeOfDay> timesByDay;
  final VoidCallback onAddDay;

  /// Opens the start/end picker for a task that runs across a stretch.
  final VoidCallback onPickSpan;

  /// True when [days] is one continuous stretch rather than separate dates.
  final bool isSpan;
  final ValueChanged<DateTime> onRemoveDay;
  final ValueChanged<DateTime> onChangeDay;
  final void Function(DateTime day, TimeOfDay? time) onTimeChanged;

  @override
  State<TaskDaysField> createState() => _TaskDaysFieldState();
}

class _TaskDaysFieldState extends State<TaskDaysField> {
  /// Repeating a task can generate dozens of dates; showing them all would
  /// bury the rest of the form.
  static const _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final isSpanned = widget.isSpan && days.length > 1;
    final hidden = isSpanned
        ? 0
        : _expanded
        ? 0
        : (days.length - _collapsedCount).clamp(0, days.length);
    final visible = hidden == 0 ? days : days.take(_collapsedCount).toList();

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
              widget.isSpan && days.length > 1
                  ? context.tr(
                      '連續期間（${spanLabel(days)}，共 ${days.length} 天）',
                      'Range (${spanLabel(days)}, ${days.length} days)',
                    )
                  : days.length > 1
                  ? context.tr(
                      '日期與時間（${days.length} 天）',
                      'Dates & times (${days.length} days)',
                    )
                  : context.tr('日期與時間', 'Date & time'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            // A span is one task lasting a stretch, so it gets one row: seven
            // identical rows for a seven-day trip is the same repetition the
            // week view was showing, just inside the form. The time applies
            // to the first day, which is what a reminder hangs off.
            if (isSpanned) ...[
              _SpanRow(
                days: days,
                time: widget.timesByDay[days.first],
                onChangeRange: widget.onPickSpan,
                onTimeChanged: widget.onTimeChanged,
              ),
            ] else
            for (final day in visible)
              _DayRow(
                day: day,
                time: widget.timesByDay[day],
                // A task must keep at least one day, so the last row can't be
                // removed — but every row can still be changed to another
                // date, including the default one.
                onRemove: days.length > 1
                    ? () => widget.onRemoveDay(day)
                    : null,
                onChangeDay: () => widget.onChangeDay(day),
                onTimeChanged: widget.onTimeChanged,
              ),
            if (hidden > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(
                    context.tr('顯示其餘 $hidden 天', 'Show $hidden more days'),
                  ),
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onAddDay,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('新增日期', 'Add date')),
                ),
                TextButton.icon(
                  onPressed: widget.onPickSpan,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(context.tr('連續期間', 'Date range')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One row standing for a whole continuous span.
class _SpanRow extends StatelessWidget {
  const _SpanRow({
    required this.days,
    required this.time,
    required this.onChangeRange,
    required this.onTimeChanged,
  });

  final List<DateTime> days;
  final TimeOfDay? time;
  final VoidCallback onChangeRange;
  final void Function(DateTime day, TimeOfDay? time) onTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 18, color: Color(0xFF586174)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${fullDateLabel(days.first, english: context.isEnglish)}'
              ' – '
              '${fullDateLabel(days.last, english: context.isEnglish)}',
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: context.tr('變更期間', 'Change range'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onChangeRange,
          ),
          const Spacer(),
          InputChip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text(
              time == null
                  ? context.tr('設定時間', 'Set time')
                  : time!.format(context),
            ),
            onPressed: () async {
              final picked = await showWheelTimePicker(
                context,
                time ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) onTimeChanged(days.first, picked);
            },
            onDeleted: time == null
                ? null
                : () => onTimeChanged(days.first, null),
            deleteIcon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.time,
    required this.onRemove,
    required this.onChangeDay,
    required this.onTimeChanged,
  });

  final DateTime day;
  final TimeOfDay? time;
  final VoidCallback? onRemove;
  final VoidCallback onChangeDay;
  final void Function(DateTime day, TimeOfDay? time) onTimeChanged;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showWheelTimePicker(
      context,
      time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) onTimeChanged(day, picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.event, size: 18, color: Color(0xFF586174)),
          const SizedBox(width: 8),
          // Flexible rather than Expanded, so the pencil sits right next to
          // the date instead of being pushed to the far edge of the row.
          Flexible(
            child: Text(
              fullDateLabel(day, english: context.isEnglish),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          // Explicit pencil, so changing a date is a deliberate action rather
          // than something a stray tap on the row can trigger.
          IconButton(
            tooltip: context.tr('變更日期', 'Change date'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onChangeDay,
          ),
          const Spacer(),
          InputChip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text(
              time == null
                  ? context.tr('設定時間', 'Set time')
                  : time!.format(context),
            ),
            onPressed: () => _pickTime(context),
            onDeleted: time == null ? null : () => onTimeChanged(day, null),
            deleteIcon: const Icon(Icons.close, size: 16),
          ),
          IconButton(
            tooltip: context.tr('移除這一天', 'Remove this day'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
