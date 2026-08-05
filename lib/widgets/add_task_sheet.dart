import 'package:flutter/material.dart';

import '../models/planner_task.dart';
import '../utils/date_utils.dart';
import 'day_selector.dart';

typedef CreateTaskCallback =
    void Function(
      String title,
      String notes,
      List<DateTime> days,
      Map<DateTime, TimeOfDay> timesByDay,
      TaskPriority priority,
    );

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({
    super.key,
    required this.initialDay,
    required this.days,
    required this.onCreate,
    this.existingTask,
  });

  final DateTime initialDay;
  final List<DateTime> days;
  final CreateTaskCallback onCreate;
  final PlannerTask? existingTask;

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

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
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
            widget.existingTask == null ? '新增任務' : '編輯任務',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '任務標題',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '備註',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DaySelector(
            days: widget.days,
            selectedDays: _taskDays,
            timesByDay: _timesByDay,
            onChanged: (day, selected) {
              setState(() {
                final normalizedDay = dateOnly(day);
                if (selected) {
                  _taskDays.add(normalizedDay);
                } else if (_taskDays.length > 1) {
                  _taskDays.remove(normalizedDay);
                  _timesByDay.remove(normalizedDay);
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
          SegmentedButton<TaskPriority>(
            segments: const [
              ButtonSegment(
                value: TaskPriority.low,
                icon: Icon(Icons.flag_outlined),
                label: Text('低'),
              ),
              ButtonSegment(
                value: TaskPriority.medium,
                icon: Icon(Icons.flag),
                label: Text('中'),
              ),
              ButtonSegment(
                value: TaskPriority.high,
                icon: Icon(Icons.priority_high),
                label: Text('高'),
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
              label: Text(widget.existingTask == null ? '新增任務' : '儲存變更'),
            ),
          ),
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
      _taskDays.toList()..sort(compareDates),
      _timesByDay,
      _priority,
    );
    Navigator.of(context).pop();
  }
}
