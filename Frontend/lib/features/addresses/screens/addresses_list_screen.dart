// lib/features/addresses/screens/addresses_list_screen.dart


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/primary_button.dart';

class AddressesListScreen extends StatefulWidget {
  const AddressesListScreen({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  State<AddressesListScreen> createState() => _AddressesListScreenState();
}

class _AddressesListScreenState extends State<AddressesListScreen> {
  bool _loading = true;
  String? _error;

  List<_Address> _items = const [];
  String? _selectedId; // default address id

  bool get _hasToken => widget.accessToken.isNotEmpty;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  @override
  void initState() {
    super.initState();
    if (_hasToken) {
      _fetch();
    } else {
      setState(() {
        _loading = false;
        _error = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Networking
  // ---------------------------------------------------------------------------

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.addresses}');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(body) as Map).cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => _Address.fromApi(m.cast<String, dynamic>()))
            .toList();

        setState(() {
          _items = list;
          _selectedId = _pickDefaultId(list);
          _loading = false;
        });
      } else if (resp.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load your addresses.';
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

  String? _pickDefaultId(List<_Address> list) {
    if (list.isEmpty) return null;
    try {
      final def = list.firstWhere((a) => a.isDefault);
      return def.id;
    } catch (_) {
      return list.first.id;
    }
  }

  Future<void> _setDefault(String id) async {
    // Backend: PUT /api/addresses/<id> with {"is_default": true}
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.addresses}/$id');
      final req = await client.putUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      req.add(utf8.encode(jsonEncode({'is_default': true})));
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() {
          _selectedId = id;
          // Update local flags to reflect server change:
          _items = _items
              .map((a) => a.copyWith(isDefault: a.id == id))
              .toList(growable: false);
        });
      } else {
        AppSnackbars.error(context, 'Could not set default (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _delete(String id) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.addresses}/$id');
      final req = await client.deleteUrl(uri);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
      final resp = await req.close();
      await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() {
          _items = _items.where((a) => a.id != id).toList();
          if (_selectedId == id) {
            _selectedId = _pickDefaultId(_items);
          }
        });
        AppSnackbars.success(context, 'Address deleted');
      } else {
        AppSnackbars.error(context, 'Delete failed (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _createOrUpdate({_Address? existing}) async {
    final result = await showModalBottomSheet<_AddressSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddressFormSheet(
        address: existing,
      ),
    );

    if (result == null) return;

    final payload = {
      'name': result.name,
      'line1': result.line1,
      'line2': result.line2,
      'city': result.city,
      'region': result.region,
      'postal_code': result.postalCode,
      'country': result.country,
      'phone': result.phone,
      'is_default': result.isDefault,
    };

    final client = HttpClient();
    try {
      if (existing == null) {
        // POST create
        final uri = Uri.parse('$_baseUrl${Api.addresses}');
        final req = await client.postUrl(uri);
        req.headers.set('Accept', 'application/json');
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
        req.add(utf8.encode(jsonEncode(payload)));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();

        if (!mounted) return;

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final map = (jsonDecode(body) as Map).cast<String, dynamic>();
          final created = _Address.fromApi(map);
          setState(() {
            _items = [created, ..._items];
            if (created.isDefault) {
              _selectedId = created.id;
              _items = _items.map((a) => a.copyWith(isDefault: a.id == created.id)).toList();
            }
          });
          AppSnackbars.success(context, 'Address added');
        } else {
          AppSnackbars.error(context, 'Create failed (${resp.statusCode}).');
        }
      } else {
        // PUT update
        final uri = Uri.parse('$_baseUrl${Api.addresses}/${existing.id}');
        final req = await client.putUrl(uri);
        req.headers.set('Accept', 'application/json');
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
        req.add(utf8.encode(jsonEncode(payload)));
        final resp = await req.close();
        await resp.transform(utf8.decoder).join();

        if (!mounted) return;

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          setState(() {
            _items = _items.map((a) {
              if (a.id == existing.id) {
                return existing.copyWith(
                  name: result.name,
                  line1: result.line1,
                  line2: result.line2,
                  city: result.city,
                  region: result.region,
                  postalCode: result.postalCode,
                  country: result.country,
                  phone: result.phone,
                  isDefault: result.isDefault,
                );
              }
              // If we set a new default, clear others:
              if (result.isDefault) {
                return a.copyWith(isDefault: a.id == existing.id);
              }
              return a;
            }).toList();
            if (result.isDefault) _selectedId = existing.id;
          });
          AppSnackbars.success(context, 'Address updated');
        } else {
          AppSnackbars.error(context, 'Update failed (${resp.statusCode}).');
        }
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) _delete(id);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'My addresses'),
      floatingActionButton: _hasToken
          ? FloatingActionButton.extended(
              onPressed: () => _createOrUpdate(),
              label: const Text('Add address'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: !_hasToken
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Log in to manage your saved addresses.',
                primaryActionLabel: 'Go to Login',
                onPrimaryAction: () => AppSnackbars.info(context, 'Navigate to Login'),
              ),
            )
          : _loading
              ? const _AddressesSkeleton()
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: 'Something went wrong',
                        message: _error ?? 'Please try again.',
                        primaryActionLabel: 'Retry',
                        onPrimaryAction: _fetch,
                      ),
                    )
                  : _items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: EmptyState(
                            icon: Icons.location_on_outlined,
                            title: 'No addresses yet',
                            message: 'Add an address to speed up checkout.',
                            primaryActionLabel: 'Add address',
                            onPrimaryAction: () => _createOrUpdate(),
                          ),
                        )
                      : RefreshIndicator(
                          color: cs.primary,
                          onRefresh: _fetch,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final a = _items[i];
                              final selected = a.id == _selectedId;
                              return InkWell(
                                onTap: () => _setDefault(a.id),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected ? cs.primary : cs.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Radio<String>(
                                        value: a.id,
                                        groupValue: _selectedId,
                                        onChanged: (v) => _setDefault(a.id),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    a.name.isEmpty ? '—' : a.name,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                                if (a.isDefault)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 8),
                                                    child: Chip(
                                                      label: const Text('Default'),
                                                      visualDensity: VisualDensity.compact,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatAddress(a),
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () => _createOrUpdate(existing: a),
                                                  icon: const Icon(Icons.edit_outlined),
                                                  label: const Text('Edit'),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: () => _confirmDelete(a.id),
                                                  icon: const Icon(Icons.delete_outline),
                                                  label: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }

  String _formatAddress(_Address a) {
    final parts = <String>[
      if (a.line1.isNotEmpty) a.line1,
      if (a.line2.isNotEmpty) a.line2,
      [a.city, a.region].where((e) => e.isNotEmpty).join(', '),
      if (a.postalCode.isNotEmpty) a.postalCode,
      if (a.country.isNotEmpty) a.country,
      if (a.phone.isNotEmpty) '☎ ${a.phone}',
    ].where((e) => e.trim().isNotEmpty).toList();
    return parts.join('\n');
  }
}

// ============================================================================
// Models
// ============================================================================

class _Address {
  final String id;
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;

  const _Address({
    required this.id,
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
    required this.isDefault,
  });

  factory _Address.fromApi(Map<String, dynamic> m) {
    return _Address(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      line1: (m['line1'] ?? '').toString(),
      line2: (m['line2'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      postalCode: (m['postal_code'] ?? '').toString(),
      country: (m['country'] ?? 'LK').toString(),
      phone: (m['phone'] ?? '').toString(),
      isDefault: m['is_default'] == true,
    );
  }

  _Address copyWith({
    String? id,
    String? name,
    String? line1,
    String? line2,
    String? city,
    String? region,
    String? postalCode,
    String? country,
    String? phone,
    bool? isDefault,
  }) {
    return _Address(
      id: id ?? this.id,
      name: name ?? this.name,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      region: region ?? this.region,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

// ============================================================================
// Bottom Sheet: Add / Edit Address
// ============================================================================

class _AddressSheetResult {
  const _AddressSheetResult({
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
    required this.phone,
    required this.isDefault,
  });

  final String name;
  final String line1;
  final String line2;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String phone;
  final bool isDefault;
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({required this.address});

  final _Address? address;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _postal;
  late final TextEditingController _country;
  late final TextEditingController _phone;

  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _name = TextEditingController(text: a?.name ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _line2 = TextEditingController(text: a?.line2 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _region = TextEditingController(text: a?.region ?? '');
    _postal = TextEditingController(text: a?.postalCode ?? '');
    _country = TextEditingController(text: a?.country ?? 'LK');
    _phone = TextEditingController(text: a?.phone ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _region.dispose();
    _postal.dispose();
    _country.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();

    if (name.isEmpty || line1.isEmpty || city.isEmpty) {
      AppSnackbars.warning(context, 'Please fill Name, Address line 1 and City.');
      return;
    }

    Navigator.of(context).pop(
      _AddressSheetResult(
        name: name,
        line1: line1,
        line2: _line2.text.trim(),
        city: city,
        region: _region.text.trim(),
        postalCode: _postal.text.trim(),
        country: _country.text.trim().isEmpty ? 'LK' : _country.text.trim().toUpperCase(),
        phone: _phone.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.address == null ? 'Add address' : 'Edit address',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _LabeledField(label: 'Full name*', controller: _name, textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                _LabeledField(label: 'Address line 1*', controller: _line1, textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                _LabeledField(label: 'Address line 2', controller: _line2, textInputAction: TextInputAction.next),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _LabeledField(label: 'City*', controller: _city, textInputAction: TextInputAction.next)),
                    const SizedBox(width: 10),
                    Expanded(child: _LabeledField(label: 'Region / State', controller: _region, textInputAction: TextInputAction.next)),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: _LabeledField(label: 'Postal code', controller: _postal, textInputAction: TextInputAction.next)),
                    const SizedBox(width: 10),
                    Expanded(child: _LabeledField(label: 'Country', controller: _country, textInputAction: TextInputAction.next)),
                  ],
                ),
                const SizedBox(height: 10),

                _LabeledField(
                  label: 'Phone',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Set as default'),
                  subtitle: Text(
                    'Use this address for future orders by default.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 14),

                PrimaryButton(
                  label: widget.address == null ? 'Add address' : 'Save changes',
                  onPressed: _submit,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============================================================================
// Skeleton
// ============================================================================

class _AddressesSkeleton extends StatelessWidget {
  const _AddressesSkeleton();

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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(20, 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(160, 16),
                  const SizedBox(height: 6),
                  bar(double.infinity, 14),
                  const SizedBox(height: 4),
                  bar(180, 14),
                ],
              ),
            ),
          ],
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: 5,
    );
  }
}
