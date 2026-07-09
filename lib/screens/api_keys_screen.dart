import 'package:flutter/material.dart';
import '../core/config/config_loader.dart';
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
      final changes = <String>[];

      // A non-empty field replaces the stored key; an empty field clears
      // any stored key so a build-time (--dart-define) key can apply again.
      if (gemini.isNotEmpty) {
        await ApiConfigService.setGeminiApiKey(gemini);
        changes.add('Gemini key saved');
      } else if (ApiConfigService.hasGeminiKey) {
        await ApiConfigService.removeGeminiApiKey();
        changes.add('Gemini key cleared');
      }
      if (deepgram.isNotEmpty) {
        await ApiConfigService.setDeepgramApiKey(deepgram);
        changes.add('Deepgram key saved');
      } else if (ApiConfigService.hasDeepgramKey) {
        await ApiConfigService.removeDeepgramApiKey();
        changes.add('Deepgram key cleared');
      }

      if (mounted) {
        _geminiController.clear();
        _deepgramController.clear();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              changes.isEmpty ? 'No changes to save' : changes.join(', '),
            ),
          ),
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

  Future<void> _clearKey({
    required String keyName,
    required Future<void> Function() remove,
    required TextEditingController controller,
  }) async {
    try {
      await remove();
      if (mounted) {
        controller.clear();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$keyName key cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing key: $e')),
        );
      }
    }
  }

  Widget _buildStatusChip({
    required String storedKey,
    required bool hasBuildTimeKey,
  }) {
    final Color color;
    final IconData icon;
    final String label;
    if (storedKey.isNotEmpty) {
      color = AppTheme.success;
      icon = Icons.check_circle;
      label = 'Key set (${_maskedKey(storedKey)})';
    } else if (hasBuildTimeKey) {
      color = AppTheme.primary;
      icon = Icons.build_circle_outlined;
      label = 'Using build-time key';
    } else {
      color = AppTheme.warning;
      icon = Icons.error_outline;
      label = 'Not set';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space8,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(color: color),
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
    required bool hasBuildTimeKey,
    required VoidCallback onClear,
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
              storedKey: storedKey,
              hasBuildTimeKey: hasBuildTimeKey,
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
                ? 'New key replaces the stored one; save empty to clear it'
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
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context)),
        ),
        if (storedKey.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : onClear,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                hasBuildTimeKey
                    ? 'Clear stored key (use build-time key)'
                    : 'Clear stored key',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
                padding: EdgeInsets.zero,
              ),
            ),
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
                color: AppTheme.textSecondaryColor(context),
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
              hasBuildTimeKey: ConfigLoader.hasBuildTimeGeminiKey,
              onClear: () => _clearKey(
                keyName: 'Gemini',
                remove: ApiConfigService.removeGeminiApiKey,
                controller: _geminiController,
              ),
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
              hasBuildTimeKey: ConfigLoader.hasBuildTimeDeepgramKey,
              onClear: () => _clearKey(
                keyName: 'Deepgram',
                remove: ApiConfigService.removeDeepgramApiKey,
                controller: _deepgramController,
              ),
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
