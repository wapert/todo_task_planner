import 'package:flutter/material.dart';

import '../models/planner_integration.dart';
import 'panel.dart';

class IntegrationPanel extends StatelessWidget {
  const IntegrationPanel({
    super.key,
    required this.integrations,
    required this.onSetUp,
    this.connectedCalendarName,
    this.onChangeCalendar,
    this.onDisconnectCalendar,
  });

  final List<PlannerIntegration> integrations;
  final ValueChanged<PlannerIntegration> onSetUp;
  final String? connectedCalendarName;
  final VoidCallback? onChangeCalendar;
  final VoidCallback? onDisconnectCalendar;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: '連結',
      icon: Icons.hub_outlined,
      child: Column(
        children: integrations
            .map(
              (integration) => IntegrationTile(
                integration: integration,
                onSetUp: onSetUp,
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
    this.connectedCalendarName,
    this.onChangeCalendar,
    this.onDisconnectCalendar,
  });

  final PlannerIntegration integration;
  final ValueChanged<PlannerIntegration> onSetUp;
  final String? connectedCalendarName;
  final VoidCallback? onChangeCalendar;
  final VoidCallback? onDisconnectCalendar;

  @override
  Widget build(BuildContext context) {
    final ready = integration.status == IntegrationStatus.ready;
    final showCalendarActions =
        ready && (onChangeCalendar != null || onDisconnectCalendar != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E8F0)),
        ),
        child: ListTile(
          leading: Icon(integration.icon, color: const Color(0xFF2563EB)),
          title: Text(
            integration.displayName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            ready && connectedCalendarName != null
                ? '${integration.description}\n已連結：$connectedCalendarName'
                : integration.description,
          ),
          isThreeLine: ready && connectedCalendarName != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => onSetUp(integration),
                icon: Icon(ready ? Icons.check_circle : Icons.lock_open),
                label: Text(ready ? '同步' : '設定'),
              ),
              if (showCalendarActions)
                PopupMenuButton<VoidCallback>(
                  tooltip: '更多選項',
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    if (onChangeCalendar != null)
                      PopupMenuItem(
                        value: onChangeCalendar,
                        child: const Text('變更日曆'),
                      ),
                    if (onDisconnectCalendar != null)
                      PopupMenuItem(
                        value: onDisconnectCalendar,
                        child: const Text('中斷連結'),
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
        title: Text('${integration.displayName}設定'),
        content: Text(integrationSetupMessage(integration.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

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
