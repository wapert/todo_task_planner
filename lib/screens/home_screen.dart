import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<TaskProvider>();
    final screens = [
      TodayScreen(onOpenSettings: () => _openSettings(context)),
      CalendarScreen(onOpenSettings: () => _openSettings(context)),
      PlanScreen(onOpenSettings: () => _openSettings(context)),
      ProgressScreen(onOpenSettings: () => _openSettings(context)),
    ];
    return Scaffold(
      backgroundColor: appearance.backgroundColor,
      body: IndexedStack(index: _index, children: screens),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: appearance.effectiveAddButtonColor,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(
                  appearance.effectiveAddButtonColor,
                ) ==
                Brightness.dark
            ? Colors.white
            : const Color(0xFF1F2937),
        onPressed: () => _showAddTaskSheet(context),
        icon: const Icon(Icons.add),
        label: Text(
          context.tr('新增任務', 'Add task'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: appearance.toolbarForegroundColor),
          ),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: appearance.toolbarForegroundColor),
          ),
          indicatorColor: appearance.toolbarForegroundColor.withValues(
            alpha: 0.18,
          ),
        ),
        child: NavigationBar(
          backgroundColor: appearance.effectiveToolbarColor,
          surfaceTintColor: Colors.transparent,
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.today),
              label: context.tr('今日', 'Today'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month),
              label: context.tr('行事曆', 'Calendar'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.edit_note),
              label: context.tr('計畫', 'Plan'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart),
              label: context.tr('進度', 'Progress'),
            ),
          ],
        ),
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
      showDragHandle: true,
      constraints: BoxConstraints(
        // Keep part of the page visible so the sheet never feels like a new
        // full-screen route and remains easy to dismiss on iPhone.
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      builder: (context) {
        return ChangeNotifierProvider<TaskProvider>.value(
          value: provider,
          child: AddTaskSheet(
            // Read fresh on open: the home shell is long-lived, so a frozen
            // field would default to whatever day the user logged in.
            initialDay: dateOnly(DateTime.now()),
            categories: provider.categories,
            onAddCategory: provider.addCategory,
            onRemoveCategory: provider.removeCategory,
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
                  provider.addTask(
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
          ),
        );
      },
    );
  }
}
