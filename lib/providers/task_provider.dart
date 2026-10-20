import 'dart:async';

import 'package:flutter/material.dart';

import '../models/planner_task.dart';
import '../services/apple_calendar_service.dart';
import '../services/google_calendar_service.dart';
import '../services/notification_service.dart';
import '../services/task_event.dart';
import '../services/task_service.dart';
import '../utils/date_utils.dart';

enum PriorityColorStyle { textOnly, fill, outline, textBackground }

enum CalendarSyncTarget { none, google, apple }

/// Owns the signed-in user's live task list (synced via Firestore) and every
/// mutation/sync operation that used to live directly on the home page's
/// State object.
class TaskProvider extends ChangeNotifier {
  TaskProvider({
    required this.uid,
    this.calendarSyncTarget = CalendarSyncTarget.none,
  }) : _taskService = TaskService(uid: uid),
       _googleCalendarService = GoogleCalendarService(),
       _appleCalendarService = AppleCalendarService();

  final String uid;
  final CalendarSyncTarget calendarSyncTarget;
  final TaskService _taskService;
  final GoogleCalendarService _googleCalendarService;
  final AppleCalendarService _appleCalendarService;

  StreamSubscription<List<PlannerTask>>? _taskSub;
  StreamSubscription<List<String>?>? _categorySub;
  StreamSubscription<Map<String, int>?>? _appearanceSub;
  StreamSubscription<bool>? _calendarSyncSub;

  /// Drives the overdue '!' marks. They depend on the clock, not on any
  /// change to the data, so without a tick nothing tells Flutter to rebuild
  /// when a reminder's time passes — the mark would only appear the next
  /// time something else happened to rebuild the page.
  Timer? _overdueTicker;
  int _lastOverdueCount = -1;

  static const defaultBackgroundColor = Color(0xFFF8FAFC);
  static const defaultToolbarColor = Color(0xFFD8DEE6);
  static const defaultHighPriorityColor = Color(0xFFDC2626);
  static const defaultMediumPriorityColor = Color(0xFFD97706);
  static const defaultLowPriorityColor = Color(0xFF16A34A);
  static const defaultAddButtonColor = Color(0xFF2563EB);

  Color backgroundColor = defaultBackgroundColor;
  Color toolbarColor = defaultToolbarColor;
  Color highPriorityColor = defaultHighPriorityColor;
  Color mediumPriorityColor = defaultMediumPriorityColor;
  Color lowPriorityColor = defaultLowPriorityColor;
  Color addButtonColor = defaultAddButtonColor;
  PriorityColorStyle priorityColorStyle = PriorityColorStyle.fill;
  int addButtonOpacityPercent = 100;

  /// null until the user's own list loads; falls back to the presets.
  List<String>? _categories;
  List<PlannerTask> _tasks = [];
  List<PlannerTask> get tasks => _tasks;

  bool _loading = true;
  bool _initialAutomaticSyncStarted = false;
  bool calendarSyncEnabled = false;
  bool get loading => _loading;

  Future<void> init() async {
    _taskSub = _taskService.watchTasks().listen((tasks) {
      _tasks = tasks;
      _loading = false;
      notifyListeners();
      // Reminders are derived from the task list, so re-deriving them here
      // covers every path that can change a task, including an edit made on
      // another device.
      unawaited(NotificationService.instance.syncTaskReminders(tasks));
      unawaited(_refreshBadge());
      if (calendarSyncEnabled &&
          !_initialAutomaticSyncStarted &&
          calendarSyncTarget != CalendarSyncTarget.none) {
        _initialAutomaticSyncStarted = true;
        unawaited(_syncAutomatically());
      }
    });
    _categorySub = _taskService.watchCategories().listen((categories) {
      _categories = categories;
      notifyListeners();
    });
    _appearanceSub = _taskService.watchAppearance().listen((appearance) {
      if (appearance != null) {
        backgroundColor = Color(
          appearance['background'] ?? defaultBackgroundColor.toARGB32(),
        );
        toolbarColor = _normalizedToolbarColor(
          appearance['toolbar'] ?? defaultToolbarColor.toARGB32(),
        );
        highPriorityColor = Color(
          appearance['priorityHigh'] ?? defaultHighPriorityColor.toARGB32(),
        );
        mediumPriorityColor = Color(
          appearance['priorityMedium'] ?? defaultMediumPriorityColor.toARGB32(),
        );
        lowPriorityColor = Color(
          appearance['priorityLow'] ?? defaultLowPriorityColor.toARGB32(),
        );
        addButtonColor = Color(
          appearance['addButton'] ?? defaultAddButtonColor.toARGB32(),
        );
        final savedPriorityStyle = appearance['priorityStyle'];
        priorityColorStyle = savedPriorityStyle == null
            ? PriorityColorStyle.fill
            : PriorityColorStyle.values[savedPriorityStyle.clamp(
                0,
                PriorityColorStyle.values.length - 1,
              )];
        addButtonOpacityPercent = appearance['addButtonOpacity'] ?? 100;
      }
      notifyListeners();
    });
    _startOverdueTicker();
    _calendarSyncSub = _taskService.watchCalendarSyncEnabled().listen((
      enabled,
    ) {
      calendarSyncEnabled = enabled;
      notifyListeners();
      if (enabled &&
          !_initialAutomaticSyncStarted &&
          !_loading &&
          calendarSyncTarget != CalendarSyncTarget.none) {
        _initialAutomaticSyncStarted = true;
        unawaited(_syncAutomatically());
      }
    });
  }

  /// Re-renders only when the number of overdue reminders actually changes,
  /// so an idle list is not rebuilt every half minute.
  void _startOverdueTicker() {
    _overdueTicker?.cancel();
    _overdueTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      final count = NotificationService.instance.overdueCount(_tasks);
      if (count == _lastOverdueCount) return;
      _lastOverdueCount = count;
      notifyListeners();
      unawaited(NotificationService.instance.updateBadge(count));
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
    await _categorySub?.cancel();
    _categorySub = null;
    await _appearanceSub?.cancel();
    _appearanceSub = null;
    await _calendarSyncSub?.cancel();
    _calendarSyncSub = null;
    await NotificationService.instance.cancelAll();
    await _taskService.deleteAllData();
  }

  @override
  void dispose() {
    _overdueTicker?.cancel();
    _taskSub?.cancel();
    _categorySub?.cancel();
    _appearanceSub?.cancel();
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  Color colorForPriority(TaskPriority priority) => switch (priority) {
    TaskPriority.low => _mergedColor(lowPriorityColor),
    TaskPriority.medium => _mergedColor(mediumPriorityColor),
    TaskPriority.high => _mergedColor(highPriorityColor),
  };

  Color get effectiveAddButtonColor => _mergedColor(
    addButtonColor,
  ).withValues(alpha: addButtonOpacityPercent / 100);
  Color get effectiveToolbarColor => _mergedColor(toolbarColor);
  Color get toolbarForegroundColor =>
      ThemeData.estimateBrightnessForColor(effectiveToolbarColor) ==
          Brightness.dark
      ? Colors.white
      : const Color(0xFF1F2937);

  Color _mergedColor(Color color) =>
      color.toARGB32() == 0 ? backgroundColor : color;

  static Color _normalizedToolbarColor(int value) => switch (value) {
    // The two dark toolbar options render semi-transparent. Earlier builds
    // used 70% (0xB3); bump existing selections to 80% (0xCC) so they are a
    // little more solid without the user re-picking.
    0xFF123A63 || 0xB3123A63 => const Color(0xCC123A63),
    // Black was removed from the palette; migrate its original, its 70%
    // softened value, and the dark-green option up to the 80% replacement.
    0xFF000000 ||
    0xA6000000 ||
    0xB30B4F3F => const Color(0xCC0B4F3F),
    _ => Color(value),
  };

  Future<void> updateAppearance({
    Color? background,
    Color? toolbar,
    Color? priorityHigh,
    Color? priorityMedium,
    Color? priorityLow,
    Color? addButton,
    PriorityColorStyle? priorityStyle,
    int? addButtonOpacity,
  }) {
    backgroundColor = background ?? backgroundColor;
    toolbarColor = toolbar ?? toolbarColor;
    highPriorityColor = priorityHigh ?? highPriorityColor;
    mediumPriorityColor = priorityMedium ?? mediumPriorityColor;
    lowPriorityColor = priorityLow ?? lowPriorityColor;
    addButtonColor = addButton ?? addButtonColor;
    priorityColorStyle = priorityStyle ?? priorityColorStyle;
    addButtonOpacityPercent = addButtonOpacity ?? addButtonOpacityPercent;
    notifyListeners();
    return _taskService.saveAppearance({
      'background': backgroundColor.toARGB32(),
      'toolbar': toolbarColor.toARGB32(),
      'priorityHigh': highPriorityColor.toARGB32(),
      'priorityMedium': mediumPriorityColor.toARGB32(),
      'priorityLow': lowPriorityColor.toARGB32(),
      'addButton': addButtonColor.toARGB32(),
      'priorityStyle': priorityColorStyle.index,
      'addButtonOpacity': addButtonOpacityPercent,
    });
  }

  // --- Task queries -------------------------------------------------------

  /// The user's category list, stored on their Firestore user document so an
  /// added category survives even before any task uses it.
  List<String> get categories => _categories ?? presetTaskCategories;

  Future<void> addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || categories.contains(trimmed)) {
      return Future.value();
    }
    return _taskService.saveCategories([...categories, trimmed]);
  }

  Future<void> removeCategory(String name) {
    return _taskService.saveCategories(
      categories.where((category) => category != name).toList(),
    );
  }

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
    String category = '',
    int? reminderMinutesBefore,
    bool isSpan = false,
  }) async {
    final id = _taskService.createTaskId();
    final task = PlannerTask(
      id: id,
      title: title,
      notes: notes,
      days: days,
      timesByDay: timesByDay,
      priority: priority,
      category: category,
      reminderMinutesBefore: reminderMinutesBefore,
      isSpan: isSpan,
      source: 'Manual',
    );
    await _taskService.updateTask(task);
    await _syncAutomatically(task: task);
    return task;
  }

  /// Keeps the icon badge equal to the number of '!' marks on screen.
  Future<void> _refreshBadge() {
    final count = NotificationService.instance.overdueCount(_tasks);
    _lastOverdueCount = count;
    return NotificationService.instance.updateBadge(count);
  }

  /// Dismisses the overdue mark for one day's reminder.
  ///
  /// Deliberately separate from completing the task: acknowledging that a
  /// reminder fired is not the same as having done the thing.
  Future<void> acknowledgeReminder(PlannerTask task, DateTime day) async {
    final key = PlannerTask.calendarDayKey(dateOnly(day));
    if (!task.acknowledgedReminderDays.add(key)) return;
    notifyListeners();
    // The badge drops by one as the mark disappears, and the follow-up
    // nudges for this occurrence are called off by the re-sync.
    await _refreshBadge();
    await _taskService.updateTask(task);
    await NotificationService.instance.syncTaskReminders(_tasks);
  }

  /// Toggles completion for one [day] only, so a multi-day task's days stay
  /// independent of one another.
  Future<void> toggleTask(PlannerTask task, DateTime day) {
    final key = PlannerTask.calendarDayKey(dateOnly(day));
    if (!task.completedDays.add(key)) {
      task.completedDays.remove(key);
    }
    notifyListeners();
    // A day just marked done should stop nagging; a day reopened should start
    // reminding again, so re-derive the schedule and the badge.
    unawaited(NotificationService.instance.syncTaskReminders(_tasks));
    unawaited(_refreshBadge());
    return _taskService.updateTask(task);
  }

  Future<void> updateTaskNotes(PlannerTask task, String notes) async {
    task.notes = notes;
    notifyListeners();
    await _taskService.updateTask(task);
    await _syncAutomatically(task: task, updateExisting: true);
  }

  Future<void> editTask({
    required PlannerTask task,
    required String title,
    required String notes,
    required List<DateTime> days,
    required Map<DateTime, TimeOfDay> timesByDay,
    required TaskPriority priority,
    String category = '',
    int? reminderMinutesBefore,
    bool isSpan = false,
  }) async {
    final retainedDayKeys = days.map(PlannerTask.calendarDayKey).toSet();
    final removedGoogleIds = task.googleCalendarEventIds.entries
        .where((entry) => !retainedDayKeys.contains(entry.key))
        .map((entry) => entry.value);
    final removedAppleIds = task.appleCalendarEventIds.entries
        .where((entry) => !retainedDayKeys.contains(entry.key))
        .map((entry) => entry.value);
    if (calendarSyncEnabled) {
      await _googleCalendarService.deleteEvents(removedGoogleIds);
      await _appleCalendarService.deleteEvents(removedAppleIds);
      task.googleCalendarEventIds.removeWhere(
        (day, _) => !retainedDayKeys.contains(day),
      );
      task.appleCalendarEventIds.removeWhere(
        (day, _) => !retainedDayKeys.contains(day),
      );
    }
    // Captured before the edit so a changed reminder can drop its stale
    // acknowledgement below.
    final previousLead = task.reminderMinutesBefore;
    final previousTimes = normalizeTimes(task.timesByDay);

    task.title = title;
    task.notes = notes;
    task.days = days.map(dateOnly).toList();
    task.timesByDay = normalizeTimes(timesByDay)
      ..removeWhere(
        (day, _) => !task.days.any((taskDay) => isSameDay(taskDay, day)),
      );
    task.priority = priority;
    task.category = category;
    task.reminderMinutesBefore = reminderMinutesBefore;
    task.isSpan = isSpan;
    // Re-timing a reminder makes it a new reminder: the user dismissing the
    // previous one must not silence it. Without this, editing the time of an
    // already-dismissed task leaves it permanently unscheduled.
    final liveKeys = {
      for (final day in task.days) PlannerTask.calendarDayKey(day),
    };
    task.acknowledgedReminderDays.removeWhere((key) {
      if (!liveKeys.contains(key)) return true;
      if (previousLead != reminderMinutesBefore) return true;
      final day = task.days.firstWhere(
        (item) => PlannerTask.calendarDayKey(item) == key,
      );
      final before = previousTimes[dateOnly(day)];
      final after = task.timesByDay[dateOnly(day)];
      return before?.hour != after?.hour || before?.minute != after?.minute;
    });
    await _taskService.updateTask(task);
    await _syncAutomatically(task: task, updateExisting: true);
  }

  Future<void> deleteTask(PlannerTask task) async {
    if (calendarSyncEnabled) {
      await _googleCalendarService.deleteEvents(
        task.googleCalendarEventIds.values,
      );
      await _appleCalendarService.deleteEvents(
        task.appleCalendarEventIds.values,
      );
    }
    await _taskService.deleteTask(task.id);
  }

  Future<String> setCalendarSyncEnabled(bool enabled) async {
    if (!enabled) {
      calendarSyncEnabled = false;
      _initialAutomaticSyncStarted = false;
      notifyListeners();
      await _taskService.saveCalendarSyncEnabled(false);
      return '已停止自動同步。';
    }

    if (calendarSyncTarget == CalendarSyncTarget.google) {
      await _googleCalendarService.requestPermission();
    } else if (calendarSyncTarget == CalendarSyncTarget.apple) {
      await _appleCalendarService.requestPermission();
    } else {
      return '此帳號沒有可用的外部行事曆。';
    }
    calendarSyncEnabled = true;
    _initialAutomaticSyncStarted = true;
    notifyListeners();
    await _taskService.saveCalendarSyncEnabled(true);
    if (calendarSyncTarget == CalendarSyncTarget.google) {
      return syncGoogleCalendar();
    }
    return syncAppleCalendar();
  }

  Future<String> syncGoogleCalendar() {
    return _googleCalendarService.createEvents(
      _tasks.expand((task) => _eventsForTask(task, google: true)).toList(),
      onEventSynced: (event, eventId) =>
          _saveCalendarEventId(event, eventId, google: true),
    );
  }

  Future<void> _syncAutomatically({
    PlannerTask? task,
    bool updateExisting = false,
  }) async {
    if (!calendarSyncEnabled) return;
    try {
      final tasks = task == null ? _tasks : [task];
      switch (calendarSyncTarget) {
        case CalendarSyncTarget.google:
          await _googleCalendarService.createEvents(
            tasks.expand((item) => _eventsForTask(item, google: true)).toList(),
            updateExisting: updateExisting,
            onEventSynced: (event, eventId) =>
                _saveCalendarEventId(event, eventId, google: true),
          );
          return;
        case CalendarSyncTarget.apple:
          await _appleCalendarService.createEvents(
            tasks
                .expand((item) => _eventsForTask(item, google: false))
                .toList(),
            updateExisting: updateExisting,
            onEventSynced: (event, eventId) =>
                _saveCalendarEventId(event, eventId, google: false),
          );
          return;
        case CalendarSyncTarget.none:
          return;
      }
    } catch (error) {
      // Calendar authorization can be declined or temporarily unavailable.
      // The task itself must remain saved; manual sync remains available.
      debugPrint('Automatic calendar sync skipped: $error');
    }
  }

  Future<String> syncAppleCalendar() {
    return _appleCalendarService.createEvents(
      _tasks.expand((task) => _eventsForTask(task, google: false)).toList(),
      onEventSynced: (event, eventId) =>
          _saveCalendarEventId(event, eventId, google: false),
    );
  }

  Iterable<TaskCalendarEvent> _eventsForTask(
    PlannerTask task, {
    required bool google,
  }) {
    return task.days.map((day) {
      final dayKey = PlannerTask.calendarDayKey(day);
      return TaskCalendarEvent(
        taskId: task.id,
        title: task.title,
        day: day,
        notes: task.notes,
        time: task.timeForDay(day),
        externalEventId: google
            ? task.googleCalendarEventIds[dayKey]
            : task.appleCalendarEventIds[dayKey],
      );
    });
  }

  Future<void> _saveCalendarEventId(
    TaskCalendarEvent event,
    String eventId, {
    required bool google,
  }) async {
    final task = _tasks.where((item) => item.id == event.taskId).firstOrNull;
    if (task == null) return;
    final dayKey = PlannerTask.calendarDayKey(event.day);
    if (google) {
      task.googleCalendarEventIds[dayKey] = eventId;
    } else {
      task.appleCalendarEventIds[dayKey] = eventId;
    }
    await _taskService.updateTask(task);
  }
}
