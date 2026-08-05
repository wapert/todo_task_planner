import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_task.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';

enum ProgressRange { week, month, custom }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;
  DateTimeRange? _custom;

  /// Start/end of whichever range is currently selected.
  (DateTime, DateTime) get _bounds {
    final today = dateOnly(DateTime.now());
    switch (_range) {
      case ProgressRange.week:
        final week = weekContaining(today);
        return (week.first, week.last);
      case ProgressRange.month:
        return monthBounds(today);
      case ProgressRange.custom:
        final custom = _custom;
        if (custom == null) {
          final week = weekContaining(today);
          return (week.first, week.last);
        }
        return (dateOnly(custom.start), dateOnly(custom.end));
    }
  }

  String get _rangeLabel {
    final (start, end) = _bounds;
    return switch (_range) {
      ProgressRange.week => '本週',
      ProgressRange.month => '本月',
      ProgressRange.custom => dateRangeLabel(start, end),
    };
  }

  /// Noun phrase for use inside a sentence.
  String get _rangeNoun => switch (_range) {
    ProgressRange.week => '本週',
    ProgressRange.month => '本月',
    ProgressRange.custom => '這段期間',
  };

  Future<void> _pickCustomRange() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 2),
      initialDateRange: _custom ?? DateTimeRange(start: today, end: today),
      helpText: '選擇日期範圍',
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _range = ProgressRange.custom;
    });
  }

  Future<void> _onRangeSelected(ProgressRange range) async {
    if (range == ProgressRange.custom) {
      // Selecting 自訂 has no meaning until a range is chosen, so go straight
      // to the picker and leave the old selection alone if it's cancelled.
      await _pickCustomRange();
      return;
    }
    setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final (start, end) = _bounds;
    final days = daysInRange(start, end);

    final rangeTasks = <PlannerTask>{};
    for (final day in days) {
      rangeTasks.addAll(provider.tasksFor(day));
    }
    final total = rangeTasks.length;
    final done = rangeTasks.where((task) => task.isDone).length;
    final completionRate = total == 0 ? 0.0 : done / total;

    final openByPriority = {
      for (final priority in TaskPriority.values)
        priority: rangeTasks
            .where((task) => !task.isDone && task.priority == priority)
            .length,
    };

    final bars = _buildBars(provider, days);
    final maxBar = bars.fold(
      0,
      (max, bar) => bar.value > max ? bar.value : max,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text(
            _rangeLabel,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _RangeSelector(
            range: _range,
            onSelected: _onRangeSelected,
            onEditCustom: _pickCustomRange,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: '總任務數', value: '$total'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(label: '已完成', value: '$done'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '完成率',
                  value: '${(completionRate * 100).round()}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: '待辦任務（依優先度）',
            icon: Icons.pie_chart_outline,
            child: total == done
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('$_rangeNoun沒有待辦任務了，太棒了！'),
                  )
                : SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 32,
                              sections: [
                                for (final entry in openByPriority.entries)
                                  if (entry.value > 0)
                                    PieChartSectionData(
                                      value: entry.value.toDouble(),
                                      color: _priorityColor(entry.key),
                                      title: '${entry.value}',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final priority in TaskPriority.values)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _priorityColor(priority),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(priority.label),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Panel(
            title: '完成數',
            icon: Icons.bar_chart,
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bar in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${bar.value}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: maxBar == 0
                                  ? 4
                                  : 70 * (bar.value / maxBar),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bar.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Buckets the range so the chart stays readable: a month of daily bars
  /// would be too thin to label, so longer spans roll up into weeks/months.
  List<_Bar> _buildBars(TaskProvider provider, List<DateTime> days) {
    int completedOn(DateTime day) =>
        provider.tasksFor(day).where((task) => task.isDone).length;

    if (days.length <= 10) {
      return [
        for (final day in days)
          _Bar(
            label: days.length <= 7
                ? weekdayShort(day)
                : '${day.month}/${day.day}',
            value: completedOn(day),
          ),
      ];
    }

    if (days.length <= 70) {
      final byWeek = <DateTime, int>{};
      for (final day in days) {
        final weekStart = weekContaining(day).first;
        byWeek[weekStart] = (byWeek[weekStart] ?? 0) + completedOn(day);
      }
      final starts = byWeek.keys.toList()..sort(compareDates);
      return [
        for (final start in starts)
          _Bar(label: '${start.month}/${start.day}', value: byWeek[start]!),
      ];
    }

    final byMonth = <DateTime, int>{};
    for (final day in days) {
      final monthStart = DateTime(day.year, day.month, 1);
      byMonth[monthStart] = (byMonth[monthStart] ?? 0) + completedOn(day);
    }
    final starts = byMonth.keys.toList()..sort(compareDates);
    return [
      for (final start in starts)
        _Bar(label: '${start.month}月', value: byMonth[start]!),
    ];
  }

  Color _priorityColor(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => const Color(0xFF64748B),
      TaskPriority.medium => const Color(0xFF0F766E),
      TaskPriority.high => const Color(0xFFB42318),
    };
  }
}

class _Bar {
  const _Bar({required this.label, required this.value});

  final String label;
  final int value;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.range,
    required this.onSelected,
    required this.onEditCustom,
  });

  final ProgressRange range;
  final ValueChanged<ProgressRange> onSelected;
  final VoidCallback onEditCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ProgressRange>(
            segments: const [
              ButtonSegment(value: ProgressRange.week, label: Text('本週')),
              ButtonSegment(value: ProgressRange.month, label: Text('本月')),
              ButtonSegment(value: ProgressRange.custom, label: Text('自訂')),
            ],
            selected: {range},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onSelected(selection.first),
          ),
        ),
        // Re-selecting a segment doesn't fire a change, so custom ranges need
        // their own way back into the picker.
        if (range == ProgressRange.custom)
          IconButton(
            tooltip: '變更日期範圍',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: onEditCustom,
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF586174))),
        ],
      ),
    );
  }
}
