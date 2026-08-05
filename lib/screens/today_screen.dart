import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';
import '../widgets/period_header.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_tile.dart';

/// Single-day task list, defaulting to today but steppable to any other day.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selected = dateOnly(DateTime.now());

  void _shiftDays(int days) {
    setState(() => _selected = _selected.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final today = dateOnly(DateTime.now());
    final isToday = isSameDay(_selected, today);
    final weekDays = weekContaining(_selected);
    final tasks = provider.tasksFor(_selected);
    final completed = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    final counts = '已完成 $completed／${tasks.length} 項';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          PeriodHeader(
            // On today the heading reads 今日, so the date moves to the
            // subtitle rather than being dropped.
            title: isToday ? '今日' : fullDateLabel(_selected),
            subtitle: isToday
                ? '${fullDateLabel(_selected)} · $counts'
                : counts,
            onPrevious: () => _shiftDays(-1),
            onNext: () => _shiftDays(1),
            previousTooltip: '前一天',
            nextTooltip: '後一天',
            onReset: isToday ? null : () => setState(() => _selected = today),
            resetLabel: '回到今日',
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 20),
          if (provider.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Panel(
              child: tasks.isEmpty
                  ? const EmptyTaskState()
                  : Column(
                      children: tasks
                          .map(
                            (task) => TaskTile(
                              task: task,
                              selectedDay: _selected,
                              weekDays: weekDays,
                              onToggle: () => provider.toggleTask(task),
                              onDaysChanged: (days) =>
                                  provider.updateTaskDays(task, days),
                              onEdit: () => showEditTaskSheet(
                                context,
                                task: task,
                                anchorDay: _selected,
                              ),
                              onDelete: () => confirmDeleteTask(context, task),
                            ),
                          )
                          .toList(),
                    ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
