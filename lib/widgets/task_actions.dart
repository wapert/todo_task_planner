import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_task.dart';
import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import 'add_task_sheet.dart';

/// Opens the edit form for [task], pre-filled with its current values.
Future<void> showEditTaskSheet(
  BuildContext context, {
  required PlannerTask task,
  required DateTime anchorDay,
}) async {
  final provider = context.read<TaskProvider>();
  // Captured before the sheet closes: the confirm dialog is opened from the
  // page underneath, since the sheet's own context is gone by then.
  final pageContext = context;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      // Match the create form: retain a clear dismiss area above the sheet.
      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
    ),
    builder: (context) {
      return ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: AddTaskSheet(
          initialDay: anchorDay,
          categories: provider.categories,
          onAddCategory: provider.addCategory,
          onRemoveCategory: provider.removeCategory,
          existingTask: task,
          onCreate:
              (
                title,
                notes,
                days,
                timesByDay,
                priority,
                category,
                reminderMinutesBefore,
                isSpan,
              ) {
                provider.editTask(
                  task: task,
                  title: title,
                  notes: notes,
                  days: days,
                  timesByDay: timesByDay,
                  priority: priority,
                  category: category,
                  reminderMinutesBefore: reminderMinutesBefore,
                    isSpan: isSpan,
                );
              },
          onDelete: () {
            if (pageContext.mounted) confirmDeleteTask(pageContext, task);
          },
        ),
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
        title: Text(context.tr('刪除任務？', 'Delete task?')),
        content: Text(
          context.tr(
            '「${task.title}」將從清單中移除。',
            '“${task.title}” will be removed from the list.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('刪除', 'Delete')),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await provider.deleteTask(task);
  }
}
