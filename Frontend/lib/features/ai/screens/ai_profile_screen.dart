// lib/features/ai/screens/ai_profile_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';
import 'package:beauty_commerce_app/features/ai/widgets/analysis_result_card.dart'
    as aiw;

class AiProfileScreen extends StatefulWidget {
  const AiProfileScreen({
    super.key,
    required this.accessToken,
    this.onOpenAnalyze,
    this.onRequireLogin,
    this.onDeleted,
  });

  /// JWT token is required to fetch the saved profile.
  final String accessToken;

  /// Navigate to the "Analyze" screen to create/update the profile.
  final VoidCallback? onOpenAnalyze;

  /// Called when token is invalid/expired and user needs to log in.
  final VoidCallback? onRequireLogin;

  /// Called after successful deletion of the profile.
  final VoidCallback? onDeleted;

  @override
  State<AiProfileScreen> createState() => _AiProfileScreenState();
}

class _AiProfileScreenState extends State<AiProfileScreen> {
  bool _loading = true;
  String? _error;
  _AiProfile? _profile;
  bool _deleting = false;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  // Handy actions with real navigation
  VoidCallback get _openAnalyze =>
      widget.onOpenAnalyze ?? () => context.pushNamed('ai_analyze');

  VoidCallback get _goLogin =>
      widget.onRequireLogin ?? () => context.goNamed('login');

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
      final uri = Uri.parse('$_baseUrl${Api.aiProfile}');
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(
          HttpHeaders.authorizationHeader, 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode == 401) {
        setState(() {
          _error = 'unauthorized';
          _loading = false;
          _profile = null;
        });
        return;
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final has = map['has_profile'] == true;
        if (!has) {
          setState(() {
            _profile = null;
            _loading = false;
          });
          return;
        }

        final profMap =
            (map['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
        // Backend saving code example:
        // { image_path, result (combined), merged, skin_type, updated_at, ... }
        final combined =
            (profMap['result'] as Map?)?.cast<String, dynamic>() ?? const {};

        // Prefer absolute image_url; else build from image_path when possible.
        String raw = (profMap['image_url'] ??
                profMap['imageUrl'] ??
                profMap['image_path'] ??
                profMap['imagePath'] ??
                '')
            .toString();
        final absImageUrl = _toAbsoluteUrl(raw);

        DateTime? updatedAt;
        final up = profMap['updated_at'];
        if (up is String) updatedAt = DateTime.tryParse(up);

        setState(() {
          _profile = _AiProfile(
            imageUrl: absImageUrl,
            combined: combined,
            updatedAt: updatedAt,
          );
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load your AI profile.';
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

  String? _toAbsoluteUrl(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    // Treat as a web path; ensure single slash
    final base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final path = v.startsWith('/') ? v : '/$v';
    return '$base$path';
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Face Analysis Profile?'),
        content: const Text(
          'This will remove your saved AI analysis and image from the server. '
          'You can create a new profile later.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.aiProfile}');
      final req = await client.deleteUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(
          HttpHeaders.authorizationHeader, 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        AppSnackbars.success(context, 'AI profile deleted');
        setState(() => _profile = null);
        widget.onDeleted?.call();
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(
            context, 'Session expired. Please log in again.');
        _goLogin();
      } else {
        AppSnackbars.error(context, 'Delete failed (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbars.error(context, 'Network problem. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'AI Profile'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Analyze new photo',
                  onPressed: _openAnalyze, // real navigation
                  fullWidth: true,
                ),
              ),
              if (_profile != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: _deleting ? 'Deleting...' : 'Delete profile',
                    onPressed: _deleting ? null : _deleteProfile,
                    fullWidth: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: _loading
          ? const _Skeleton()
          : (_error == 'unauthorized')
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.lock_outline,
                    title: 'Please sign in',
                    message: 'Your session has expired or is invalid.',
                    primaryActionLabel: 'Go to login',
                    onPrimaryAction: _goLogin, // real navigation
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
                  : (_profile == null)
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: EmptyState(
                            icon: Icons.face_retouching_natural_outlined,
                            title: 'No AI profile yet',
                            message:
                                'Analyze a face photo to get personalized recommendations.',
                            primaryActionLabel: 'Analyze now',
                            onPrimaryAction: _openAnalyze,
                          ),
                        )
                      : RefreshIndicator(
                          color: cs.primary,
                          onRefresh: _fetchProfile,
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              // Single card that shows image, saved/updated chips, and 4 horizontal sections
                              aiw.AnalysisResultCard.fromCombined(
                                combined: _profile!.combined,
                                imageUrl: _profile!.imageUrl,
                                saved: true, // it's a saved profile
                                updatedAt: _profile!.updatedAt,
                                // title: 'Your AI analysis', // optional
                              ),
                            ],
                          ),
                        ),
    );
  }
}

// -----------------------------------------------------------------------------
// Skeleton (loading)
// -----------------------------------------------------------------------------

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box({double h = 220}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        box(h: 260),
        const SizedBox(height: 16),
        box(h: 200),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Model for Profile (stores combined result)
// -----------------------------------------------------------------------------

class _AiProfile {
  final String? imageUrl; // absolute URL, if available
  final Map<String, dynamic> combined; // exact "combined" object
  final DateTime? updatedAt;

  _AiProfile({
    required this.imageUrl,
    required this.combined,
    required this.updatedAt,
  });
}
