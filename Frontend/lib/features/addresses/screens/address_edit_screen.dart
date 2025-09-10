// lib/features/addresses/screens/address_edit_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/app_constants.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/primary_button.dart';
import '../../../common/utils/snackbar.dart';

class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({
    super.key,
    required this.accessToken,
    this.address,
    this.addressId, // <--- NEW: allows route to pass only the id
  });

  /// JWT access token (required for POST/PUT/GET).
  final String accessToken;

  /// If provided, the screen will be in "edit" mode with this object.
  final AddressData? address;

  /// Optional: if only an id is available (from router param), we'll fetch the
  /// address list and prefill the form by matching this id.
  final String? addressId;

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _postal;
  late final TextEditingController _country;
  late final TextEditingController _phone;

  bool _isDefault = false;
  bool _saving = false;
  bool _loadingPrefill = false; // <--- NEW: for fetch-by-id flow

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  bool get _isEdit {
    if (widget.address != null) return true;
    if (widget.addressId != null && widget.addressId!.isNotEmpty) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    // Init controllers early (empty by default)
    _name = TextEditingController();
    _line1 = TextEditingController();
    _line2 = TextEditingController();
    _city = TextEditingController();
    _region = TextEditingController();
    _postal = TextEditingController();
    _country = TextEditingController(text: 'LK');
    _phone = TextEditingController();

    // If full AddressData is provided -> apply immediately
    if (widget.address != null) {
      _applyAddress(widget.address!);
    }
    // Else if we only have an id -> fetch list and prefill
    else if (widget.addressId != null && widget.addressId!.isNotEmpty) {
      _prefillFromServer(widget.addressId!);
    }
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

  void _applyAddress(AddressData a) {
    _name.text = a.name;
    _line1.text = a.line1;
    _line2.text = a.line2;
    _city.text = a.city;
    _region.text = a.region;
    _postal.text = a.postalCode;
    _country.text = (a.country.isEmpty ? 'LK' : a.country.toUpperCase());
    _phone.text = a.phone;
    _isDefault = a.isDefault;
    setState(() {});
  }

  Future<void> _prefillFromServer(String id) async {
    setState(() => _loadingPrefill = true);

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
        final items = (map['items'] as List? ?? const [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

        AddressData? found;
        for (final m in items) {
          final a = AddressData.fromApi(m);
          if (a.id == id) {
            found = a;
            break;
          }
        }

        if (found != null) {
          _applyAddress(found);
        } else {
          AppSnackbars.warning(context, 'Address not found. Fill the form to update.');
        }
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Session expired. Please log in again.');
      } else {
        AppSnackbars.error(context, 'Failed to load address (${resp.statusCode}).');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbars.error(context, 'Network problem while loading address.');
      }
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    final name = _name.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    final country = _country.text.trim().isEmpty ? 'LK' : _country.text.trim().toUpperCase();

    if (name.isEmpty || line1.isEmpty || city.isEmpty) {
      AppSnackbars.warning(context, 'Please fill Name, Address line 1 and City.');
      return;
    }

    final payload = {
      'name': name,
      'line1': line1,
      'line2': _line2.text.trim(),
      'city': city,
      'region': _region.text.trim(),
      'postal_code': _postal.text.trim(),
      'country': country,
      'phone': _phone.text.trim(),
      'is_default': _isDefault,
    };

    setState(() => _saving = true);

    final client = HttpClient();
    try {
      if (_isEdit) {
        // Choose id from provided object or route parameter
        final String id = widget.address?.id ?? widget.addressId ?? '';
        if (id.isEmpty) {
          AppSnackbars.error(context, 'Missing address id for update.');
          setState(() => _saving = false);
          return;
        }

        // PUT /api/addresses/<id>
        final uri = Uri.parse('$_baseUrl${Api.addresses}/$id');
        final req = await client.putUrl(uri);
        req.headers.set('Accept', 'application/json');
        req.headers.set('Content-Type', 'application/json');
        req.headers.set('Authorization', 'Bearer ${widget.accessToken}');
        req.add(utf8.encode(jsonEncode(payload)));
        final resp = await req.close();
        await resp.transform(utf8.decoder).join();

        if (!mounted) return;

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          // Build result (if we had object, copy; otherwise synthesize)
          final updated = (widget.address ?? AddressData.empty(id: id)).copyWith(
            name: name,
            line1: line1,
            line2: _line2.text.trim(),
            city: city,
            region: _region.text.trim(),
            postalCode: _postal.text.trim(),
            country: country,
            phone: _phone.text.trim(),
            isDefault: _isDefault,
          );
          Navigator.of(context).pop(AddressSaveResult(address: updated, created: false));
        } else if (resp.statusCode == 401) {
          AppSnackbars.warning(context, 'Session expired. Please log in again.');
        } else {
          AppSnackbars.error(context, 'Update failed (${resp.statusCode}).');
        }
      } else {
        // POST /api/addresses
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
          final created = AddressData.fromApi(map);
          Navigator.of(context).pop(AddressSaveResult(address: created, created: true));
        } else if (resp.statusCode == 401) {
          AppSnackbars.warning(context, 'Session expired. Please log in again.');
        } else {
          AppSnackbars.error(context, 'Create failed (${resp.statusCode}).');
        }
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Please try again.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBarPrimary(title: _isEdit ? 'Edit address' : 'Add address'),
      body: SafeArea(
        child: _loadingPrefill
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
                child: Column(
                  children: [
                    _LabeledField(
                      label: 'Full name*',
                      controller: _name,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    _LabeledField(
                      label: 'Address line 1*',
                      controller: _line1,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    _LabeledField(
                      label: 'Address line 2',
                      controller: _line2,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'City*',
                            controller: _city,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LabeledField(
                            label: 'Region / State',
                            controller: _region,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Postal code',
                            controller: _postal,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LabeledField(
                            label: 'Country',
                            controller: _country,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: _saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add address'),
                      onPressed: _saving ? null : _submit,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// UI helper
// ============================================================================

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
// Data & Result
// ============================================================================

class AddressData {
  const AddressData({
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

  factory AddressData.fromApi(Map<String, dynamic> m) {
    return AddressData(
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

  AddressData copyWith({
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
    return AddressData(
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

  /// Helper for synthesizing a minimal object when we only know the id.
  factory AddressData.empty({required String id}) => AddressData(
        id: id,
        name: '',
        line1: '',
        line2: '',
        city: '',
        region: '',
        postalCode: '',
        country: 'LK',
        phone: '',
        isDefault: false,
      );
}

class AddressSaveResult {
  const AddressSaveResult({
    required this.address,
    required this.created, // true if POST (new), false if PUT (updated)
  });

  final AddressData address;
  final bool created;
}
