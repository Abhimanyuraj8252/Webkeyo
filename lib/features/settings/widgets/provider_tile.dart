import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/ai_provider_model.dart';
import '../../../services/dynamic_api_client.dart';
import '../../../services/provider_registry.dart';

class ProviderTile extends StatefulWidget {
  final AIProviderModel provider;

  const ProviderTile({super.key, required this.provider});

  @override
  State<ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<ProviderTile> {
  bool _isExpanded = false;
  bool _isLoading = false;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.provider.apiKey);
    _baseUrlController = TextEditingController(text: widget.provider.customBaseUrl);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProvider() async {
    final updatedProvider = widget.provider.copyWith(
      apiKey: _apiKeyController.text,
      customBaseUrl: _baseUrlController.text,
    );
    await context.read<ProviderRegistry>().updateProvider(updatedProvider);
  }

  void _onApiKeyChanged(String value) {
    _saveProvider();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      if (value.isNotEmpty) {
        _fetchModels();
      }
    });
  }

  Future<void> _fetchModels() async {
    // Capture references before any async gaps
    final registry = context.read<ProviderRegistry>();
    final messenger = ScaffoldMessenger.of(context);

    await _saveProvider(); // Save first so client has the latest keys
    
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProvider = registry.providers.firstWhere((p) => p.id == widget.provider.id);
      
      // Specifically skip Edge-TTS and Piper TTS since they don't have standard API endpoints
      if (updatedProvider.id == 'edge_tts' || updatedProvider.id == 'piper_tts') {
         messenger.showSnackBar(
          const SnackBar(content: Text('Offline/Built-in TTS providers do not need manual fetching.')),
        );
        return;
      }
      
      final models = await DynamicApiClient.fetchModels(updatedProvider);
      await registry.saveModelsForProvider(updatedProvider.id, models);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Successfully fetched ${models.length} models for ${updatedProvider.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = context.watch<ProviderRegistry>();
    final isEnabled = widget.provider.isEnabled;
    final modelCount = registry.getModelsByProvider(widget.provider.id).length;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingSmall,
            ),
            title: Text(
              widget.provider.name,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              modelCount > 0 ? '$modelCount Models available' : 'Tap to configure',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: modelCount > 0 ? AppTheme.successColor : theme.colorScheme.secondary,
              ),
            ),
            leading: Icon(
              isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isEnabled ? AppTheme.accentNeonPurple : theme.textTheme.bodyMedium?.color,
            ),
            trailing: Switch(
              value: isEnabled,
              activeThumbColor: AppTheme.accentNeonPurple,
              onChanged: (value) {
                final updatedProvider = widget.provider.copyWith(isEnabled: value);
                context.read<ProviderRegistry>().updateProvider(updatedProvider);
              },
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: AppConstants.paddingSmall),
                  if (widget.provider.customBaseUrl != null) ...[
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (_) => _saveProvider(),
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                  ],
                  if (widget.provider.requiresApiKey) ...[
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      onChanged: _onApiKeyChanged,
                    ),
                    const SizedBox(height: AppConstants.paddingMedium),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchModels,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20, height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Icon(Icons.sync),
                    label: Text(_isLoading ? 'Fetching...' : 'Fetch Models'),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: AppConstants.animationMedium,
          ),
        ],
      ),
    );
  }
}
