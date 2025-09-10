// lib/features/ai/screens/ai_analyze_screen.dart


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/utils/snackbar.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/primary_button.dart';
import 'package:beauty_commerce_app/features/ai/widgets/analysis_result_card.dart' as aiw;

class AiAnalyzeScreen extends StatefulWidget {
  const AiAnalyzeScreen({super.key, this.accessToken});
  final String? accessToken;

  @override
  State<AiAnalyzeScreen> createState() => _AiAnalyzeScreenState();
}

class _AiAnalyzeScreenState extends State<AiAnalyzeScreen> {
  final _picker = ImagePicker();

  String? _dataUrl;           // normalized data URL to POST
  Uint8List? _bytes;          // preview
  bool _submitting = false;

  // Fields from API response
  Map<String, dynamic>? _combined; // {skin_type, skin_concerns, other_concerns, low_concerns}
  bool _saved = false;
  String? _imageUrl;

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) return Api.defaultBaseUrlIosSimulator;
    return Api.defaultBaseUrlAndroidEmulator;
  }

  // ---------------- Image picking ----------------

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _setImageBytes(bytes, _guessMimeFromPath(x.path));
  }

  Future<void> _captureFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _setImageBytes(bytes, _guessMimeFromPath(x.path));
  }

  String _guessMimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<void> _setImageBytes(Uint8List bytes, String mime) async {
    final b64 = base64Encode(bytes);
    setState(() {
      _bytes = bytes;
      _dataUrl = 'data:$mime;base64,$b64';
      // clear previous results for new image
      _combined = null;
      _imageUrl = null;
      _saved = false;
    });
  }

  // ---------------- Submit to backend ----------------

  Future<void> _submit() async {
    if (_submitting) return;
    if ((_dataUrl ?? '').isEmpty) {
      AppSnackbars.warning(context, 'Pick or capture a photo first');
      return;
    }

    setState(() => _submitting = true);

    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl${Api.aiAnalyze}');
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      final token = (widget.accessToken ?? '').trim();
      if (token.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      req.add(utf8.encode(jsonEncode({'image_base64': _dataUrl})));

      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = (jsonDecode(text) as Map).cast<String, dynamic>();
        final combined = (map['result'] as Map?)?.cast<String, dynamic>() ?? const {};
        setState(() {
          _combined = combined.isEmpty ? null : combined;
          _saved = map['saved'] == true;
          final u = (map['image_url'] ?? '').toString();
          _imageUrl = u.isEmpty ? null : u;
        });
      } else if (resp.statusCode == 401) {
        AppSnackbars.warning(context, 'Please sign in to save your AI profile');
        context.goNamed('login');
      } else {
        AppSnackbars.error(context, 'Analysis failed (${resp.statusCode})');
      }
    } catch (_) {
      if (mounted) AppSnackbars.error(context, 'Network problem. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
      client.close(force: true);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarPrimary(title: 'AI Analyze'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: PrimaryButton(
            label: _submitting ? 'Analyzing…' : 'Analyze',
            onPressed: _submitting ? null : _submit,
            fullWidth: true,
            loading: _submitting,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HelpCard(),
          const SizedBox(height: 12),

          // Preview tile
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _bytes == null
                        ? _placeholder(cs)
                        : Image.memory(
                            _bytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _broken(cs),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Pick photo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _captureFromCamera,
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('Take photo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Render the "combined" result as 4 horizontal sections
          if (_combined != null)
            aiw.AnalysisResultCard.fromCombined(
              combined: _combined!,
              imageUrl: _imageUrl,
              saved: _saved,
              // updatedAt: (optional) if your API returns it
            ),
        ],
      ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper
// -----------------------------------------------------------------------------

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pick a photo from your gallery or take a new one. '
              'If you are signed in, the analysis can be saved to your profile.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
