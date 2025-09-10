// lib/features/account/screens/settings_screen.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/primary_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.accessToken,
    this.initialThemeMode = ThemeMode.system,
    this.initialNotifyOrders = true,
    this.initialNotifyPromos = false,
    this.onThemeModeChanged,
    this.onNotifyOrdersChanged,
    this.onNotifyPromosChanged,
    this.onOpenAbout,
    this.onOpenSupport,
  });

  /// JWT token for authenticated actions (used by "Delete Face Analysis Profile").
  final String? accessToken;

  /// Initial UI prefs.
  final ThemeMode initialThemeMode;
  final bool initialNotifyOrders;
  final bool initialNotifyPromos;

  /// Callbacks to propagate changes to app state.
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<bool>? onNotifyOrdersChanged;
  final ValueChanged<bool>? onNotifyPromosChanged;

  /// Optional navigation callbacks.
  final VoidCallback? onOpenAbout;
  final VoidCallback? onOpenSupport;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state
  late ThemeMode _themeMode;
  late bool _notifyOrders;
  late bool _notifyPromos;

  bool _deletingProfile = false;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _notifyOrders = widget.initialNotifyOrders;
    _notifyPromos = widget.initialNotifyPromos;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _saveAll() {
    widget.onThemeModeChanged?.call(_themeMode);
    widget.onNotifyOrdersChanged?.call(_notifyOrders);
    widget.onNotifyPromosChanged?.call(_notifyPromos);
    AppSnackbars.success(context, 'Settings saved');
  }

  String _extractServerMessage(String body, int status) {
    try {
      final m = (jsonDecode(body) as Map).cast<String, dynamic>();
      final msg = (m['error'] ?? m['message'] ?? m['detail'])?.toString();
      return (msg == null || msg.isEmpty) ? 'Error ($status).' : msg;
    } catch (_) {
      return 'Error ($status).';
    }
  }

  Future<void> _deleteAiProfile() async {
    final token = (widget.accessToken ?? '').trim();
    if (token.isEmpty) {
      AppSnackbars.warning(context, 'Please sign in to manage AI profile');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Face Analysis Profile?'),
        content: const Text(
          'This will remove your saved AI analysis and image from the server. '
          'You can create a new profile later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deletingProfile = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/ai/profile');
      final req = await client.deleteUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer $token');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'AI profile deleted');
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, _extractServerMessage(body, resp.statusCode));
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Please try again.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _deletingProfile = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI Helpers
  // ---------------------------------------------------------------------------

  Widget _sectionCard({required String title, Widget? trailing, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 16);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Settings'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: PrimaryButton(
            label: 'Save changes',
            onPressed: _saveAll,
            fullWidth: true,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Appearance
          _sectionCard(
            title: 'Appearance',
            children: [
              _ThemeModePicker(
                value: _themeMode,
                onChanged: (m) => setState(() => _themeMode = m),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notifications (Preferences without currency)
          _sectionCard(
            title: 'Notifications',
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Order updates'),
                subtitle: const Text('Get notifications about your order status'),
                value: _notifyOrders,
                onChanged: (v) => setState(() => _notifyOrders = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Promotions'),
                subtitle: const Text('Receive discounts and special offers'),
                value: _notifyPromos,
                onChanged: (v) => setState(() => _notifyPromos = v),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Privacy
          _sectionCard(
            title: 'Privacy',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  child: Icon(Icons.face_retouching_natural_outlined, color: cs.primary, size: 20),
                ),
                title: const Text('Delete Face Analysis Profile'),
                subtitle: const Text('Remove your saved AI skin analysis and photo'),
                trailing: PrimaryButton(
                  label: _deletingProfile ? 'Deleting...' : 'Delete',
                  onPressed: _deletingProfile ? null : _deleteAiProfile,
                  size: ButtonSize.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // About
          _sectionCard(
            title: 'About',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App'),
                subtitle: Text('${AppInfo.appName} • v${AppInfo.version}'),
                trailing: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                onTap: widget.onOpenAbout ??
                    () => AppSnackbars.info(context, '${AppInfo.appName} v${AppInfo.version}'),
              ),
              _divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Help & Support'),
                subtitle: const Text('FAQs, contact us'),
                trailing: Icon(Icons.help_outline, color: cs.onSurfaceVariant),
                onTap: widget.onOpenSupport ??
                    () => AppSnackbars.info(context, 'Open support'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme'),
        const SizedBox(height: 6),
        _RadioRow<ThemeMode>(
          options: const [
            _Option(label: 'System', value: ThemeMode.system),
            _Option(label: 'Light', value: ThemeMode.light),
            _Option(label: 'Dark', value: ThemeMode.dark),
          ],
          groupValue: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.options,
    required this.groupValue,
    required this.onChanged,
  });

  final List<_Option<T>> options;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: options
            .map(
              (opt) => RadioListTile<T>(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(opt.label),
                value: opt.value,
                groupValue: groupValue,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Option<T> {
  final String label;
  final T value;
  const _Option({required this.label, required this.value});
}
