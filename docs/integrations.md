# Integrations

## System Calendar Accounts

The primary calendar integration uses the calendars already signed in on the user's device.

- macOS/iOS: system calendars via EventKit.
- Android: system calendars via Android Calendar Provider.

This is similar to how Apple Calendar/Mail-style account setup works: the user signs into Google, iCloud, or another provider in system settings, then Todo Task Planner asks for calendar permission and writes task events to the calendar the user selects.

Required setup:

- Android requires `READ_CALENDAR` and `WRITE_CALENDAR`.
- iOS/macOS require Calendar usage descriptions.
- macOS sandbox builds require the Calendar personal-information entitlement.

## Direct Google Calendar

The app also includes direct Google Calendar sync plumbing in `lib/services/google_calendar_service.dart`.
It signs in with Google, requests Calendar edit access, and inserts each assigned task day as an event on the user's primary calendar.

Required setup:

1. Create an OAuth client in Google Cloud Console.
2. Enable the Google Calendar API.
3. Allow the Calendar scope:
   `https://www.googleapis.com/auth/calendar`
4. Build/run with your client ID:

```sh
flutter run -d chrome --dart-define=GOOGLE_OAUTH_CLIENT_ID="YOUR_CLIENT_ID"
```

For iOS and Android, also add the platform-specific Google Sign-In configuration files and URL schemes required by the `google_sign_in` package.

## Apple Mail

Apple Mail is being ignored for now. If it comes back later, it is not a Google-style OAuth provider. Real Apple Mail integration requires native work:

- macOS/iOS MailKit extension, or
- Share/import workflow from Mail into the planner, or
- a backend mailbox sync path for non-Apple mail accounts.

## Yahoo Mail

Yahoo Mail should be implemented with Yahoo OAuth plus IMAP/SMTP or a backend mail-sync service. Do not put a Yahoo client secret directly in the Flutter client.
