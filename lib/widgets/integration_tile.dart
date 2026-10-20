import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../models/planner_integration.dart';
import '../providers/task_provider.dart';
import 'panel.dart';

class IntegrationPanel extends StatelessWidget {
  const IntegrationPanel({
    super.key,
    required this.integrations,
    required this.onSetUp,
    this.calendarSyncEnabled,
    this.onCalendarSyncChanged,
    this.connectedCalendarName,
    this.onChangeCalendar,
    this.onDisconnectCalendar,
  });

  final List<PlannerIntegration> integrations;
  final ValueChanged<PlannerIntegration> onSetUp;
  final bool? calendarSyncEnabled;
  final ValueChanged<bool>? onCalendarSyncChanged;
  final String? connectedCalendarName;
  final VoidCallback? onChangeCalendar;
  final VoidCallback? onDisconnectCalendar;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.tr('連結', 'Connections'),
      icon: Icons.hub_outlined,
      child: Column(
        children: integrations
            .map(
              (integration) => IntegrationTile(
                integration: integration,
                onSetUp: onSetUp,
                calendarSyncEnabled: calendarSyncEnabled,
                onCalendarSyncChanged: onCalendarSyncChanged,
                connectedCalendarName: integration.name == 'Calendar Accounts'
                    ? connectedCalendarName
                    : null,
                onChangeCalendar: integration.name == 'Calendar Accounts'
                    ? onChangeCalendar
                    : null,
                onDisconnectCalendar: integration.name == 'Calendar Accounts'
                    ? onDisconnectCalendar
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }
}

class IntegrationTile extends StatelessWidget {
  const IntegrationTile({
    super.key,
    required this.integration,
    required this.onSetUp,
    this.calendarSyncEnabled,
    this.onCalendarSyncChanged,
    this.connectedCalendarName,
    this.onChangeCalendar,
    this.onDisconnectCalendar,
  });

  final PlannerIntegration integration;
  final ValueChanged<PlannerIntegration> onSetUp;
  final bool? calendarSyncEnabled;
  final ValueChanged<bool>? onCalendarSyncChanged;
  final String? connectedCalendarName;
  final VoidCallback? onChangeCalendar;
  final VoidCallback? onDisconnectCalendar;

  @override
  Widget build(BuildContext context) {
    final background = context.watch<TaskProvider>().backgroundColor;
    final ready = integration.status == IntegrationStatus.ready;
    final isCalendar = integration.name.contains('Calendar');
    final showCalendarActions =
        ready && (onChangeCalendar != null || onDisconnectCalendar != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E8F0)),
        ),
        child: ListTile(
          leading: Icon(integration.icon, color: const Color(0xFF2563EB)),
          title: Text(
            context.isEnglish
                ? _englishName(integration.name)
                : integration.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            ready && connectedCalendarName != null
                ? context.tr(
                    '${integration.description}\n已連結：$connectedCalendarName',
                    '${_englishDescription(integration.name)}\nConnected: $connectedCalendarName',
                  )
                : context.isEnglish
                ? _englishDescription(integration.name)
                : integration.description,
          ),
          isThreeLine: ready && connectedCalendarName != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCalendar && onCalendarSyncChanged != null)
                Switch(
                  value: calendarSyncEnabled ?? false,
                  onChanged: onCalendarSyncChanged,
                )
              else
                OutlinedButton.icon(
                  onPressed: () => onSetUp(integration),
                  icon: Icon(
                    isCalendar
                        ? Icons.sync
                        : ready
                        ? Icons.check_circle
                        : Icons.lock_open,
                  ),
                  label: Text(
                    isCalendar || ready
                        ? context.tr('同步', 'Sync')
                        : context.tr('設定', 'Set up'),
                  ),
                ),
              if (showCalendarActions)
                PopupMenuButton<VoidCallback>(
                  tooltip: context.tr('更多選項', 'More options'),
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    if (onChangeCalendar != null)
                      PopupMenuItem(
                        value: onChangeCalendar,
                        child: Text(context.tr('變更日曆', 'Change calendar')),
                      ),
                    if (onDisconnectCalendar != null)
                      PopupMenuItem(
                        value: onDisconnectCalendar,
                        child: Text(context.tr('中斷連結', 'Disconnect')),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void showIntegrationSetup(
  BuildContext context,
  PlannerIntegration integration,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          context.tr(
            '${integration.displayName}設定',
            '${_englishName(integration.name)} setup',
          ),
        ),
        content: Text(
          context.isEnglish
              ? _englishSetupMessage(integration.name)
              : integrationSetupMessage(integration.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('關閉', 'Close')),
          ),
        ],
      );
    },
  );
}

String _englishName(String name) => switch (name) {
  'Calendar Accounts' => 'Calendar Accounts',
  'Google Calendar' => 'Google Calendar',
  'Apple Mail' => 'Apple Mail',
  'Yahoo Mail' => 'Yahoo Mail',
  _ => name,
};

String _englishDescription(String name) => switch (name) {
  'Calendar Accounts' =>
    'Sync tasks to your device calendars, including iCloud.',
  'Google Calendar' => 'Sync tasks as Google Calendar events.',
  _ => 'Connect this service to sync data.',
};

String _englishSetupMessage(String name) => switch (name) {
  'Google Calendar' =>
    'Google OAuth credentials and Calendar API access are required to sync.',
  'Apple Mail' =>
    'Native macOS/iOS mail integration and platform-specific permission are required.',
  'Yahoo Mail' =>
    'Yahoo OAuth credentials and mail access are required to turn email into tasks.',
  _ =>
    'Provider credentials and a secure sign-in flow are required to sync data.',
};

String integrationSetupMessage(String name) {
  return switch (name) {
    'Google Calendar' =>
      '需要 Google OAuth 憑證與日曆 API 存取權限才能同步。請先設定用戶端 ID、申請日曆權限範圍，再連結任務到日曆事件。',
    'Apple Mail' =>
      '需要 macOS/iOS 原生郵件整合。Apple Mail 沒有簡易的跨平台 OAuth API，須以平台專屬權限或分享/匯入流程實作。',
    'Yahoo Mail' =>
      '需要 Yahoo OAuth 憑證與郵件存取流程，才能將郵件轉換為任務。請先在後端或安全的原生流程中設定用戶端 ID/密鑰。',
    _ => '此連結需要服務提供者憑證與安全登入流程才能同步資料。',
  };
}
