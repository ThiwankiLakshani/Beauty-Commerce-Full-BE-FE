// lib/features/addresses/widgets/address_form.dart
//


import 'package:flutter/material.dart';

import '../../../common/widgets/primary_button.dart';

class AddressFormData {
  const AddressFormData({
    required this.name,
    required this.line1,
    this.line2 = '',
    required this.city,
    this.region = '',
    this.postalCode = '',
    this.country = 'LK',
    this.phone = '',
    this.isDefault = false,
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

  AddressFormData copyWith({
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
    return AddressFormData(
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

  /// Convenience for backend payloads.
  Map<String, dynamic> toApiPayload() => {
        'name': name,
        'line1': line1,
        'line2': line2,
        'city': city,
        'region': region,
        'postal_code': postalCode,
        'country': country,
        'phone': phone,
        'is_default': isDefault,
      };

  factory AddressFormData.empty() => const AddressFormData(
        name: '',
        line1: '',
        city: '',
      );
}

class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.submitLabel = 'Save address',
    this.isSaving = false,
    this.showSetDefault = true,
    this.autofocusName = false,
  });

  /// Pre-fill fields for editing; if null, starts blank.
  final AddressFormData? initial;

  /// Called when form is valid and the user taps the submit button.
  final ValueChanged<AddressFormData> onSubmit;

  /// Main button label.
  final String submitLabel;

  /// Disable button and show a progress label when saving.
  final bool isSaving;

  /// Show the "Set as default" switch.
  final bool showSetDefault;

  /// Autofocus the name field on open.
  final bool autofocusName;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final _formKey = GlobalKey<FormState>();

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
    final i = widget.initial ?? AddressFormData.empty();
    _name = TextEditingController(text: i.name);
    _line1 = TextEditingController(text: i.line1);
    _line2 = TextEditingController(text: i.line2);
    _city = TextEditingController(text: i.city);
    _region = TextEditingController(text: i.region);
    _postal = TextEditingController(text: i.postalCode);
    _country = TextEditingController(text: i.country.isEmpty ? 'LK' : i.country);
    _phone = TextEditingController(text: i.phone);
    _isDefault = i.isDefault;
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = AddressFormData(
      name: _name.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      city: _city.text.trim(),
      region: _region.text.trim(),
      postalCode: _postal.text.trim(),
      country: (_country.text.trim().isEmpty ? 'LK' : _country.text.trim().toUpperCase()),
      phone: _phone.text.trim(),
      isDefault: _isDefault,
    );
    widget.onSubmit(data);
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom > 0 ? 8 : 0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Name
            TextFormField(
              controller: _name,
              autofocus: widget.autofocusName,
              textInputAction: TextInputAction.next,
              validator: _required,
              decoration: _dec('Full name*'),
            ),
            const SizedBox(height: 10),

            // Address 1
            TextFormField(
              controller: _line1,
              textInputAction: TextInputAction.next,
              validator: _required,
              decoration: _dec('Address line 1*'),
            ),
            const SizedBox(height: 10),

            // Address 2
            TextFormField(
              controller: _line2,
              textInputAction: TextInputAction.next,
              decoration: _dec('Address line 2'),
            ),
            const SizedBox(height: 10),

            // City + Region
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    textInputAction: TextInputAction.next,
                    validator: _required,
                    decoration: _dec('City*'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _region,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('Region / State'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Postal + Country
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _postal,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Postal code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _country,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('Country'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Phone
            TextFormField(
              controller: _phone,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone'),
            ),
            const SizedBox(height: 10),

            if (widget.showSetDefault)
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
              label: widget.isSaving ? 'Saving…' : widget.submitLabel,
              onPressed: widget.isSaving ? null : _submit,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
