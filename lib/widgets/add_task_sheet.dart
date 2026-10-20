import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../models/planner_task.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';
import 'task_category_field.dart';
import 'task_days_field.dart';
import 'task_repeat_field.dart';
import 'task_reminder_field.dart';

typedef CreateTaskCallback =
    void Function(
      String title,
      String notes,
      List<DateTime> days,
      Map<DateTime, TimeOfDay> timesByDay,
      TaskPriority priority,
      String category,
      int? reminderMinutesBefore,
      bool isSpan,
    );

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({
    super.key,
    required this.initialDay,
    required this.onCreate,
    required this.categories,
    required this.onAddCategory,
    required this.onRemoveCategory,
    this.existingTask,
    this.onDelete,
  });

  /// Where the date picker opens, and the default day for a new task.
  final DateTime initialDay;
  final CreateTaskCallback onCreate;

  /// The user's saved categories.
  final List<String> categories;
  final ValueChanged<String> onAddCategory;
  final ValueChanged<String> onRemoveCategory;

  final PlannerTask? existingTask;

  /// Only meaningful when editing — deleting lives here rather than as a
  /// separate button on every task row.
  final VoidCallback? onDelete;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.existingTask?.title ?? '',
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.existingTask?.notes ?? '',
  );
  late final Set<DateTime> _taskDays = widget.existingTask != null
      ? widget.existingTask!.days.map(dateOnly).toSet()
      : {dateOnly(widget.initialDay)};
  late final Map<DateTime, TimeOfDay> _timesByDay = widget.existingTask != null
      ? Map<DateTime, TimeOfDay>.from(widget.existingTask!.timesByDay)
      : {};
  late TaskPriority _priority =
      widget.existingTask?.priority ?? TaskPriority.medium;
  late String _category = widget.existingTask?.category ?? '';

  /// Whether this task runs across one continuous stretch rather than a set
  /// of separate occasions.
  late bool _isSpan = widget.existingTask?.isSpan ?? false;
  late int? _reminderMinutesBefore = widget.existingTask?.reminderMinutesBefore;

  List<DateTime> get _sortedDays => _taskDays.toList()..sort(compareDates);

  /// Opens the platform date picker, focused on the day the sheet was opened
  /// from — so the current week is one tap away, but any date is reachable.
  Future<void> _addDay() async {
    final anchor = _sortedDays.isEmpty
        ? dateOnly(widget.initialDay)
        : _sortedDays.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(anchor.year - 2),
      lastDate: DateTime(anchor.year + 5),
      helpText: context.tr('選擇日期', 'Select date'),
    );
    if (picked == null) return;
    setState(() {
      _taskDays.add(dateOnly(picked));
      _isSpan = false;
    });
  }

  /// Picks a start and end date and fills in every day between, for a task
  /// that runs across a stretch rather than recurring.
  Future<void> _pickSpan() async {
    final anchor = _sortedDays.isEmpty
        ? dateOnly(widget.initialDay)
        : _sortedDays.first;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _isSpan && _sortedDays.length > 1
          ? DateTimeRange(start: _sortedDays.first, end: _sortedDays.last)
          : null,
      firstDate: DateTime(anchor.year - 2),
      lastDate: DateTime(anchor.year + 5),
      helpText: context.tr('選擇起訖日期', 'Select start and end'),
    );
    if (picked == null) return;
    final span = daysInRange(picked.start, picked.end);
    setState(() {
      // A span replaces the day list outright: mixing it with separately
      // chosen dates would make "continuous stretch" untrue.
      _taskDays
        ..clear()
        ..addAll(span);
      _repeatDays.clear();
      _timesByDay.removeWhere(
        (day, _) => !span.any((item) => isSameDay(item, day)),
      );
      _anchorDay = span.first;
      _isSpan = true;
    });
  }

  /// Re-dates an existing row, so even the day a new task defaults to can be
  /// moved without having to delete it first.
  Future<void> _changeDay(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 5),
      helpText: context.tr('選擇日期', 'Select date'),
    );
    if (picked == null) return;
    final replacement = dateOnly(picked);
    if (replacement == current) return;
    setState(() {
      _taskDays.remove(current);
      _taskDays.add(replacement);
      if (_repeatDays.remove(current)) _repeatDays.add(replacement);
      if (_anchorDay == current) _anchorDay = replacement;
      final time = _timesByDay.remove(current);
      if (time != null) _timesByDay[replacement] = time;
    });
  }

  /// Dates that came from the repeat picker rather than from the user picking
  /// them by hand — tracked so changing the selection can replace them instead
  /// of piling more dates on top.
  final Set<DateTime> _repeatDays = {};

  /// The task's own start day: where repeats are counted from, and the one day
  /// a repeat is never allowed to delete. Tracked explicitly because it can
  /// itself land on a repeated weekday, where it would be indistinguishable
  /// from a generated date.
  late DateTime _anchorDay = _sortedDays.first;

  /// Expands a weekday selection into concrete dates for the next [weeks]
  /// weeks. The model stores a plain list of days, so each occurrence stays
  /// independently editable and completable.
  ///
  /// Runs on every change to the picker, so it must be idempotent: unchecking
  /// a weekday has to take its dates back out again.
  void _applyRepeat(Set<int> weekdays, int weeks) {
    // Days the user chose by hand survive any change to the repeat selection.
    final manualDays = _taskDays.difference(_repeatDays)..add(_anchorDay);
    final base = _anchorDay;
    final weekStart = weekContaining(base).first;
    // Carry the base day's time onto every generated occurrence — a weekly
    // 19:30 session should stay at 19:30.
    final baseTime = _timesByDay[base];

    final generated = <DateTime>{};
    for (var week = 0; week < weeks; week++) {
      for (final weekday in weekdays) {
        final offset = week * 7 + (weekday % 7);
        final day = weekStart.add(Duration(days: offset));
        // Skip days earlier in the first week than the task's own start.
        if (day.isBefore(base)) continue;
        generated.add(day);
      }
    }

    setState(() {
      // Drop the previous generation, but never a day the user added or kept
      // by hand.
      for (final day in _repeatDays) {
        if (generated.contains(day) || manualDays.contains(day)) continue;
        _taskDays.remove(day);
        _timesByDay.remove(day);
      }
      _repeatDays
        ..clear()
        ..addAll(generated);
      for (final day in generated) {
        _taskDays.add(day);
        if (baseTime != null) _timesByDay.putIfAbsent(day, () => baseTime);
      }
    });
  }

  /// Asks for notification permission the moment a reminder is switched on,
  /// rather than at launch — the prompt then arrives with a reason the user
  /// can see.
  Future<void> _setReminder(int? minutes) async {
    setState(() => _reminderMinutesBefore = minutes);
    if (minutes == null) return;
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted || granted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '通知權限未開啟，提醒將不會響起。請至系統設定開啟通知。',
            'Notifications are off, so this reminder will not sound. Enable notifications in system settings.',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = context.watch<TaskProvider>().colorForPriority;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        // The modal already reserves space for its drag handle. Keep the form
        // heading close to it instead of adding another large top gap.
        top: 4,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existingTask == null
                ? context.tr('新增任務', 'Add task')
                : context.tr('編輯任務', 'Edit task'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TaskCategoryField(
            category: _category,
            categories: widget.categories,
            onAddCategory: widget.onAddCategory,
            onRemoveCategory: widget.onRemoveCategory,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr('任務標題', 'Task title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.tr('備註', 'Notes'),
              hintText: context.tr(
                '可貼上地圖、音樂、文件或圖片連結',
                'Paste a map, music, document, or image link',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TaskDaysField(
            days: _sortedDays,
            timesByDay: _timesByDay,
            onAddDay: _addDay,
            onPickSpan: _pickSpan,
            isSpan: _isSpan,
            onChangeDay: _changeDay,
            onRemoveDay: (day) {
              setState(() {
                final normalizedDay = dateOnly(day);
                if (_taskDays.length > 1) {
                  _taskDays.remove(normalizedDay);
                  _timesByDay.remove(normalizedDay);
                  _repeatDays.remove(normalizedDay);
                  _isSpan = false;
                  // The start day moved, so later repeats count from the new
                  // earliest day.
                  if (_anchorDay == normalizedDay) {
                    _anchorDay = _sortedDays.first;
                  }
                }
              });
            },
            onTimeChanged: (day, time) {
              setState(() {
                final normalizedDay = dateOnly(day);
                if (time == null) {
                  _timesByDay.remove(normalizedDay);
                } else {
                  _timesByDay[normalizedDay] = time;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TaskRepeatField(
            initialWeekday: _anchorDay.weekday,
            onApply: _applyRepeat,
          ),
          const SizedBox(height: 12),
          TaskReminderField(
            minutesBefore: _reminderMinutesBefore,
            hasAnyTime: _timesByDay.isNotEmpty,
            onChanged: _setReminder,
          ),
          const SizedBox(height: 12),
          SegmentedButton<TaskPriority>(
            // The selected segment takes its own priority's colour, and each
            // flag is tinted so the mapping is visible before selecting.
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: priorityColor(
                _priority,
              ).withValues(alpha: 0.18),
              selectedForegroundColor: priorityColor(_priority),
            ),
            // Keep the flags visible instead of swapping in a check mark.
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TaskPriority.low,
                icon: Icon(Icons.flag, color: priorityColor(TaskPriority.low)),
                label: Text(context.tr('低', 'Low')),
              ),
              ButtonSegment(
                value: TaskPriority.medium,
                icon: Icon(
                  Icons.flag,
                  color: priorityColor(TaskPriority.medium),
                ),
                label: Text(context.tr('中', 'Medium')),
              ),
              ButtonSegment(
                value: TaskPriority.high,
                icon: Icon(Icons.flag, color: priorityColor(TaskPriority.high)),
                label: Text(context.tr('高', 'High')),
              ),
            ],
            selected: {_priority},
            onSelectionChanged: (selection) {
              setState(() => _priority = selection.first);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _createTask,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: Icon(
                widget.existingTask == null ? Icons.add_task : Icons.check,
              ),
              label: Text(
                widget.existingTask == null
                    ? context.tr('新增任務', 'Add task')
                    : context.tr('儲存變更', 'Save changes'),
              ),
            ),
          ),
          if (widget.existingTask != null && widget.onDelete != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(context.tr('刪除任務', 'Delete task')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _createTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    widget.onCreate(
      title,
      _notesController.text.trim(),
      _sortedDays,
      _timesByDay,
      _priority,
      _category,
      _reminderMinutesBefore,
      _isSpan,
    );
    Navigator.of(context).pop();
  }
}
