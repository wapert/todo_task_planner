import 'dart:async';

import 'package:flutter/material.dart';

import '../models/planner_task.dart';
import '../services/apple_calendar_service.dart';
import '../services/google_calendar_service.dart';
import '../services/task_event.dart';
import '../services/task_service.dart';
import '../utils/date_utils.dart';

/// Owns the signed-in user's live task list (synced via Firestore) and every
/// mutation/sync operation that used to live directly on the home page's
/// State object.
class TaskProvider extends ChangeNotifier {
  TaskProvider({required this.uid})
    : _taskService = TaskService(uid: uid),
      _googleCalendarService = GoogleCalendarService(),
      _appleCalendarService = AppleCalendarService();

  final String uid;
  final TaskService _taskService;
  final GoogleCalendarService _googleCalendarService;
  final AppleCalendarService _appleCalendarService;

  StreamSubscription<List<PlannerTask>>? _taskSub;
  List<PlannerTask> _tasks = [];
  List<PlannerTask> get tasks => _tasks;

  bool _loading = true;
  bool get loading => _loading;

  Future<void> init() async {
    _taskSub = _taskService.watchTasks().listen((tasks) {
      _tasks = tasks;
      _loading = false;
      notifyListeners();
    });
  }

  /// Wipes this user's cloud data as part of account deletion.
  ///
  /// The live stream is cancelled first: deleting the account moments later
  /// revokes access, and a still-open listener would surface a
  /// permission-denied error against data that is already gone.
  Future<void> deleteAccountData() async {
    await _taskSub?.cancel();
    _taskSub = null;
    await _taskService.deleteAllData();
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    super.dispose();
  }

  // --- Task queries -------------------------------------------------------

  List<PlannerTask> tasksFor(DateTime day) {
    final date = dateOnly(day);
    final matching = _tasks
        .where((task) => task.days.any((taskDay) => isSameDay(taskDay, date)))
        .toList();
    matching.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final aMinutes = minutesOfTime(a.timeForDay(date));
      final bMinutes = minutesOfTime(b.timeForDay(date));
      return aMinutes.compareTo(bMinutes);
    });
    return matching;
  }

  // --- Task mutations -------------------------------------------------------

  Future<PlannerTask> addTask({
    required String title,
    required String notes,
    required List<DateTime> days,
    required Map<DateTime, TimeOfDay> timesByDay,
    required TaskPriority priority,
  }) async {
    final id = _taskService.createTaskId();
    final task = PlannerTask(
      id: id,
      title: title,
      notes: notes,
      days: days,
      timesByDay: timesByDay,
      priority: priority,
      source: 'Manual',
    );
    await _taskService.updateTask(task);
    return task;
  }

  Future<void> toggleTask(PlannerTask task) {
    task.isDone = !task.isDone;
    return _taskService.updateTask(task);
  }

  Future<void> updateTaskDays(PlannerTask task, List<DateTime> days) {
    if (days.isEmpty) {
      return Future.value();
    }
    final normalizedDays = days.map(dateOnly).toList();
    task.days = normalizedDays;
    task.timesByDay.removeWhere(
      (day, _) => !normalizedDays.any((taskDay) => isSameDay(taskDay, day)),
    );
    return _taskService.updateTask(task);
  }

  Future<void> editTask({
    required PlannerTask task,
    required String title,
    required String notes,
    required List<DateTime> days,
    required Map<DateTime, TimeOfDay> timesByDay,
    required TaskPriority priority,
  }) {
    task.title = title;
    task.notes = notes;
    task.days = days.map(dateOnly).toList();
    task.timesByDay = normalizeTimes(timesByDay)
      ..removeWhere(
        (day, _) => !task.days.any((taskDay) => isSameDay(taskDay, day)),
      );
    task.priority = priority;
    return _taskService.updateTask(task);
  }

  Future<void> deleteTask(PlannerTask task) {
    return _taskService.deleteTask(task.id);
  }

  Future<String> syncGoogleCalendar() {
    return _googleCalendarService.createEvents(
      _tasks.expand(_eventsForTask).toList(),
    );
  }

  Future<String> syncAppleCalendar() {
    return _appleCalendarService.createEvents(
      _tasks.expand(_eventsForTask).toList(),
    );
  }

  Iterable<TaskCalendarEvent> _eventsForTask(PlannerTask task) {
    return task.days.map(
      (day) => TaskCalendarEvent(
        title: task.title,
        day: day,
        notes: task.notes,
        time: task.timeForDay(day),
      ),
    );
  }
}
