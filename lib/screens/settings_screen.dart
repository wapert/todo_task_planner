import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../localization/app_locale.dart';
import '../models/planner_integration.dart';
import '../providers/task_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/credential_store.dart';
import '../services/notification_service.dart';
import '../widgets/integration_tile.dart';
import '../widgets/panel.dart';

const _backgroundPalette = <int>[
  0xFFFFFFFF, // white
  0xFFF8FAFC, // slate 50
  0xFFF9FAFB, // gray 50
  0xFFEFF6FF, // blue 50
  0xFFECFDF5, // emerald 50
  0xFFFFFBEB, // amber 50
  0xFFFFF7ED, // orange 50
  0xFFFFF1F2, // rose 50
  0xFFF5F3FF, // violet 50
];

const _toolbarPalette = <int>[
  0xFFD8DEE6, // soft slate
  0xFFB1DDEE, // soft sky
  0xFFBCD6F4, // soft blue
  0xFFAAE7D1, // soft emerald
  0xFFF3DB9C, // soft amber
  0xFFF2C5CB, // soft rose
  0xFFD4CEF4, // soft violet
  0xFFE2D1A7, // deep yellow, softened with light gray
  0xFFA8AECF, // deep blue, softened with light gray
  0xFFA5C2AD, // deep green, softened with light gray
  0xFFF6C49E, // vivid orange, softened with light gray
  0xCC123A63, // softened dark blue, 80% opacity
  0xCC0B4F3F, // softened dark green, 80% opacity
];

const _accentPalette = <int>[
  0xFFDC2626, // red 600
  0xFFEA580C, // orange 600
  0xFFEAB308, // yellow 500
  0xFF16A34A, // green 600
  0xFF2563EB, // blue 600
  0xFF9333EA, // purple 600
  0xFFDB2777, // pink 600
];

const _opacityChoices = <int>[100, 80, 60, 40, 20];

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

class _ColorSettingRow extends StatelessWidget {
  const _ColorSettingRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.allowMergeWithBackground = false,
  });

  final String label;
  final List<int> values;
  final Color selected;
  final ValueChanged<Color> onSelected;
  final bool allowMergeWithBackground;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < values.length; index++)
              _ColorDot(
                label: '$label ${index + 1}',
                color: Color(values[index]),
                selected: selected.toARGB32() == values[index],
                onTap: () => onSelected(Color(values[index])),
              ),
            if (allowMergeWithBackground)
              ChoiceChip(
                avatar: Icon(
                  selected.toARGB32() == 0
                      ? Icons.check
                      : Icons.layers_clear_outlined,
                  size: 17,
                ),
                label: Text(
                  context.tr('無顏色（與背景融合）', 'No color (blend with background)'),
                ),
                selected: selected.toARGB32() == 0,
                onSelected: (_) => onSelected(const Color(0x00000000)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF374151);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? const Color(0xFF374151) : Colors.black12,
              width: selected ? 3 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: selected
              ? Icon(Icons.check, size: 21, color: checkColor)
              : null,
        ),
      ),
    );
  }
}

class _OpacitySettingRow extends StatelessWidget {
  const _OpacitySettingRow({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opacity in _opacityChoices)
              ChoiceChip(
                label: Text('$opacity%'),
                selected: selected == opacity,
                onSelected: (_) => onSelected(opacity),
              ),
          ],
        ),
      ],
    );
  }
}

class _PriorityStyleSettingRow extends StatelessWidget {
  const _PriorityStyleSettingRow({
    required this.selected,
    required this.onSelected,
  });

  final PriorityColorStyle selected;
  final ValueChanged<PriorityColorStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = {
      PriorityColorStyle.textOnly: context.tr('僅文字顏色', 'Text only'),
      PriorityColorStyle.textBackground: context.tr(
        '文字背景顏色',
        'Text background',
      ),
      PriorityColorStyle.fill: context.tr('填滿顏色', 'Fill'),
      PriorityColorStyle.outline: context.tr('外框線顏色', 'Outline'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('優先度顯示樣式', 'Priority display style'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final style in const [
              PriorityColorStyle.textOnly,
              PriorityColorStyle.textBackground,
              PriorityColorStyle.fill,
              PriorityColorStyle.outline,
            ])
              ChoiceChip(
                label: Text(labels[style]!),
                selected: selected == style,
                onSelected: (_) => onSelected(style),
              ),
          ],
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final appearance = context.watch<TaskProvider>();
    // Calendar sync is only offered for the provider the user actually signed
    // in with: syncing needs an authorization that only that sign-in grants,
    // so an email/password account has nothing to sync against.
    final integrations = <PlannerIntegration>[
      if (auth.isGoogleAccount) _googleCalendar,
      if (auth.isAppleAccount) _appleCalendar,
    ];
    return Scaffold(
      backgroundColor: appearance.backgroundColor,
      appBar: AppBar(
        backgroundColor: appearance.effectiveToolbarColor,
        foregroundColor: appearance.toolbarForegroundColor,
        title: Text(context.tr('設定', 'Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            title: context.tr('語言', 'Language'),
            icon: Icons.language,
            child: SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.traditionalChinese,
                  label: Text(context.tr('繁體中文', 'Traditional Chinese')),
                ),
                ButtonSegment(
                  value: AppLanguage.english,
                  label: const Text('English'),
                ),
              ],
              selected: {context.appLocale.language},
              onSelectionChanged: (selection) => context
                  .read<AppLocaleController>()
                  .setLanguage(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          const _ReminderDiagnosticsPanel(),
          const SizedBox(height: 16),
          if (integrations.isNotEmpty) ...[
            IntegrationPanel(
              integrations: integrations,
              onSetUp: (integration) => _setUpIntegration(context, integration),
              calendarSyncEnabled: appearance.calendarSyncEnabled,
              onCalendarSyncChanged: (enabled) =>
                  _setCalendarSyncEnabled(context, enabled),
            ),
            const SizedBox(height: 16),
          ],
          Panel(
            title: context.tr('帳號', 'Account'),
            icon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.email ?? context.tr('已登入', 'Signed in')),
                const SizedBox(height: 2),
                Text(
                  '${auth.isAppleAccount
                      ? context.tr('Apple 帳號', 'Apple account')
                      : auth.isGoogleAccount
                      ? context.tr('Google 帳號', 'Google account')
                      : context.tr('電子郵件帳號', 'Email account')}'
                  '（ID: ${auth.uid ?? '-'}）',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
                const SizedBox(height: 12),
                const _AccountLinkingSection(),
                const SizedBox(height: 4),
                const _BiometricSignInTile(),
                const SizedBox(height: 12),
                if (auth.canResetPassword) ...[
                  OutlinedButton.icon(
                    onPressed: () => _sendPasswordReset(context),
                    icon: const Icon(Icons.lock_reset),
                    label: Text(context.tr('重設密碼', 'Reset password')),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: Text(context.tr('登出', 'Sign out')),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    '刪除帳號後，所有任務資料會被永久移除，且無法復原。',
                    'Deleting your account permanently removes all task data and cannot be undone.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA4B2),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteAccount(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFE6A6A0)),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(context.tr('刪除帳號', 'Delete account')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildColorSettings(context, appearance),
        ],
      ),
    );
  }

  Widget _buildColorSettings(BuildContext context, TaskProvider appearance) {
    return Panel(
      title: context.tr('顏色設定', 'Color settings'),
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ColorSettingRow(
            label: context.tr('背景顏色', 'Background color'),
            values: _backgroundPalette,
            selected: appearance.backgroundColor,
            onSelected: (color) =>
                appearance.updateAppearance(background: color),
          ),
          const SizedBox(height: 20),
          _ColorSettingRow(
            label: context.tr('工具列顏色（頂部＋底部）', 'Toolbar color (top + bottom)'),
            values: _toolbarPalette,
            selected: appearance.toolbarColor,
            allowMergeWithBackground: true,
            onSelected: (color) => appearance.updateAppearance(toolbar: color),
          ),
          const SizedBox(height: 20),
          _ColorSettingRow(
            label: context.tr('高優先度顏色', 'High priority color'),
            values: _accentPalette,
            selected: appearance.highPriorityColor,
            onSelected: (color) =>
                appearance.updateAppearance(priorityHigh: color),
          ),
          const SizedBox(height: 20),
          _ColorSettingRow(
            label: context.tr('中優先度顏色', 'Medium priority color'),
            values: _accentPalette,
            selected: appearance.mediumPriorityColor,
            onSelected: (color) =>
                appearance.updateAppearance(priorityMedium: color),
          ),
          const SizedBox(height: 20),
          _ColorSettingRow(
            label: context.tr('低優先度顏色', 'Low priority color'),
            values: _accentPalette,
            selected: appearance.lowPriorityColor,
            onSelected: (color) =>
                appearance.updateAppearance(priorityLow: color),
          ),
          const SizedBox(height: 20),
          _PriorityStyleSettingRow(
            selected: appearance.priorityColorStyle,
            onSelected: (style) =>
                appearance.updateAppearance(priorityStyle: style),
          ),
          const SizedBox(height: 20),
          _ColorSettingRow(
            label: context.tr('「新增任務」按鈕顏色', 'Add task button color'),
            values: _accentPalette,
            selected: appearance.addButtonColor,
            allowMergeWithBackground: true,
            onSelected: (color) =>
                appearance.updateAppearance(addButton: color),
          ),
          const SizedBox(height: 20),
          _OpacitySettingRow(
            label: context.tr('「新增任務」按鈕不透明度', 'Add task button opacity'),
            selected: appearance.addButtonOpacityPercent,
            onSelected: (opacity) =>
                appearance.updateAppearance(addButtonOpacity: opacity),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final auth = context.read<AuthService>();
    final email = auth.email;
    if (!auth.canResetPassword || email == null || email.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text('已寄送重設密碼郵件至 $email')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(error))),
      );
    }
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

  Future<void> _setCalendarSyncEnabled(
    BuildContext context,
    bool enabled,
  ) async {
    final provider = context.read<TaskProvider>();
    final name = provider.calendarSyncTarget == CalendarSyncTarget.apple
        ? 'Apple 行事曆'
        : 'Google 日曆';
    try {
      final message = await provider.setCalendarSyncEnabled(enabled);
      if (context.mounted) _showResult(context, name, message);
    } catch (error) {
      if (context.mounted) {
        _showResult(context, name, '無法變更自動同步設定：$error');
      }
    }
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

class _AccountLinkingSection extends StatefulWidget {
  const _AccountLinkingSection();

  @override
  State<_AccountLinkingSection> createState() => _AccountLinkingSectionState();
}

class _AccountLinkingSectionState extends State<_AccountLinkingSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final googleLinked = auth.isGoogleAccount;
    final passwordLinked = auth.hasPasswordProvider;
    if (!auth.isAppleAccount && googleLinked && passwordLinked) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('登入方式', 'Sign-in methods'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                '連結其他登入方式後，可在 Android 使用同一帳號及任務資料。',
                'Link another sign-in method to use the same account and tasks on Android.',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 10),
            _LinkedProviderRow(
              icon: Icons.apple,
              label: 'Apple',
              linked: auth.isAppleAccount,
            ),
            _LinkedProviderRow(
              icon: Icons.account_circle_outlined,
              label: 'Google',
              linked: googleLinked,
            ),
            _LinkedProviderRow(
              icon: Icons.alternate_email,
              label: context.tr('電子郵件與密碼', 'Email and password'),
              linked: passwordLinked,
            ),
            if (!googleLinked || !passwordLinked) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!googleLinked)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _linkGoogle,
                      icon: const Icon(Icons.add_link),
                      label: Text(context.tr('連結 Google', 'Link Google')),
                    ),
                  if (!passwordLinked)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _linkPassword,
                      icon: const Icon(Icons.password),
                      label: Text(context.tr('設定電子郵件密碼', 'Set email password')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _linkGoogle() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().linkGoogleAccount();
      if (!mounted) return;
      setState(() {});
      _showMessage(
        context.tr(
          'Google 帳號已連結，可在 Android 使用 Google 登入。',
          'Google account linked. You can now sign in with Google on Android.',
        ),
      );
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        _showMessage(
          context.tr(
            'Google 連結失敗：${error.description ?? error.code.name}',
            'Could not link Google: ${error.description ?? error.code.name}',
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkPassword() async {
    final values = await _showPasswordDialog();
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().linkEmailPassword(values.$1, values.$2);
      if (!mounted) return;
      setState(() {});
      _showMessage(
        context.tr(
          '電子郵件密碼已設定，可在 Android 使用此方式登入。',
          'Email password set. You can now use it to sign in on Android.',
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String)?> _showPasswordDialog() async {
    final auth = context.read<AuthService>();
    final emailController = TextEditingController(text: auth.email ?? '');
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('設定電子郵件密碼', 'Set email password')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(
                    '設定後請使用這個電子郵件和密碼在 Android 登入。',
                    'Use this email and password to sign in on Android.',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.tr('電子郵件', 'Email'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      '密碼（至少 6 個字元）',
                      'Password (at least 6 characters)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('確認密碼', 'Confirm password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (email.isEmpty || !email.contains('@')) {
                  setDialogState(
                    () => error = context.tr(
                      '請輸入有效的電子郵件',
                      'Enter a valid email address',
                    ),
                  );
                } else if (password.length < 6) {
                  setDialogState(
                    () => error = context.tr(
                      '密碼至少需要 6 個字元',
                      'Password must be at least 6 characters',
                    ),
                  );
                } else if (password != confirmController.text) {
                  setDialogState(
                    () => error = context.tr(
                      '兩次輸入的密碼不一致',
                      'Passwords do not match',
                    ),
                  );
                } else {
                  Navigator.of(dialogContext).pop((email, password));
                }
              },
              child: Text(context.tr('連結', 'Link')),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LinkedProviderRow extends StatelessWidget {
  const _LinkedProviderRow({
    required this.icon,
    required this.label,
    required this.linked,
  });

  final IconData icon;
  final String label;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Icon(
            linked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: linked ? const Color(0xFF16A34A) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            linked
                ? context.tr('已連結', 'Linked')
                : context.tr('未連結', 'Not linked'),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
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
    final authenticationReason = context.tr(
      '驗證身分以開啟快速登入',
      'Verify your identity to enable quick sign-in',
    );

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

    final ok = await _bio.authenticate(reason: authenticationReason);
    if (!ok || !mounted) return;

    await store.save(auth.email ?? '', password);
    if (mounted) setState(() => _enabled = true);
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('開啟快速登入', 'Enable quick sign-in')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                '為了下次能用生物辨識登入，需要將密碼加密儲存在這台裝置上。\n'
                    '密碼會存放在系統的安全儲存區，並且只有通過生物辨識才能讀取。',
                'Your encrypted password must be stored on this device for quick sign-in.\n'
                    'It is kept in secure system storage and can only be accessed after authentication.',
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('密碼', 'Password'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.tr('確定', 'Done')),
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
      title: Text(
        context.tr(
          '使用 $_label 登入',
          'Sign in with ${localizedDeviceAuthLabel(_label, english: true)}',
        ),
      ),
      subtitle: Text(
        context.tr(
          '登出後可用生物辨識快速登入，密碼會加密儲存在本機。',
          'Use secure authentication for quick sign-in. Your encrypted password stays on this device.',
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// Shows whether reminders can actually fire, and lets the user prove it.
///
/// A reminder that never arrives gives the user nothing to act on: permission
/// may be off, or nothing may be scheduled at all. This states both, and the
/// test button separates an OS/permission problem from a scheduling one.
class _ReminderDiagnosticsPanel extends StatefulWidget {
  const _ReminderDiagnosticsPanel();

  @override
  State<_ReminderDiagnosticsPanel> createState() =>
      _ReminderDiagnosticsPanelState();
}

class _ReminderDiagnosticsPanelState extends State<_ReminderDiagnosticsPanel> {
  ReminderDiagnostics? _diagnostics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final result = await NotificationService.instance.diagnose();
    if (!mounted) return;
    setState(() {
      _diagnostics = result;
      _loading = false;
    });
  }

  Future<void> _runSelfTest() async {
    await NotificationService.instance.scheduleSelfTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '已安排 15 秒後的測試提醒，請鎖定螢幕等待。',
            'A test reminder is set for 15 seconds from now — lock the screen and wait.',
          ),
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;
    return Panel(
      title: context.tr('提醒', 'Reminders'),
      icon: Icons.notifications_active_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading || diagnostics == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _DiagnosticRow(
              ok: diagnostics.permissionGranted,
              label: context.tr('通知權限', 'Notification permission'),
              value: diagnostics.permissionGranted
                  ? context.tr('已開啟', 'Granted')
                  : context.tr('未開啟', 'Not granted'),
            ),
            const SizedBox(height: 6),
            _DiagnosticRow(
              ok: diagnostics.pendingCount > 0,
              label: context.tr('已排程的提醒', 'Scheduled reminders'),
              value: '${diagnostics.pendingCount}',
            ),
            const SizedBox(height: 6),
            // Authorised but with alerts off is the state that looks exactly
            // like a broken app, so it gets its own row.
            _DiagnosticRow(
              ok: diagnostics.alertsEnabled,
              label: context.tr('可顯示通知', 'Alerts allowed'),
              value: diagnostics.alertsEnabled
                  ? context.tr('是', 'Yes')
                  : context.tr('否', 'No'),
            ),
            const SizedBox(height: 6),
            _DiagnosticRow(
              ok: diagnostics.soundEnabled,
              label: context.tr('聲音', 'Sound'),
              value: diagnostics.soundEnabled
                  ? context.tr('是', 'Yes')
                  : context.tr('否', 'No'),
            ),
            if (diagnostics.provisionalOnly) ...[
              const SizedBox(height: 6),
              _DiagnosticRow(
                ok: false,
                label: context.tr('僅安靜通知', 'Quiet delivery only'),
                value: context.tr('是', 'Yes'),
              ),
            ],
            const SizedBox(height: 6),
            _DiagnosticRow(
              ok: !diagnostics.timeZoneName.startsWith('fallback'),
              label: context.tr('時區', 'Time zone'),
              value: diagnostics.timeZoneName,
            ),
            if (diagnostics.nextFireTimes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('接下來的提醒：', 'Next reminders:'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              for (final time in diagnostics.nextFireTimes)
                Text(
                  '${time.year}/${time.month}/${time.day} '
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
            if (diagnostics.lastError != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                diagnostics.lastError!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB42318)),
              ),
            ],
            if (!diagnostics.permissionGranted) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  '通知權限未開啟，提醒不會響起。系統只會詢問一次，請到「設定 › 通知」開啟。',
                  'Notifications are off, so reminders cannot sound. iOS only asks once — turn them on in Settings › Notifications.',
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr('重新檢查', 'Re-check')),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _runSelfTest,
                icon: const Icon(Icons.notifications, size: 18),
                label: Text(context.tr('測試提醒', 'Test reminder')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.ok,
    required this.label,
    required this.value,
  });

  final bool ok;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: ok ? const Color(0xFF16A34A) : const Color(0xFFB42318),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
