import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/daily_quote_card.dart';
import '../widgets/panel.dart';
import '../widgets/period_header.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_tile.dart';

/// Single-day task list, defaulting to today but steppable to any other day.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

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
    final tasks = provider.tasksFor(_selected);
    final completed = tasks.where((task) => task.isDoneOn(_selected)).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    final counts = context.tr(
      '已完成 $completed／${tasks.length} 項',
      '$completed of ${tasks.length} completed',
    );

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 88,
        backgroundColor: provider.effectiveToolbarColor,
        foregroundColor: provider.toolbarForegroundColor,
        title: PeriodHeader(
          title: isToday
              ? context.tr('今日', 'Today')
              : compactDateLabel(_selected, english: context.isEnglish),
          subtitle: isToday
              ? '${compactDateLabel(_selected, english: context.isEnglish)} · $counts'
              : counts,
          onPrevious: () => _shiftDays(-1),
          onNext: () => _shiftDays(1),
          previousTooltip: context.tr('前一天', 'Previous day'),
          nextTooltip: context.tr('後一天', 'Next day'),
          onReset: isToday ? null : () => setState(() => _selected = today),
          resetLabel: context.tr('回到今日', 'Back to today'),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('設定', 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
        children: [
          DailyQuoteCard(date: _selected),
          const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: tasks.isEmpty
                  ? const EmptyTaskState()
                  : Column(
                      children: tasks
                          .map(
                            (task) => TaskTile(
                              task: task,
                              selectedDay: _selected,
                              onToggle: () => provider.toggleTask(task, _selected),
                              onDelete: () => confirmDeleteTask(context, task),
                              onEdit: () => showEditTaskSheet(
                                context,
                                task: task,
                                anchorDay: _selected,
                              ),
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
