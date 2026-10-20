import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'task_event.dart';

/// Writes task events into the device's calendar database (EventKit on iOS).
///
/// This is *not* tied to Sign in with Apple — Apple grants no calendar scope,
/// and there is no Apple Calendar web API. Access comes from the OS permission
/// prompt, and the target is whichever calendar the device has set as default,
/// which for most people is their iCloud calendar.
class AppleCalendarService {
  final dc.DeviceCalendarPlugin _plugin = dc.DeviceCalendarPlugin();
  bool _timezonesReady = false;

  Future<void> _ensureTimezones() async {
    if (_timezonesReady) return;
    tz_data.initializeTimeZones();
    _timezonesReady = true;
  }

  Future<bool> _ensurePermission() async {
    final granted = await _plugin.hasPermissions();
    if (granted.isSuccess && granted.data == true) return true;
    final requested = await _plugin.requestPermissions();
    return requested.isSuccess && requested.data == true;
  }

  Future<void> requestPermission() async {
    if (!await _ensurePermission()) {
      throw const AppleCalendarException('未取得行事曆存取權限，請到「設定」開啟權限後再試一次。');
    }
  }

  /// Creates one event per task-day. Returns a message for the result dialog.
  Future<String> createEvents(
    List<TaskCalendarEvent> events, {
    required CalendarEventSynced onEventSynced,
    bool updateExisting = false,
  }) async {
    final eventsToSync = updateExisting
        ? events
        : events.where((event) => event.externalEventId == null).toList();
    if (eventsToSync.isEmpty) return '沒有新事件。';
    if (!await _ensurePermission()) {
      throw const AppleCalendarException('未取得行事曆存取權限，請到「設定」開啟權限後再試一次。');
    }
    await _ensureTimezones();

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? <dc.Calendar>[];
    final writable = calendars.where((c) => c.isReadOnly != true).toList();
    if (writable.isEmpty) {
      throw const AppleCalendarException('找不到可寫入的行事曆，請先在系統設定中新增行事曆帳號。');
    }
    final target = writable.firstWhere(
      (c) => c.isDefault == true,
      orElse: () => writable.first,
    );

    final location = tz.local;
    var created = 0;
    var updated = 0;
    for (final taskEvent in eventsToSync) {
      final time = taskEvent.time;
      final day = taskEvent.day;
      final start = tz.TZDateTime(
        location,
        day.year,
        day.month,
        day.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
      final event = dc.Event(
        target.id,
        eventId: taskEvent.externalEventId,
        title: taskEvent.title,
        description: taskEvent.notes.isEmpty ? null : taskEvent.notes,
        start: start,
        end: start.add(const Duration(hours: 1)),
        // Tasks with no time become all-day entries rather than pinning them
        // to an arbitrary hour on the user's calendar.
        allDay: time == null,
      );
      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        if (taskEvent.externalEventId == null) {
          created++;
        } else {
          updated++;
        }
        await onEventSynced(taskEvent, result!.data!);
      }
    }

    if (created == 0) {
      throw const AppleCalendarException('建立行事曆事件失敗，請稍後再試。');
    }
    return '「${target.name ?? '行事曆'}」同步完成：新增 $created 個，更新 $updated 個事件。';
  }

  Future<void> deleteEvents(Iterable<String> eventIds) async {
    final ids = eventIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    if (!await _ensurePermission()) {
      throw const AppleCalendarException('未取得行事曆存取權限，無法刪除已同步的事件。');
    }
    final calendars =
        (await _plugin.retrieveCalendars()).data ?? <dc.Calendar>[];
    for (final eventId in ids) {
      for (final calendar in calendars) {
        final result = await _plugin.deleteEvent(calendar.id, eventId);
        if (result.isSuccess && result.data == true) break;
      }
    }
  }
}

class AppleCalendarException implements Exception {
  const AppleCalendarException(this.message);

  final String message;

  @override
  String toString() => message;
}
