import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_task.dart';
import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';
import '../widgets/period_header.dart';
import '../widgets/task_actions.dart';
import '../widgets/linkified_text.dart';
import '../widgets/task_tile.dart';

enum ProgressRange { week, month, custom }

/// Which slice of the range's tasks the list at the bottom shows.
enum TaskFilter { open, done }

String _englishMonth(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

class _CompactRangeDialog extends StatefulWidget {
  const _CompactRangeDialog({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CompactRangeDialog> createState() => _CompactRangeDialogState();
}

class _CompactRangeDialogState extends State<_CompactRangeDialog> {
  late DateTime _start = dateOnly(widget.initialRange.start);
  late DateTime _end = dateOnly(widget.initialRange.end);

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: context.tr('選擇開始日期', 'Select start date'),
    );
    if (picked == null) return;
    setState(() {
      _start = dateOnly(picked);
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: widget.lastDate,
      helpText: context.tr('選擇結束日期', 'Select end date'),
    );
    if (picked == null) return;
    setState(() => _end = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('自訂日期範圍', 'Custom date range')),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateField(
              label: context.tr('開始日期', 'Start date'),
              date: _start,
              onPressed: _pickStart,
            ),
            const SizedBox(height: 12),
            _DateField(
              label: context.tr('結束日期', 'End date'),
              date: _end,
              onPressed: _pickEnd,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('取消', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DateTimeRange(start: _start, end: _end)),
          child: Text(context.tr('確定', 'Done')),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: context.tr('選擇$label', 'Select $label'),
            onPressed: onPressed,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
        child: Text(compactDateLabel(date, english: context.isEnglish)),
      ),
    );
  }
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressRange _range = ProgressRange.week;
  TaskFilter _filter = TaskFilter.open;
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
      ProgressRange.week => context.tr('本週', 'This week'),
      ProgressRange.month => context.tr('本月', 'This month'),
      ProgressRange.custom => dateRangeLabel(start, end),
    };
  }

  /// Noun phrase for use inside a sentence.
  String get _rangeNoun => switch (_range) {
    ProgressRange.week => context.tr('本週', 'This week'),
    ProgressRange.month => context.tr('本月', 'This month'),
    ProgressRange.custom => context.tr('這段期間', 'This period'),
  };

  Future<void> _pickCustomRange() async {
    final today = dateOnly(DateTime.now());
    final initial = _custom ?? DateTimeRange(start: today, end: today);
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _CompactRangeDialog(
        initialRange: initial,
        firstDate: DateTime(today.year - 2),
        lastDate: DateTime(today.year + 2),
      ),
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

  // --- Drill-downs from the stat tiles --------------------------------------

  /// Priority breakdown for either the open or the completed tasks. Tapping a
  /// slice (or a legend row) drills into that priority's tasks.
  void _showPriorityPie({
    required String title,
    required List<PlannerTask> tasks,
    required String emptyText,
  }) {
    final provider = context.read<TaskProvider>();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ChangeNotifierProvider<TaskProvider>.value(
        value: provider,
        child: _PriorityPieSheet(
          title: title,
          rangeLabel: _rangeLabel,
          tasks: tasks,
          emptyText: emptyText,
        ),
      ),
    );
  }

  /// Completion *rate* per bucket — not raw counts, so a light day with 1/1
  /// done reads as 100% rather than looking worse than a busy day.
  void _showRateTrend(List<_RateBar> bars) {
    _showSheet(
      icon: Icons.show_chart,
      title: context.tr('完成率趨勢', 'Completion trend'),
      child: SizedBox(
        height: 150,
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
                        bar.total == 0 ? '–' : '${(bar.rate * 100).round()}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        // Always leave a sliver visible so an empty day still
                        // reads as a bucket rather than a gap.
                        height: bar.total == 0 ? 3 : 4 + 84 * bar.rate,
                        decoration: BoxDecoration(
                          color: bar.total == 0
                              ? const Color(0xFFD9DEE7)
                              : const Color(0xFFFF9500),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bar.done}/${bar.total}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
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
    );
  }

  void _showSheet({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _rangeLabel,
                    style: const TextStyle(color: Color(0xFF586174)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        );
      },
    );
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
    final openTasks = _sorted(rangeTasks.where((task) => !task.isDone));
    final doneTasks = _sorted(rangeTasks.where((task) => task.isDone));
    final completionRate = total == 0 ? 0.0 : doneTasks.length / total;
    final listed = _filter == TaskFilter.open ? openTasks : doneTasks;

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 88,
        backgroundColor: provider.effectiveToolbarColor,
        foregroundColor: provider.toolbarForegroundColor,
        title: PageHeaderText(
          title: context.tr('進度', 'Progress'),
          subtitle: '$_rangeLabel · ${dateRangeLabel(start, end)}',
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
          _RangeSelector(
            range: _range,
            onSelected: _onRangeSelected,
            onEditCustom: _pickCustomRange,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: context.tr('待辦任務', 'To do'),
                  value: '${openTasks.length}',
                  icon: Icons.pie_chart_outline,
                  onTap: () => _showPriorityPie(
                    title: context.tr('待辦任務（依優先度）', 'To do by priority'),
                    tasks: openTasks,
                    emptyText: context.tr(
                      '$_rangeNoun沒有待辦任務了，太棒了！',
                      'No tasks to do for $_rangeNoun. Great job!',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: context.tr('完成任務', 'Completed'),
                  value: '${doneTasks.length}',
                  icon: Icons.pie_chart_outline,
                  onTap: () => _showPriorityPie(
                    title: context.tr('完成任務（依優先度）', 'Completed by priority'),
                    tasks: doneTasks,
                    emptyText: context.tr(
                      '$_rangeNoun還沒有完成的任務。',
                      'No completed tasks for $_rangeNoun yet.',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: context.tr('完成率', 'Completion'),
                  value: '${(completionRate * 100).round()}%',
                  icon: Icons.show_chart,
                  onTap: () => _showRateTrend(_buildRateBars(provider, days)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            title: context.tr('任務清單', 'Task list'),
            icon: Icons.checklist,
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<TaskFilter>(
                  segments: [
                    ButtonSegment(
                      value: TaskFilter.open,
                      label: Text(
                        context.tr(
                          '待辦任務 ${openTasks.length}',
                          'To do ${openTasks.length}',
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: TaskFilter.done,
                      label: Text(
                        context.tr(
                          '完成任務 ${doneTasks.length}',
                          'Completed ${doneTasks.length}',
                        ),
                      ),
                    ),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.first),
                ),
                const SizedBox(height: 14),
                if (listed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _filter == TaskFilter.open
                          ? context.tr(
                              '$_rangeNoun沒有待辦任務了，太棒了！',
                              'No tasks to do for $_rangeNoun. Great job!',
                            )
                          : context.tr(
                              '$_rangeNoun還沒有完成的任務。',
                              'No completed tasks for $_rangeNoun yet.',
                            ),
                      style: const TextStyle(color: Color(0xFF9AA4B2)),
                    ),
                  )
                else
                  for (var index = 0; index < listed.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: 12,
                        thickness: 1,
                        color: Color(0xFFCBD5E1),
                      ),
                    Builder(
                      builder: (context) {
                        // Anchor each tile on the task's own first day inside
                        // the range, so its time chip and day menu make sense.
                        final task = listed[index];
                        final anchor = _anchorDay(task, start, end);
                        return TaskTile(
                          task: task,
                          selectedDay: anchor,
                          onToggle: () => provider.toggleTask(task, anchor),
                          onDelete: () => confirmDeleteTask(context, task),
                          onEdit: () => showEditTaskSheet(
                            context,
                            task: task,
                            anchorDay: anchor,
                          ),
                        );
                      },
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Earliest day of [task] that falls inside the range, falling back to its
  /// first day (a task can be assigned days outside the current range).
  DateTime _anchorDay(PlannerTask task, DateTime start, DateTime end) {
    final inRange =
        task.days
            .where(
              (day) =>
                  !dateOnly(day).isBefore(start) && !dateOnly(day).isAfter(end),
            )
            .toList()
          ..sort(compareDates);
    if (inRange.isNotEmpty) return dateOnly(inRange.first);
    final all = task.days.map(dateOnly).toList()..sort(compareDates);
    return all.isEmpty ? start : all.first;
  }

  /// Highest priority first, then earliest day, then title — so the list has a
  /// stable order instead of the set's arbitrary one.
  List<PlannerTask> _sorted(Iterable<PlannerTask> tasks) {
    DateTime firstDay(PlannerTask task) {
      final days = task.days.map(dateOnly).toList()..sort(compareDates);
      return days.isEmpty ? DateTime(9999) : days.first;
    }

    return tasks.toList()..sort((a, b) {
      final byPriority = b.priority.index.compareTo(a.priority.index);
      if (byPriority != 0) return byPriority;
      final byDay = compareDates(firstDay(a), firstDay(b));
      if (byDay != 0) return byDay;
      return a.title.compareTo(b.title);
    });
  }

  /// Completion rate per bucket. Buckets the range so the chart stays
  /// readable: a month of daily bars would be too thin to label, so longer
  /// spans roll up into weeks/months.
  List<_RateBar> _buildRateBars(TaskProvider provider, List<DateTime> days) {
    ({int done, int total}) countsOn(DateTime day) {
      final tasks = provider.tasksFor(day);
      return (
        done: tasks.where((task) => task.isDone).length,
        total: tasks.length,
      );
    }

    _RateBar bar(String label, int done, int total) =>
        _RateBar(label: label, done: done, total: total);

    if (days.length <= 10) {
      return [
        for (final day in days)
          () {
            final c = countsOn(day);
            return bar(
              days.length <= 7
                  ? weekdayShort(day, english: context.isEnglish)
                  : '${day.month}/${day.day}',
              c.done,
              c.total,
            );
          }(),
      ];
    }

    if (days.length <= 70) {
      final byWeek = <DateTime, (int, int)>{};
      for (final day in days) {
        final weekStart = weekContaining(day).first;
        final c = countsOn(day);
        final prev = byWeek[weekStart] ?? (0, 0);
        byWeek[weekStart] = (prev.$1 + c.done, prev.$2 + c.total);
      }
      final starts = byWeek.keys.toList()..sort(compareDates);
      return [
        for (final start in starts)
          bar(
            '${start.month}/${start.day}',
            byWeek[start]!.$1,
            byWeek[start]!.$2,
          ),
      ];
    }

    final byMonth = <DateTime, (int, int)>{};
    for (final day in days) {
      final monthStart = DateTime(day.year, day.month, 1);
      final c = countsOn(day);
      final prev = byMonth[monthStart] ?? (0, 0);
      byMonth[monthStart] = (prev.$1 + c.done, prev.$2 + c.total);
    }
    final starts = byMonth.keys.toList()..sort(compareDates);
    return [
      for (final start in starts)
        bar(
          context.tr('${start.month}月', _englishMonth(start.month)),
          byMonth[start]!.$1,
          byMonth[start]!.$2,
        ),
    ];
  }
}

/// Priority pie with a drill-down: tapping a slice or a legend row lists that
/// priority's tasks underneath.
class _PriorityPieSheet extends StatefulWidget {
  const _PriorityPieSheet({
    required this.title,
    required this.rangeLabel,
    required this.tasks,
    required this.emptyText,
  });

  final String title;
  final String rangeLabel;
  final List<PlannerTask> tasks;
  final String emptyText;

  @override
  State<_PriorityPieSheet> createState() => _PriorityPieSheetState();
}

class _PriorityPieSheetState extends State<_PriorityPieSheet> {
  TaskPriority? _selected;

  @override
  Widget build(BuildContext context) {
    final byPriority = {
      for (final priority in TaskPriority.values)
        priority: widget.tasks
            .where((task) => task.priority == priority)
            .toList(),
    };
    // Only non-empty priorities become slices, so the tap index has to be
    // mapped back through this list rather than through TaskPriority.values.
    final slices = TaskPriority.values
        .where((priority) => byPriority[priority]!.isNotEmpty)
        .toList();
    final selectedTasks = _selected == null
        ? const <PlannerTask>[]
        : byPriority[_selected]!;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  widget.rangeLabel,
                  style: const TextStyle(color: Color(0xFF586174)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(widget.emptyText),
              )
            else ...[
              SizedBox(
                height: 190,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              // Match exactly one event per tap. A single tap
                              // also emits down/pan-end events that all pass
                              // isInterestedForInteractions, which would fire
                              // this callback repeatedly and make the
                              // selection flicker on and straight back off.
                              if (event is! FlTapUpEvent) return;
                              final section =
                                  response?.touchedSection?.touchedSectionIndex;
                              if (section == null ||
                                  section < 0 ||
                                  section >= slices.length) {
                                return;
                              }
                              // Selecting is idempotent — re-tapping a slice
                              // keeps it shown rather than dismissing it. Use
                              // 清除 to go back to the overview.
                              setState(() => _selected = slices[section]);
                            },
                          ),
                          sections: [
                            for (final priority in slices)
                              PieChartSectionData(
                                value: byPriority[priority]!.length.toDouble(),
                                color: context
                                    .read<TaskProvider>()
                                    .colorForPriority(priority),
                                title: '${byPriority[priority]!.length}',
                                // Selected slice pops out slightly.
                                radius: _selected == priority ? 62 : 54,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final priority in TaskPriority.values)
                          _LegendRow(
                            priority: priority,
                            count: byPriority[priority]!.length,
                            selected: _selected == priority,
                            onTap: byPriority[priority]!.isEmpty
                                ? null
                                : () => setState(() => _selected = priority),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_selected == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    context.tr(
                      '點選圖表或圖例，查看該優先度的任務',
                      'Tap the chart or legend to view tasks at that priority',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF9AA4B2),
                      fontSize: 13,
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: context.read<TaskProvider>().colorForPriority(
                          _selected!,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(
                        '${_selected!.label}優先度 · ${selectedTasks.length} 項',
                        '${_selected!.localizedLabel(english: true)} priority · ${selectedTasks.length} tasks',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selected = null),
                      child: Text(context.tr('清除', 'Clear')),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selectedTasks.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFCBD5E1),
                    ),
                    itemBuilder: (context, index) =>
                        _TaskSummaryRow(task: selectedTasks[index]),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.priority,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final TaskPriority priority;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: context.read<TaskProvider>().colorForPriority(priority),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${priority.localizedLabel(english: context.isEnglish)}　$count',
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: count == 0 ? const Color(0xFF9AA4B2) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact one-line task row for the drill-down list — the full TaskTile is
/// too tall for a sheet that may show a dozen tasks.
class _TaskSummaryRow extends StatelessWidget {
  const _TaskSummaryRow({required this.task});

  final PlannerTask task;

  @override
  Widget build(BuildContext context) {
    final days = task.days.map(dateOnly).toList()..sort(compareDates);
    final when = days.isEmpty
        ? ''
        : days.length == 1
        ? dayLabel(days.first, english: context.isEnglish)
        : context.tr(
            '${dayLabel(days.first)} 起 ${days.length} 天',
            '${days.length} days from ${dayLabel(days.first, english: true)}',
          );
    final time = days.isEmpty ? null : task.timeForDay(days.first);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: task.isDone
                ? const Color(0xFF0F766E)
                : const Color(0xFFB6BECC),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone ? const Color(0xFF9AA4B2) : null,
                  ),
                ),
                if (task.notes.isNotEmpty)
                  LinkifiedText(
                    task.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA4B2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                when,
                style: const TextStyle(fontSize: 12, color: Color(0xFF586174)),
              ),
              if (time != null)
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateBar {
  const _RateBar({
    required this.label,
    required this.done,
    required this.total,
  });

  final String label;
  final int done;
  final int total;

  double get rate => total == 0 ? 0 : done / total;
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
            segments: [
              ButtonSegment(
                value: ProgressRange.week,
                label: Text(context.tr('本週', 'Week')),
              ),
              ButtonSegment(
                value: ProgressRange.month,
                label: Text(context.tr('本月', 'Month')),
              ),
              ButtonSegment(
                value: ProgressRange.custom,
                label: Text(context.tr('自訂範圍', 'Custom')),
              ),
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
            tooltip: context.tr('變更日期範圍', 'Change date range'),
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: onEditCustom,
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Panel(
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
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF586174)),
                ),
              ),
              // Hints that the tile drills down into a chart.
              if (icon != null) ...[
                const SizedBox(width: 3),
                Icon(icon, size: 13, color: const Color(0xFF9AA4B2)),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: tile,
    );
  }
}
