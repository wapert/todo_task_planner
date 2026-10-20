import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/planner_task.dart';
import '../utils/date_utils.dart';

/// Schedules the local "alarm" notifications that fire before a task is due.
///
/// Reminders are derived state: the task list in Firestore is the source of
/// truth, and every change re-derives the whole pending schedule. That keeps
/// the two in step without having to track which individual reminders were
/// already registered, which the OS does not reliably let us read back.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// iOS silently drops anything past 64 pending notifications, so a user with
  /// a 12-week repeat would otherwise lose the later ones with no warning.
  /// Scheduling only the soonest few keeps every platform inside its limit;
  /// the window rolls forward as reminders fire and the list re-syncs.
  static const _maxScheduled = 56;

  /// A channel's sound and audio attributes are fixed when Android first
  /// creates it and cannot be changed afterwards — moving to the alarm stream
  /// therefore needs a new channel id, or the old silent one would persist
  /// for every existing install.
  static const _channelId = 'task_reminders_alarm';

  /// A reminder repeats until the task is marked done or its '!' dismissed.
  /// Nothing checks "still not done" at fire time — acting on the task
  /// re-runs the sync, which drops the follow-ups and cancels them.
  ///
  /// Every occurrence costs a notification slot and iOS silently discards
  /// anything past 64 pending, so the repeat is bounded: a tighter interval
  /// buys persistence at the cost of how far ahead reminders can be queued.
  /// Spread over 15 minutes rather than a tight burst: Android defers these
  /// alarms under doze (measured at ~3 minutes late, and throttled to roughly
  /// one per app per 9 minutes), so a shorter interval buys nothing there —
  /// while on iOS every extra notification eats into the 64-pending limit
  /// that caps how far ahead reminders can be queued.
  static const _followUpSeconds = [0, 5 * 60, 15 * 60];

  /// Long-short-long, so a reminder is distinguishable by feel from the
  /// single blip of an ordinary notification. This is the main attention
  /// signal on a phone kept on silent.
  static final Int64List _vibrationPattern = Int64List.fromList([
    0,
    600,
    300,
    600,
    300,
    900,
  ]);

  bool _ready = false;

  /// True once the user has granted notification permission, so the UI can
  /// explain why a reminder would not arrive.
  bool permissionGranted = false;

  /// The last scheduling failure, kept so the diagnostics panel can show it.
  /// Scheduling errors are caught so one bad reminder cannot take down the
  /// rest, which also makes them invisible — this is how they surface.
  String? lastError;

  /// The resolved time zone. A wrong zone would fire reminders hours out.
  String timeZoneName = 'unresolved';

  /// Fire times from the most recent sync, soonest first. iOS will not tell
  /// us back when a pending request is due, so this is the only way to see
  /// whether a reminder is minutes away or days away.
  List<DateTime> lastScheduledTimes = const [];

  Future<void> init() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      timeZoneName = zone.identifier;
    } catch (error) {
      // An unknown zone name should not cost the user their reminders; UTC is
      // wrong by hours at worst, whereas throwing here loses them entirely.
      timeZoneName = 'fallback (${tz.local.name})';
      lastError = 'timezone: $error';
      debugPrint('Falling back to the default time zone: $error');
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly later, so the prompt lands when the user
          // first turns a reminder on rather than at first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Reports whether reminders can currently be posted, without prompting.
  ///
  /// iOS only ever shows its permission prompt once, so a declined or
  /// never-asked state has to be readable to explain the silence.
  Future<bool> refreshPermissionStatus() async {
    await init();
    if (!_supported) return false;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      permissionGranted = await android?.areNotificationsEnabled() ?? false;
    } else if (Platform.isMacOS) {
      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      _applyOptions(await darwin?.checkPermissions());
    } else {
      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      _applyOptions(await darwin?.checkPermissions());
    }
    return permissionGranted;
  }

  /// Authorisation is not one flag. A notification can be authorised and
  /// still never appear, because alerts are a separate setting — that state
  /// looks exactly like a broken app, so each flag is recorded separately.
  void _applyOptions(NotificationsEnabledOptions? options) {
    permissionGranted = options?.isEnabled ?? false;
    alertsEnabled = options?.isAlertEnabled ?? false;
    soundEnabled = options?.isSoundEnabled ?? false;
    provisionalOnly = options?.isProvisionalEnabled ?? false;
  }

  /// Whether a notification may actually show itself. False means iOS accepts
  /// and delivers the notification, but nothing is visible.
  bool alertsEnabled = false;
  bool soundEnabled = false;

  /// Provisional authorisation delivers quietly to Notification Centre only.
  bool provisionalOnly = false;

  /// Asks for permission, returning whether reminders can actually be posted.
  Future<bool> requestPermission() async {
    await init();
    var granted = true;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      granted = await android?.requestNotificationsPermission() ?? false;
      // Android 12+ needs a separate grant before alarms may fire at an exact
      // minute. Without it the OS still delivers, just batched — late enough
      // to be useless for a reminder, so ask, but do not treat a refusal as
      // a failure to schedule.
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isMacOS) {
      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      granted =
          await darwin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else if (Platform.isIOS) {
      final darwin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      granted =
          await darwin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    permissionGranted = granted;
    return granted;
  }

  /// Rebuilds the pending reminder schedule from [tasks].
  Future<void> syncTaskReminders(List<PlannerTask> tasks) async {
    await init();
    if (!_supported) return;

    final pending = <_PendingReminder>[];
    final now = DateTime.now();
    for (final task in tasks) {
      final lead = task.reminderMinutesBefore;
      if (lead == null) continue;
      for (final day in task.days) {
        // A day already completed has nothing left to remind about, even if
        // other days of the same task are still open.
        if (task.isDoneOn(day)) continue;
        final time = task.timeForDay(day);
        // Reminders hang off a specific clock time; an all-day task has none.
        if (time == null) continue;
        // Dismissing the mark also calls off the nudges that would follow.
        if (task.acknowledgedReminderDays.contains(
          PlannerTask.calendarDayKey(dateOnly(day)),
        )) {
          continue;
        }
        final due = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        final fireAt = due.subtract(Duration(minutes: lead));
        const offsets = _followUpSeconds;
        for (var index = 0; index < offsets.length; index++) {
          final at = fireAt.add(Duration(seconds: offsets[index]));
          // A follow-up whose moment has passed is not worth firing late.
          if (!at.isAfter(now)) continue;
          pending.add(
            _PendingReminder(
              task: task,
              day: day,
              fireAt: at,
              followUp: index,
            ),
          );
        }
      }
    }

    pending.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    final scheduled = pending.take(_maxScheduled).toList();
    // The badge counts what has fired and not yet been dealt with, so it
    // keeps saying something after the notification itself is gone.
    for (var index = 0; index < scheduled.length; index++) {
      scheduled[index].badge = index + 1;
    }

    // A reminder can arrive from another device via Firestore, so the task
    // form is not the only way one comes into existence — without this, a
    // reminder set on Android would silently never fire on iOS, where
    // permission is mandatory and had never been asked for.
    if (pending.isNotEmpty && !permissionGranted) {
      await refreshPermissionStatus();
      if (!permissionGranted) await requestPermission();
    }

    // Reconciled rather than rebuilt. A cancelAll() + re-add is not atomic:
    // iOS can suspend the app between the two and leave nothing scheduled,
    // and it also destroys notifications this sync does not own, such as the
    // self-test. Touching only what actually changed avoids both.
    //
    // The id covers the fire time, so a reminder whose time moved gets a new
    // id — the stale one falls out of [desired] and is cancelled below.
    final desired = {for (final r in scheduled) r.id: r};
    final existing = await _plugin.pendingNotificationRequests();
    final existingIds = <int>{};
    for (final request in existing) {
      if (request.id == _selfTestId) continue;
      existingIds.add(request.id);
      if (!desired.containsKey(request.id)) {
        await _plugin.cancel(request.id);
      }
    }
    for (final entry in desired.entries) {
      // Already scheduled for this exact time — leaving it alone means there
      // is never a window where a due reminder is missing.
      if (existingIds.contains(entry.key)) continue;
      await _schedule(entry.value);
    }
    lastScheduledTimes = scheduled.map((r) => r.fireAt).toList();
  }

  /// What the OS actually holds right now, for the diagnostics panel.
  ///
  /// Scheduling is silent when it fails — permission can be off, or every
  /// occurrence can be in the past — so the only way to tell a working setup
  /// from a broken one is to read back what is really pending.
  Future<ReminderDiagnostics> diagnose() async {
    await init();
    if (!_supported) {
      return const ReminderDiagnostics(
        supported: false,
        permissionGranted: false,
        pendingCount: 0,
      );
    }
    await refreshPermissionStatus();
    final pending = await _plugin.pendingNotificationRequests();
    return ReminderDiagnostics(
      supported: true,
      permissionGranted: permissionGranted,
      pendingCount: pending.length,
      timeZoneName: timeZoneName,
      lastError: lastError,
      alertsEnabled: alertsEnabled,
      soundEnabled: soundEnabled,
      provisionalOnly: provisionalOnly,
      nextFireTimes: lastScheduledTimes.take(3).toList(),
    );
  }

  /// Fires a notification [seconds] from now, bypassing the task list.
  ///
  /// This separates "the OS will not deliver for us" from "our scheduling is
  /// wrong" — the two look identical from the outside.
  Future<void> scheduleSelfTest({int seconds = 15}) async {
    await init();
    if (!_supported) return;
    if (!await refreshPermissionStatus()) await requestPermission();
    await _plugin.zonedSchedule(
      _selfTestId,
      '提醒測試',
      '如果你看到這則通知，提醒功能運作正常。',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '任務提醒',
          channelDescription: '在任務開始前發出提醒',
          importance: Importance.max,
          priority: Priority.high,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static const _selfTestId = 2147483600;

  /// Set natively because the notifications plugin can only set a badge as a
  /// side effect of delivering a notification — which cannot express the
  /// count going *down* when the user clears a mark.
  static const _badgeChannel = MethodChannel('todo_planner/badge');

  /// Reminders that have fired on an unfinished task and not been dismissed.
  /// This is what the icon badge counts, so it has to match exactly what the
  /// task list shows a '!' against.
  int overdueCount(List<PlannerTask> tasks) {
    final now = DateTime.now();
    var count = 0;
    for (final task in tasks) {
      final lead = task.reminderMinutesBefore;
      if (lead == null) continue;
      for (final day in task.days) {
        if (task.isDoneOn(day)) continue;
        final time = task.timeForDay(day);
        if (time == null) continue;
        if (task.acknowledgedReminderDays.contains(
          PlannerTask.calendarDayKey(dateOnly(day)),
        )) {
          continue;
        }
        final fireAt = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ).subtract(Duration(minutes: lead));
        if (fireAt.isAfter(now)) continue;
        count++;
      }
    }
    return count;
  }

  /// Pushes [count] to the app icon. Android launcher badges follow the
  /// app's active notifications instead, so this is a no-op there.
  Future<void> updateBadge(int count) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return;
    try {
      await _badgeChannel.invokeMethod<void>('setBadge', count);
    } catch (error) {
      debugPrint('Badge not updated: $error');
    }
  }

  Future<void> cancelAll() async {
    await init();
    if (!_supported) return;
    await _plugin.cancelAll();
  }

  Future<void> _schedule(_PendingReminder reminder) async {
    final task = reminder.task;
    final time = task.timeForDay(reminder.day)!;
    // A repeat says so, otherwise the second and third look like duplicates.
    final title = reminder.followUp == 0
        ? task.title
        : '再次提醒：${task.title}';
    final body = StringBuffer(
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}',
    );
    if (task.category.isNotEmpty) body.write(' · ${task.category}');
    if (task.notes.isNotEmpty) body.write('\n${task.notes}');

    try {
      await _plugin.zonedSchedule(
        reminder.id,
        title,
        body.toString(),
        tz.TZDateTime.from(reminder.fireAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            '任務提醒',
            channelDescription: '在任務開始前發出提醒',
            importance: Importance.max,
            priority: Priority.high,
            // The alarm stream, not the notification stream: a reminder the
            // user asked for should still sound when the phone is on silent,
            // the same way a clock alarm does. On the notification stream it
            // is muted along with everything else.
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: AndroidNotificationCategory.alarm,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
            number: reminder.badge,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // A reminder that arrives silently in the notification list is
            // useless — the whole point is to interrupt. timeSensitive lights
            // the screen, plays the sound and is delivered through a Focus.
            interruptionLevel: InterruptionLevel.timeSensitive,
            badgeNumber: reminder.badge,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
            badgeNumber: reminder.badge,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (error) {
      // Most often the exact-alarm grant was refused on Android 12+. Falling
      // back to an inexact alarm delivers late rather than not at all.
      debugPrint('Exact reminder rejected, retrying inexactly: $error');
      try {
        await _plugin.zonedSchedule(
          reminder.id,
          title,
          body.toString(),
          tz.TZDateTime.from(reminder.fireAt, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              '任務提醒',
              channelDescription: '在任務開始前發出提醒',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
            macOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (error) {
        lastError = 'schedule: $error';
        debugPrint('Reminder could not be scheduled: $error');
      }
    }
  }

  /// Windows has no implementation in the plugin, and the web build has no
  /// scheduler at all.
  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
}

class _PendingReminder {
  _PendingReminder({
    required this.task,
    required this.day,
    required this.fireAt,
    this.followUp = 0,
  });

  /// 0 is the reminder itself; 1 and 2 are the nudges that follow it.
  final int followUp;

  /// Assigned once the whole schedule is ordered, so it reflects position
  /// across every task rather than within one.
  int badge = 0;

  final PlannerTask task;
  final DateTime day;
  final DateTime fireAt;

  /// Identifies this occurrence *at this time*: the fire time is part of the
  /// hash, so moving a task's time yields a different id. That is what lets
  /// the sync reconcile incrementally — an unchanged reminder keeps its id
  /// and is left untouched, while a changed one is cancelled and re-added.
  int get id =>
      Object.hash(
        task.id,
        PlannerTask.calendarDayKey(dateOnly(day)),
        fireAt.millisecondsSinceEpoch,
      ) &
      0x7fffffff;
}

/// A read-back of the live reminder state, for the settings diagnostics.
class ReminderDiagnostics {
  const ReminderDiagnostics({
    required this.supported,
    required this.permissionGranted,
    required this.pendingCount,
    this.timeZoneName = 'unresolved',
    this.lastError,
    this.alertsEnabled = false,
    this.soundEnabled = false,
    this.provisionalOnly = false,
    this.nextFireTimes = const [],
  });

  final bool supported;
  final bool permissionGranted;
  final int pendingCount;
  final String timeZoneName;
  final String? lastError;
  final bool alertsEnabled;
  final bool soundEnabled;
  final bool provisionalOnly;
  final List<DateTime> nextFireTimes;
}
