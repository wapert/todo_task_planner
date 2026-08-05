import 'package:flutter/material.dart';

import '../models/planner_task.dart';
import '../utils/date_utils.dart';

class DayMenuAction {
  const DayMenuAction({required this.day, required this.selected});

  final DateTime day;
  final bool selected;
}

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.selectedDay,
    required this.weekDays,
    required this.onToggle,
    required this.onDaysChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTask task;
  final DateTime selectedDay;
  final List<DateTime> weekDays;
  final VoidCallback onToggle;
  final ValueChanged<List<DateTime>> onDaysChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      TaskPriority.low => const Color(0xFF64748B),
      TaskPriority.medium => const Color(0xFF0F766E),
      TaskPriority.high => const Color(0xFFB42318),
    };
    final selectedTime = task.timeForDay(selectedDay);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: task.isDone, onChanged: (_) => onToggle()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        MetaChip(
                          icon: Icons.source,
                          label: _sourceLabel(task.source),
                        ),
                        MetaChip(
                          icon: Icons.event_repeat,
                          label: assignedDaysLabel(task.days),
                        ),
                        MetaChip(
                          icon: Icons.flag,
                          label: task.priority.label,
                          color: priorityColor,
                        ),
                        if (selectedTime != null)
                          MetaChip(
                            icon: Icons.schedule,
                            label: selectedTime.format(context),
                          ),
                      ],
                    ),
                    if (task.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes,
                        style: const TextStyle(color: Color(0xFF586174)),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '編輯任務',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: '刪除任務',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
              PopupMenuButton<DayMenuAction>(
                tooltip: '指定日期',
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  final selectedDays = task.days.map(dateOnly).toSet();
                  final normalizedDay = dateOnly(action.day);
                  if (action.selected) {
                    selectedDays.add(normalizedDay);
                  } else if (selectedDays.length > 1) {
                    selectedDays.removeWhere(
                      (day) => isSameDay(day, normalizedDay),
                    );
                  }
                  onDaysChanged(selectedDays.toList()..sort(compareDates));
                },
                itemBuilder: (context) => weekDays.map((day) {
                  final selected = task.days.any(
                    (taskDay) => isSameDay(taskDay, day),
                  );
                  return CheckedPopupMenuItem(
                    value: DayMenuAction(day: day, selected: !selected),
                    checked: selected,
                    child: Text(dayLabel(day)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = const Color(0xFF475569),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class EmptyTaskState extends StatelessWidget {
  const EmptyTaskState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            '這天沒有任務',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text('新增任務，或從本週其他日子移過來。'),
        ],
      ),
    );
  }
}

String _sourceLabel(String source) {
  return source == 'Manual' ? '手動建立' : source;
}
