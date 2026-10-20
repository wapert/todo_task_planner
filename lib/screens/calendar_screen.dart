import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';
import '../widgets/period_header.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final today = dateOnly(DateTime.now());
    final tasks = provider.tasksFor(_selectedDay);

    return Scaffold(
      backgroundColor: provider.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 88,
        backgroundColor: provider.effectiveToolbarColor,
        foregroundColor: provider.toolbarForegroundColor,
        title: PageHeaderText(
          title: context.tr('行事曆', 'Calendar'),
          subtitle: isSameDay(_selectedDay, today)
              ? context.tr(
                  '${fullDateLabel(_selectedDay)} · 今日',
                  '${fullDateLabel(_selectedDay, english: true)} · Today',
                )
              : fullDateLabel(_selectedDay, english: context.isEnglish),
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
          Panel(
            child: TableCalendar<void>(
              firstDay: DateTime(today.year - 2),
              lastDay: DateTime(today.year + 2),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = dateOnly(selected);
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) => _focusedDay = focused,
              calendarFormat: CalendarFormat.month,
              eventLoader: (day) => provider.tasksFor(day),
              locale: context.isEnglish ? 'en_US' : 'zh_TW',
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                // Keeps the next-month chevron clear of the floating
                // settings button in the corner above it.
                headerPadding: EdgeInsets.fromLTRB(0, 8, 40, 8),
              ),
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarStyle: const CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: flaggedColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Color(0xFFFFD9A6),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: Colors.black87),
                selectedDecoration: BoxDecoration(
                  color: flaggedColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: tasks.isEmpty
                ? const EmptyTaskState()
                : Column(
                    children: tasks
                        .map(
                          (task) => TaskTile(
                            task: task,
                            selectedDay: _selectedDay,
                            onToggle: () => provider.toggleTask(task, _selectedDay),
                            onDelete: () => confirmDeleteTask(context, task),
                            onEdit: () => showEditTaskSheet(
                              context,
                              task: task,
                              anchorDay: _selectedDay,
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
