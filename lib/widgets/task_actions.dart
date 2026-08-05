import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_task.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import 'add_task_sheet.dart';

/// Opens the edit form for [task], pre-filled with its current values.
Future<void> showEditTaskSheet(
  BuildContext context, {
  required PlannerTask task,
  required DateTime anchorDay,
}) async {
  final provider = context.read<TaskProvider>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return AddTaskSheet(
        initialDay: anchorDay,
        days: weekContaining(anchorDay),
        existingTask: task,
        onCreate: (title, notes, days, timesByDay, priority) {
          provider.editTask(
            task: task,
            title: title,
            notes: notes,
            days: days,
            timesByDay: timesByDay,
            priority: priority,
          );
        },
      );
    },
  );
}

/// Confirms and deletes [task].
Future<void> confirmDeleteTask(BuildContext context, PlannerTask task) async {
  final provider = context.read<TaskProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('刪除任務？'),
        content: Text('「${task.title}」將從清單中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await provider.deleteTask(task);
  }
}
