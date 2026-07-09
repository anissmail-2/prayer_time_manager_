import 'package:flutter/material.dart';
import '../core/services/api_config_service.dart';
import '../core/theme/app_theme.dart';

/// Screen for entering the Gemini and Deepgram API keys at runtime.
///
/// Keys are persisted via [ApiConfigService] (SharedPreferences) so they
/// never need to live in source code or in the APK.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _deepgramController = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureDeepgram = true;
  bool _saving = false;

  @override
  void dispose() {
    _geminiController.dispose();
    _deepgramController.dispose();
    super.dispose();
  }

  /// Masked representation of a stored key, e.g. "••••3d5a".
  String _maskedKey(String key) {
    if (key.isEmpty) return '';
    final suffix = key.length > 4 ? key.substring(key.length - 4) : key;
    return '••••$suffix';
  }

  Future<void> _saveKeys() async {
    setState(() => _saving = true);
    try {
      final gemini = _geminiController.text.trim();
      final deepgram = _deepgramController.text.trim();

      // Only overwrite a stored key when the user actually typed something.
      if (gemini.isNotEmpty) {
        await ApiConfigService.setGeminiApiKey(gemini);
      }
      if (deepgram.isNotEmpty) {
        await ApiConfigService.setDeepgramApiKey(deepgram);
      }

      if (mounted) {
        _geminiController.clear();
        _deepgramController.clear();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API keys saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving keys: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildStatusChip({required bool isSet, required String maskedKey}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: (isSet ? AppTheme.success : AppTheme.warning)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSet ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: isSet ? AppTheme.success : AppTheme.warning,
          ),
          const SizedBox(width: AppTheme.space4),
          Text(
            isSet ? 'Key set ($maskedKey)' : 'Not set',
            style: AppTheme.labelMedium.copyWith(
              color: isSet ? AppTheme.success : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeySection({
    required String title,
    required String helperText,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String storedKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: AppTheme.titleMedium),
            ),
            _buildStatusChip(
              isSet: storedKey.isNotEmpty,
              maskedKey: _maskedKey(storedKey),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: storedKey.isNotEmpty
                ? 'Enter a new key to replace the stored one'
                : 'Paste your API key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          helperText,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keys are stored on this device only and are never bundled '
              'with the app.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            _buildKeySection(
              title: 'Gemini API Key',
              helperText: 'Required for the AI assistant. Create a free key '
                  'at https://aistudio.google.com/apikey',
              controller: _geminiController,
              obscure: _obscureGemini,
              onToggleObscure: () =>
                  setState(() => _obscureGemini = !_obscureGemini),
              storedKey: ApiConfigService.geminiApiKey,
            ),
            const SizedBox(height: AppTheme.space24),
            _buildKeySection(
              title: 'Deepgram API Key',
              helperText: 'Required for voice input (Android). Create a key '
                  'at https://console.deepgram.com',
              controller: _deepgramController,
              obscure: _obscureDeepgram,
              onToggleObscure: () =>
                  setState(() => _obscureDeepgram = !_obscureDeepgram),
              storedKey: ApiConfigService.deepgramApiKey,
            ),
            const SizedBox(height: AppTheme.space32),
            FilledButton.icon(
              onPressed: _saving ? null : _saveKeys,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.space16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
