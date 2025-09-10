// lib/features/account/screens/account_home_screen.dart
//

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../app/app_router.dart'; // for AppRouter.setAccessToken(null)
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/logout_button.dart';

class AccountHomeScreen extends StatefulWidget {
  const AccountHomeScreen({
    super.key,
    required this.accessToken,
    this.onOpenOrders,
    this.onOpenAddresses,
    this.onOpenWishlist,
    this.onOpenSettings,
    this.onOpenSupport, // if null, the tile is hidden
    this.onSignOut,
    this.onRequireLogin,
  });

  /// JWT token. If invalid/expired, screen will show an "unauthorized" state.
  final String accessToken;

  // Optional navigation callbacks – if not provided, default GoRouter navigation is used.
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenAddresses;
  final VoidCallback? onOpenWishlist;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenSupport;

  /// Called after the user confirms sign-out. If null, defaults to:
  /// AppRouter.setAccessToken(null); context.goNamed('login');
  final VoidCallback? onSignOut;

  /// Called when token is invalid/expired. If null, defaults to context.goNamed('login').
  final VoidCallback? onRequireLogin;

  @override
  State<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends State<AccountHomeScreen> {
  bool _loading = true;
  String? _error;
  _User? _user;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.authMe}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final u = _User.fromApi((map['user'] as Map?)?.cast<String, dynamic>() ?? {});
        setState(() {
          _user = u;
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() {
          _error = 'unauthorized';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load your profile.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please try again.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to log in again to access your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      if (widget.onSignOut != null) {
        widget.onSignOut!();
      } else {
        // Default sign-out behavior
        AppRouter.setAccessToken(null);
        if (mounted) context.goNamed('login');
      }
    }
  }

  // UI helpers
  Widget _buildHeader(_User u) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primary.withOpacity(0.12),
            child: Icon(Icons.person_outline, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name.isEmpty ? 'Your Account' : u.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  u.email.isEmpty ? '—' : u.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (iconColor ?? cs.primary).withOpacity(0.12),
              child: Icon(icon, color: iconColor ?? cs.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Default navigation helpers using named routes
  VoidCallback _navToOrders() =>
      widget.onOpenOrders ?? () => context.pushNamed('orders');

  VoidCallback _navToAddresses() =>
      widget.onOpenAddresses ?? () => context.pushNamed('addresses');

  VoidCallback _navToWishlist() =>
      widget.onOpenWishlist ?? () => context.pushNamed('wishlist');

  VoidCallback _navToSettings() =>
      widget.onOpenSettings ?? () => context.pushNamed('settings');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'Account'),
      body: _loading
          ? const _AccountSkeleton()
          : (_error == 'unauthorized')
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.lock_outline,
                    title: 'Please sign in',
                    message: 'Your session has expired or is invalid.',
                    primaryActionLabel: 'Go to login',
                    onPrimaryAction:
                        widget.onRequireLogin ?? () => context.goNamed('login'),
                  ),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Something went wrong',
                        message: _error ?? 'Please try again.',
                        primaryActionLabel: 'Retry',
                        onPrimaryAction: _fetchProfile,
                      ),
                    )
                  : RefreshIndicator(
                      color: cs.primary,
                      onRefresh: _fetchProfile,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          if (_user != null) _buildHeader(_user!),
                          const SizedBox(height: 16),

                          _tile(
                            icon: Icons.receipt_long_outlined,
                            title: 'My orders',
                            subtitle: 'Track, return or buy again',
                            onTap: _navToOrders(),
                          ),
                          const SizedBox(height: 10),
                          _tile(
                            icon: Icons.location_on_outlined,
                            title: 'Addresses',
                            subtitle: 'Manage delivery addresses',
                            onTap: _navToAddresses(),
                          ),
                          const SizedBox(height: 10),
                          _tile(
                            icon: Icons.favorite_border,
                            title: 'Wishlist',
                            subtitle: 'Your saved items',
                            onTap: _navToWishlist(),
                          ),
                          const SizedBox(height: 10),
                          _tile(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'Preferences, currency, theme',
                            onTap: _navToSettings(),
                          ),
                          const SizedBox(height: 10),

                          // Optional Help & Support tile: shown only if a handler is provided.
                          if (widget.onOpenSupport != null)
                            _tile(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              subtitle: 'FAQs, contact us',
                              onTap: widget.onOpenSupport,
                            ),

                          const SizedBox(height: 20),

                          // Sign out
                          LogoutButton(
                            onPressed: _confirmSignOut,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

// ============================================================================
// Model
// ============================================================================

class _User {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  _User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory _User.fromApi(Map<String, dynamic> m) {
    DateTime? _toDt(v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return _User(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      email: (m['email'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      isActive: m['is_active'] == true,
      createdAt: _toDt(m['created_at']),
    );
  }
}

// ============================================================================
// Skeleton
// ============================================================================

class _AccountSkeleton extends StatelessWidget {
  const _AccountSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box({double h = 84}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(cs, 140, 16),
                    const SizedBox(height: 8),
                    _bar(cs, 180, 14),
                  ],
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        box(h: 92),
        const SizedBox(height: 16),
        box(),
        const SizedBox(height: 10),
        box(),
        const SizedBox(height: 10),
        box(),
        const SizedBox(height: 10),
        box(),
      ],
    );
  }

  static Widget _bar(ColorScheme cs, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
