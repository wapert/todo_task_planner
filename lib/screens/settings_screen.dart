import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_integration.dart';
import '../providers/task_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/credential_store.dart';
import '../widgets/integration_tile.dart';
import '../widgets/panel.dart';

/// Offered only to Google accounts — the Calendar scope is granted during
/// Google sign-in, so no other account type can authorize this.
const PlannerIntegration _googleCalendar = PlannerIntegration(
  name: 'Google Calendar',
  displayName: 'Google 日曆',
  description: '將任務同步為 Google 日曆事件。',
  icon: Icons.calendar_month,
  status: IntegrationStatus.needsSetup,
);

/// Shown to Apple accounts. Unlike Google, this writes to the device's own
/// calendar (EventKit) rather than an account API — Apple grants no calendar
/// scope at sign-in — so it is gated by product choice, not by capability.
const PlannerIntegration _appleCalendar = PlannerIntegration(
  name: 'Apple Calendar',
  displayName: 'Apple 行事曆',
  description: '將任務同步到裝置的行事曆（含 iCloud）。',
  icon: Icons.event_available,
  status: IntegrationStatus.needsSetup,
);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    // Calendar sync is only offered for the provider the user actually signed
    // in with: syncing needs an authorization that only that sign-in grants,
    // so an email/password account has nothing to sync against.
    final integrations = <PlannerIntegration>[
      if (auth.isGoogleAccount) _googleCalendar,
      if (auth.isAppleAccount) _appleCalendar,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (integrations.isNotEmpty) ...[
            IntegrationPanel(
              integrations: integrations,
              onSetUp: (integration) => _setUpIntegration(context, integration),
            ),
            const SizedBox(height: 16),
          ],
          Panel(
            title: '帳號',
            icon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.email ?? '已登入'),
                const SizedBox(height: 2),
                Text(
                  '${auth.isAppleAccount
                      ? 'Apple 帳號'
                      : auth.isGoogleAccount
                      ? 'Google 帳號'
                      : '電子郵件帳號'}'
                  '（ID: ${auth.uid ?? '-'}）',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
                const SizedBox(height: 4),
                const _BiometricSignInTile(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('登出'),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  '刪除帳號後，所有任務資料會被永久移除，且無法復原。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9AA4B2)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteAccount(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFE6A6A0)),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('刪除帳號'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Signing out only swaps the home route over to the login screen, so this
  /// pushed route has to close itself first — otherwise it stays on top and
  /// the tap looks like it did nothing.
  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthService>();
    Navigator.of(context).pop();
    await auth.signOut();
  }

  /// Permanent account deletion, required by App Store guideline 5.1.1(v).
  ///
  /// Order matters: Firestore rules key off `request.auth.uid`, so the cloud
  /// data has to go *before* the auth account, or it would be stranded with no
  /// way to reach it again.
  Future<void> _deleteAccount(BuildContext context) async {
    final auth = context.read<AuthService>();
    final provider = context.read<TaskProvider>();
    final credentials = context.read<CredentialStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmDelete(context)) return;

    // Firebase refuses deletion unless the login is recent.
    try {
      if (auth.isAppleAccount) {
        await auth.reauthenticateWithApple();
      } else if (auth.isGoogleAccount) {
        await auth.reauthenticateWithGoogle();
      } else {
        if (!context.mounted) return;
        final password = await _askPasswordForDelete(context);
        if (password == null) return;
        await auth.reauthenticate(password);
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('身分驗證失敗：${AuthService.messageFor(error)}')),
      );
      return;
    }

    try {
      await provider.deleteAccountData();
      await credentials.clear();
      // Leave this route before the account goes away: it lives above the
      // provider AuthGate tears down on sign-out, so staying would strand a
      // screen watching a disposed TaskProvider.
      navigator.popUntil((route) => route.isFirst);
      await auth.deleteAccount();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('刪除帳號失敗：${AuthService.messageFor(error)}')),
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除帳號？'),
        content: const Text(
          '這會永久刪除你的帳號與所有任務資料，無法復原。\n\n'
          '如果只是想離開，請改用「登出」。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
            ),
            child: const Text('永久刪除'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<String?> _askPasswordForDelete(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認身分'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請輸入密碼以確認刪除帳號。', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '密碼',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
            ),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  Future<void> _setUpIntegration(
    BuildContext context,
    PlannerIntegration integration,
  ) async {
    if (integration.name == 'Google Calendar') {
      await _syncGoogleCalendar(context);
      return;
    }
    if (integration.name == 'Apple Calendar') {
      await _syncAppleCalendar(context);
      return;
    }
    showIntegrationSetup(context, integration);
  }

  Future<void> _syncAppleCalendar(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    try {
      final message = await provider.syncAppleCalendar();
      if (context.mounted) {
        _showResult(context, 'Apple 行事曆', message);
      }
    } catch (error) {
      if (context.mounted) {
        _showResult(context, 'Apple 行事曆', 'Apple 行事曆同步未能完成：$error');
      }
    }
  }

  Future<void> _syncGoogleCalendar(BuildContext context) async {
    final provider = context.read<TaskProvider>();
    try {
      final message = await provider.syncGoogleCalendar();
      if (context.mounted) {
        _showResult(context, 'Google 日曆', message);
      }
    } catch (error) {
      if (context.mounted) {
        _showResult(context, 'Google 日曆', 'Google 日曆設定未能完成：$error');
      }
    }
  }

  void _showResult(BuildContext context, String name, String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$name結果'),
          content: Text(message),
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
}

/// Toggles storing the password on this device so the user can sign back in
/// with biometrics after an explicit 登出.
class _BiometricSignInTile extends StatefulWidget {
  const _BiometricSignInTile();

  @override
  State<_BiometricSignInTile> createState() => _BiometricSignInTileState();
}

class _BiometricSignInTileState extends State<_BiometricSignInTile> {
  final _bio = BiometricService();
  bool? _available;
  bool _enabled = false;
  String _label = '生物辨識';

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    // Read the provider before any await so BuildContext isn't used across
    // an async gap.
    final store = context.read<CredentialStore>();
    final available = await _bio.isAvailable();
    final label = await _bio.methodLabel();
    final enabled = await store.hasCredentials();
    if (!mounted) return;
    setState(() {
      _available = available;
      _label = label;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool want) async {
    final store = context.read<CredentialStore>();
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    if (!want) {
      await store.clear();
      if (mounted) setState(() => _enabled = false);
      return;
    }

    // Enabling needs the password: Firebase never exposes it, so the user has
    // to re-enter it once. This also proves they own the account.
    final password = await _askPassword();
    if (password == null || !mounted) return;

    try {
      await auth.reauthenticate(password);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
      return;
    }

    final ok = await _bio.authenticate(reason: '驗證身分以開啟快速登入');
    if (!ok || !mounted) return;

    await store.save(auth.email ?? '', password);
    if (mounted) setState(() => _enabled = true);
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('開啟快速登入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '為了下次能用生物辨識登入，需要將密碼加密儲存在這台裝置上。\n'
              '密碼會存放在系統的安全儲存區，並且只有通過生物辨識才能讀取。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '密碼',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hidden entirely until the probe finishes, and on devices with no
    // screen lock at all where the option would be meaningless.
    if (_available != true) return const SizedBox.shrink();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _enabled,
      onChanged: _toggle,
      title: Text('使用 $_label 登入'),
      subtitle: const Text(
        '登出後可用生物辨識快速登入，密碼會加密儲存在本機。',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
