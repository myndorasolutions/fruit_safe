import 'package:flutter/material.dart';
import 'package:fruit_safe/services/audio_service.dart';
import 'package:fruit_safe/theme/app_theme.dart';

class DeveloperSettingsDialog extends StatefulWidget {
  const DeveloperSettingsDialog({super.key});

  @override
  State<DeveloperSettingsDialog> createState() => _DeveloperSettingsDialogState();
}

class _DeveloperSettingsDialogState extends State<DeveloperSettingsDialog> {
  late final TextEditingController _token;
  var _obscure = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: AudioService.instance.hfApiToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await AudioService.instance.setHfToken(null);
    if (!mounted) return;
    _token.clear();
    setState(() => _busy = false);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    await AudioService.instance.setHfToken(_token.text);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.statusVerdant,
        content: Text(
          'Hugging Face token saved',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = AudioService.instance.hasToken;
    final maxHeight = MediaQuery.sizeOf(context).height - 48;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'N-ATLAS Developer Settings',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.nAtlasAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Evaluator / Dev Mode',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.nAtlasAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Configure live sovereign inference via Hugging Face Hub (NCAIR1/N-ATLaS) or test local dialect fallback.',
                style: textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _token,
                obscureText: _obscure,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Hugging Face Access Token',
                  hintText: 'hf_xxxxxxxxxxxxxxxxxxxxxxxxx',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  helperText: 'Read-access token from huggingface.co/settings/tokens',
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show token' : 'Hide token',
                    onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ConnectionStatus(active: active),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _busy ? null : _clear,
                    child: const Text('Clear Token'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _busy ? null : _save,
                    child: const Text('Save Token'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.statusVerdant : AppColors.statusWarning;
    final label = active
        ? 'Hugging Face token active'
        : 'Defaulting to bundled dialect assets';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.cloud_done_outlined : Icons.offline_bolt_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
