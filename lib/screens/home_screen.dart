import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/add_task_sheet.dart';
import 'calendar_screen.dart';
import 'plan_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DateTime _today = dateOnly(DateTime.now());
  int _index = 0;

  static const _screens = [
    TodayScreen(),
    CalendarScreen(),
    PlanScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No app bar: with the title gone it was just an empty band, so the
      // pages start at the top and the settings button floats over them.
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          Positioned(
            top: 0,
            right: 4,
            child: SafeArea(
              child: Material(
                color: pageBackgroundColor.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '設定',
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => _openSettings(context),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('新增任務'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '行事曆'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '計畫'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '進度'),
        ],
      ),
    );
  }

  /// TaskProvider is provided inside the home route, so a pushed route sits
  /// above it in the tree and can't look it up. Hand the existing instance
  /// down explicitly.
  void _openSettings(BuildContext context) {
    final provider = context.read<TaskProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TaskProvider>.value(
          value: provider,
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return AddTaskSheet(
          initialDay: _today,
          days: weekContaining(_today),
          onCreate: (title, notes, days, timesByDay, priority) {
            provider.addTask(
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
}
