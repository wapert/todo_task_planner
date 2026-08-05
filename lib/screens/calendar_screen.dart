import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/panel.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

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
    final weekDays = weekContaining(_selectedDay);
    final tasks = provider.tasksFor(_selectedDay);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              locale: 'zh_TW',
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                // Keeps the next-month chevron clear of the floating
                // settings button in the corner above it.
                headerPadding: EdgeInsets.fromLTRB(0, 8, 40, 8),
              ),
              startingDayOfWeek: StartingDayOfWeek.monday,
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
            child: tasks.isEmpty
                ? const EmptyTaskState()
                : Column(
                    children: tasks
                        .map(
                          (task) => TaskTile(
                            task: task,
                            selectedDay: _selectedDay,
                            weekDays: weekDays,
                            onToggle: () => provider.toggleTask(task),
                            onDaysChanged: (days) =>
                                provider.updateTaskDays(task, days),
                            onEdit: () => showEditTaskSheet(
                              context,
                              task: task,
                              anchorDay: _selectedDay,
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
