import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';
import '../widgets/period_header.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_tile.dart';

/// Vertical week-at-a-glance planner: one section per day of the week, each
/// showing that day's tasks. Steppable to any other week.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  /// Any day inside the week currently on screen.
  late DateTime _anchor = dateOnly(DateTime.now());

  void _shiftWeeks(int weeks) {
    setState(() => _anchor = _anchor.add(Duration(days: 7 * weeks)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final today = dateOnly(DateTime.now());
    final weekDays = weekContaining(_anchor);
    final isThisWeek = weekDays.any((day) => isSameDay(day, today));

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 88,
        backgroundColor: provider.effectiveToolbarColor,
        foregroundColor: provider.toolbarForegroundColor,
        title: PeriodHeader(
          title: context.tr('週計畫', 'Weekly plan'),
          subtitle: isThisWeek
              ? context.tr(
                  '本週 · ${weekRangeLabel(weekDays)}',
                  'This week · ${weekRangeLabel(weekDays)}',
                )
              : weekRangeLabel(weekDays),
          onPrevious: () => _shiftWeeks(-1),
          onNext: () => _shiftWeeks(1),
          previousTooltip: context.tr('前一週', 'Previous week'),
          nextTooltip: context.tr('後一週', 'Next week'),
          onReset: isThisWeek ? null : () => setState(() => _anchor = today),
          resetLabel: context.tr('回到本週', 'Back to this week'),
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
          for (final day in weekDays) ...[
            _DaySection(day: day, today: today),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.today,
  });

  final DateTime day;
  final DateTime today;


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasksFor(day);
    final isToday = isSameDay(day, today);

    return Panel(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${day.month}/${day.day} ${weekdayShort(day, english: context.isEnglish)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (isToday) ...[const SizedBox(width: 8), const _TodayBadge()],
              const Spacer(),
              Text(
                context.tr('${tasks.length} 項', '${tasks.length} tasks'),
                style: const TextStyle(color: Color(0xFF586174)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                context.tr('尚無任務', 'No tasks'),
                style: const TextStyle(color: Color(0xFF9AA4B2)),
              ),
            )
          else
            Column(
              children: tasks
                  .map(
                    (task) => TaskTile(
                      task: task,
                      selectedDay: day,
                      onToggle: () => provider.toggleTask(task, day),
                      onDelete: () => confirmDeleteTask(context, task),
                      onEdit: () => showEditTaskSheet(
                        context,
                        task: task,
                        anchorDay: day,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: flaggedColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flaggedColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        context.tr('今日', 'Today'),
        style: const TextStyle(
          color: flaggedColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
