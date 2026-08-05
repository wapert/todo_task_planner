import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  const PlanScreen({super.key});

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
    final today = dateOnly(DateTime.now());
    final weekDays = weekContaining(_anchor);
    final isThisWeek = weekDays.any((day) => isSameDay(day, today));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          PeriodHeader(
            title: '週計畫',
            subtitle: isThisWeek ? '本週' : weekRangeLabel(weekDays),
            onPrevious: () => _shiftWeeks(-1),
            onNext: () => _shiftWeeks(1),
            previousTooltip: '前一週',
            nextTooltip: '後一週',
            onReset: isThisWeek ? null : () => setState(() => _anchor = today),
            resetLabel: '回到本週',
          ),
          const SizedBox(height: 12),
          for (final day in weekDays) ...[
            _DaySection(day: day, today: today, weekDays: weekDays),
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
    required this.weekDays,
  });

  final DateTime day;
  final DateTime today;
  final List<DateTime> weekDays;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasksFor(day);
    final isToday = isSameDay(day, today);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isToday) ...[const _TodayBadge(), const SizedBox(width: 8)],
              Text(
                dayLabel(day),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${tasks.length} 項',
                style: const TextStyle(color: Color(0xFF586174)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('尚無任務', style: TextStyle(color: Color(0xFF9AA4B2))),
            )
          else
            Column(
              children: tasks
                  .map(
                    (task) => TaskTile(
                      task: task,
                      selectedDay: day,
                      weekDays: weekDays,
                      onToggle: () => provider.toggleTask(task),
                      onDaysChanged: (days) =>
                          provider.updateTaskDays(task, days),
                      onEdit: () => showEditTaskSheet(
                        context,
                        task: task,
                        anchorDay: day,
                      ),
                      onDelete: () => confirmDeleteTask(context, task),
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
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: flaggedColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
