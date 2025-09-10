// lib/features/cart/screens/payment_method_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    super.key,
    this.accessToken,
    this.amount,
    this.currency,
    this.initialMethod = 'cod', // 'cod' | 'card'
  });

  /// JWT access token. Required if user selects "Card" (for create-intent).
  final String? accessToken;

  /// Optional known amount. If null, we try to fetch from /api/cart (JWT required).
  final double? amount;

  /// Optional currency code (e.g., 'LKR'). If null, try to fetch from /api/cart.
  final String? currency;

  /// Initial selected method: 'cod' or 'card'.
  final String initialMethod;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // Local copy of amount/currency (may be fetched)
  double? _amount;
  String? _currency;

  // UI state
  String _selected = 'cod';
  bool _loading = false;       // loading amount (when missing)
  bool _creating = false;      // creating payment intent
  String? _error;              // loading error

  // Inlined endpoint to avoid undefined constant errors.
  static const String _paymentsCreateIntentPath = '/api/payments/create-intent';

  bool get _hasToken => (widget.accessToken ?? '').isNotEmpty;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  @override
  void initState() {
    super.initState();
    _selected = (widget.initialMethod == 'card') ? 'card' : 'cod';
    _amount = widget.amount;
    _currency = widget.currency;
    if (_amount == null || _currency == null) {
      _tryLoadAmountFromCart();
    }
  }

  Future<void> _tryLoadAmountFromCart() async {
    if (!_hasToken) return; // Can't fetch cart without JWT; still allow COD flow.
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.cart}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final pricing = (map['pricing'] as Map?)?.cast<String, dynamic>();
        if (pricing != null) {
          setState(() {
            _amount = _toD(pricing['total']);
            _currency = (pricing['currency'] ?? 'LKR').toString();
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Pricing unavailable.';
            _loading = false;
          });
        }
      } else if (resp.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load cart total.';
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

  Future<void> _createPaymentIntentAndReturn() async {
    if (_creating) return;

    if (!_hasToken) {
      AppSnackbars.info(context, 'Please log in to pay by card.', title: 'Sign-in required');
      return;
    }
    final amt = _amount ?? 0.0; // backend accepts any double; this is a mock anyway
    setState(() => _creating = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl$_paymentsCreateIntentPath');
      final req = await client.postUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      req.add(utf8.encode(jsonEncode({'amount': amt})));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final secret = (map['client_secret'] ?? '').toString();
        Navigator.of(context).pop(
          PaymentMethodResult(
            method: 'card',
            clientSecret: secret,
            amount: amt,
            currency: _currency ?? 'LKR',
          ),
        );
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, 'Payment could not be initialized (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Please try again.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _creating = false);
    }
  }

  void _useCodAndReturn() {
    Navigator.of(context).pop(
      PaymentMethodResult(
        method: 'cod',
        amount: _amount,
        currency: _currency,
      ),
    );
  }

  String _amountText() {
    final cur = _currency ?? 'LKR';
    final amt = _amount;
    if (amt == null) return '—';
    return '$cur ${amt.toStringAsFixed(2)}';
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrimary(title: 'Payment method'),
      body: _loading
          ? const _Skeleton()
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Couldn’t load total',
                    message: _error ?? 'Please try again.',
                    primaryActionLabel: 'Retry',
                    onPrimaryAction: _tryLoadAmountFromCart,
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          _TotalCard(text: _amountText()),
                          const SizedBox(height: 12),
                          _MethodTile(
                            title: 'Cash on Delivery',
                            subtitle: 'Pay with cash when your order arrives.',
                            icon: Icons.payments_outlined,
                            value: 'cod',
                            groupValue: _selected,
                            onChanged: (v) => setState(() => _selected = v),
                          ),
                          const SizedBox(height: 8),
                          _MethodTile(
                            title: 'Card (Mock)',
                            subtitle: 'Test card payment via create-intent.',
                            icon: Icons.credit_card,
                            value: 'card',
                            groupValue: _selected,
                            onChanged: (v) => setState(() => _selected = v),
                          ),
                          const SizedBox(height: 8),
                          // Add more options later (e.g., wallet)
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Payable', style: Theme.of(context).textTheme.labelMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                    _amountText(),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 180,
                              child: PrimaryButton(
                                label: _selected == 'card'
                                    ? (_creating ? 'Processing…' : 'Continue to pay')
                                    : 'Use COD',
                                onPressed: _selected == 'card'
                                    ? (_creating ? null : _createPaymentIntentAndReturn)
                                    : _useCodAndReturn,
                                fullWidth: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  double _toD(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
}

// ============================================================================
// Result object returned to caller
// ============================================================================
class PaymentMethodResult {
  PaymentMethodResult({
    required this.method, // 'cod' | 'card'
    this.clientSecret,   // only for 'card'
    this.amount,
    this.currency,
  });

  final String method;
  final String? clientSecret;
  final double? amount;
  final String? currency;
}

// ============================================================================
// UI pieces
// ============================================================================

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Text('Total to pay', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v ?? value),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    Widget box() => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              bar(36, 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(120, 14),
                    const SizedBox(height: 6),
                    bar(180, 12),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              bar(20, 20),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        bar(double.infinity, 52),
        const SizedBox(height: 12),
        box(),
        const SizedBox(height: 8),
        box(),
        const SizedBox(height: 8),
        box(),
      ],
    );
  }
}
