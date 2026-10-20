import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

import 'auth_service.dart';
import 'google_auth_config.dart';
import 'task_event.dart';

class GoogleCalendarService {
  GoogleCalendarService();

  static const List<String> scopes = googleCalendarScopes;

  Future<void> initialize() => AuthService.ensureGoogleInitialized();

  Future<void> requestPermission() async {
    await initialize();
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication() ??
        await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
  }

  Future<String> createEvents(
    List<TaskCalendarEvent> events, {
    required CalendarEventSynced onEventSynced,
    bool updateExisting = false,
  }) async {
    final eventsToSync = updateExisting
        ? events
        : events.where((event) => event.externalEventId == null).toList();
    if (eventsToSync.isEmpty) return '沒有新事件。';

    await initialize();

    // The account already consented to the Calendar scope during Google
    // sign-in, so this normally resolves silently from cache. Only fall back
    // to an interactive prompt if that has lapsed.
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication() ??
        await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);

    final client = authorization.authClient(scopes: scopes);
    try {
      final api = calendar.CalendarApi(client);
      var created = 0;
      var updated = 0;
      for (final taskEvent in eventsToSync) {
        final existingId = taskEvent.externalEventId;
        final syncedEvent = existingId == null
            ? await api.events.insert(_toGoogleEvent(taskEvent), 'primary')
            : await api.events.update(
                _toGoogleEvent(taskEvent),
                'primary',
                existingId,
              );
        if (existingId == null) {
          created++;
        } else {
          updated++;
        }
        final eventId = syncedEvent.id ?? existingId;
        if (eventId != null) await onEventSynced(taskEvent, eventId);
      }
      return 'Google 日曆同步完成：新增 $created 個，更新 $updated 個事件。';
    } finally {
      client.close();
    }
  }

  Future<void> deleteEvents(Iterable<String> eventIds) async {
    final ids = eventIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    await initialize();
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication() ??
        await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    final client = authorization.authClient(scopes: scopes);
    try {
      final api = calendar.CalendarApi(client);
      for (final id in ids) {
        await api.events.delete('primary', id);
      }
    } finally {
      client.close();
    }
  }

  calendar.Event _toGoogleEvent(TaskCalendarEvent taskEvent) {
    final event = calendar.Event(
      summary: taskEvent.title,
      description: taskEvent.notes.isEmpty ? null : taskEvent.notes,
    );

    final time = taskEvent.time;
    if (time == null) {
      event.start = calendar.EventDateTime(
        date: _dateOnly(taskEvent.day),
        timeZone: DateTime.now().timeZoneName,
      );
      event.end = calendar.EventDateTime(
        date: _dateOnly(taskEvent.day.add(const Duration(days: 1))),
        timeZone: DateTime.now().timeZoneName,
      );
    } else {
      final start = DateTime(
        taskEvent.day.year,
        taskEvent.day.month,
        taskEvent.day.day,
        time.hour,
        time.minute,
      );
      event.start = calendar.EventDateTime(
        dateTime: start,
        timeZone: DateTime.now().timeZoneName,
      );
      event.end = calendar.EventDateTime(
        dateTime: start.add(const Duration(hours: 1)),
        timeZone: DateTime.now().timeZoneName,
      );
    }

    return event;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class GoogleCalendarConfigurationException implements Exception {
  const GoogleCalendarConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
