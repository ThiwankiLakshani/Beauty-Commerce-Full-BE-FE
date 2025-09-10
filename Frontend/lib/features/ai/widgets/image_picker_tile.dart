// lib/features/ai/widgets/image_picker_tile.dart


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImagePickerTile extends StatefulWidget {
  const ImagePickerTile({
    super.key,
    this.initialDataUrl,
    required this.onChanged,
    this.title = 'Face Photo',
    this.hint =
        'Paste a Base64 image or enter an image URL. We will convert it for analysis.',
  });

  /// Optional initial data URL ("data:<mime>;base64,<...>").
  final String? initialDataUrl;

  /// Called whenever the selected image changes. Passes a normalized Data URL or null if cleared.
  final ValueChanged<String?> onChanged;

  /// Title shown above the tile.
  final String title;

  /// Short helper text shown in the placeholder.
  final String hint;

  @override
  State<ImagePickerTile> createState() => _ImagePickerTileState();
}

class _ImagePickerTileState extends State<ImagePickerTile> {
  String? _dataUrl; // normalized: "data:<mime>;base64,<...>"
  Uint8List? _bytes; // decoded for preview
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDataUrl != null && widget.initialDataUrl!.trim().isNotEmpty) {
      _setDataUrl(widget.initialDataUrl!.trim());
    }
  }

  // ----------------------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setDataUrl(String? value) async {
    if (!mounted) return;
    if (value == null || value.trim().isEmpty) {
      setState(() {
        _dataUrl = null;
        _bytes = null;
      });
      widget.onChanged(null);
      return;
    }

    final normalized = _normalizeToDataUrl(value.trim());
    if (normalized == null) {
      _toast('Unsupported image data.');
      return;
    }

    final bytes = _decodeDataUrlBytes(normalized);
    if (bytes == null) {
      _toast('Could not decode image data.');
      return;
    }

    setState(() {
      _dataUrl = normalized;
      _bytes = bytes;
    });
    widget.onChanged(_dataUrl);
  }

  String? _normalizeToDataUrl(String input) {
    // Already a data URL
    if (input.startsWith('data:')) return input;

    // Looks like a raw base64 string -> wrap with jpeg mime as a safe default
    final isLikelyB64 = RegExp(r'^[A-Za-z0-9+/=\s]+$').hasMatch(input) && input.contains('=');
    if (isLikelyB64) {
      final clean = input.replaceAll(RegExp(r'\s'), '');
      return 'data:image/jpeg;base64,$clean';
    }

    // Otherwise assume it's a URL; this path is handled elsewhere via _pickFromUrl()
    return null;
  }

  Uint8List? _decodeDataUrlBytes(String dataUrl) {
    try {
      final idx = dataUrl.indexOf(',');
      if (idx < 0) return null;
      final b64 = dataUrl.substring(idx + 1);
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  String _guessMimeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<void> _pickFromUrl() async {
    final url = await _promptText(
      title: 'Image URL',
      hintText: 'https://example.com/photo.jpg',
      keyboardType: TextInputType.url,
      validator: (s) {
        final v = (s ?? '').trim();
        if (v.isEmpty) return 'Please enter a URL';

        final u = Uri.tryParse(v);
        final ok = u != null &&
            (u.scheme == 'http' || u.scheme == 'https') &&
            u.hasAuthority &&            // ensures host present
            u.hasAbsolutePath;           // path starts with '/'

        if (!ok) return 'Enter a valid URL';
        return null;
      },

    );
    if (url == null) return;

    setState(() => _busy = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'image/*');
      final resp = await req.close();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _toast('Failed to fetch image (${resp.statusCode}).');
        return;
      }

      final bytes = await _readAllBytes(resp);
      final mime = resp.headers.contentType?.mimeType ?? _guessMimeFromUrl(url);
      final b64 = base64Encode(bytes);
      await _setDataUrl('data:$mime;base64,$b64');
    } catch (_) {
      _toast('Network problem. Please try again.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteBase64() async {
    final b64 = await _promptMultiline(
      title: 'Paste Base64',
      hintText: 'Paste a Base64 string (with or without data: prefix)',
    );
    if (b64 == null) return;

    // Accept both raw base64 and full data URL
    final normalized = b64.startsWith('data:')
        ? b64.trim()
        : 'data:image/jpeg;base64,${b64.replaceAll(RegExp(r"\s"), "")}';

    await _setDataUrl(normalized);
  }

  Future<void> _clear() async {
    await _setDataUrl(null);
  }

  // ----------------------------------------------------------------------------
  // UI dialogs
  // ----------------------------------------------------------------------------

  Future<String?> _promptText({
    required String title,
    required String hintText,
    String? initial,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: keyboardType,
            validator: validator,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (validator != null) {
                if (!(formKey.currentState?.validate() ?? false)) return;
              }
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptMultiline({
    required String title,
    required String hintText,
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Preview or placeholder
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _busy
                      ? Container(
                          color: cs.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : (_bytes != null
                          ? Image.memory(
                              _bytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _broken(cs),
                            )
                          : _placeholder(cs)),
                ),
              ),
              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _pickFromUrl,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('From URL'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pasteBase64,
                      icon: const Icon(Icons.paste_rounded),
                      label: const Text('Paste Base64'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _busy || _dataUrl == null ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.hint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            'No image selected',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _broken(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 36, color: cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            'Preview unavailable',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// IO helpers
// ----------------------------------------------------------------------------

Future<Uint8List> _readAllBytes(HttpClientResponse response) {
  final completer = Completer<Uint8List>();
  final contents = <int>[];
  response.listen(
    contents.addAll,
    onDone: () => completer.complete(Uint8List.fromList(contents)),
    onError: completer.completeError,
    cancelOnError: true,
  );
  return completer.future;
}
