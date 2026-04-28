import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/ai_provider_model.dart';
import '../../services/provider_registry.dart';
import 'widgets/provider_tile.dart';

class ProvidersScreen extends StatelessWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Providers'),
          bottom: TabBar(
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            tabs: const [
              Tab(text: 'Script / Text', icon: Icon(Icons.description)),
              Tab(text: 'Vision / Image', icon: Icon(Icons.remove_red_eye)),
              Tab(text: 'TTS / Audio', icon: Icon(Icons.record_voice_over)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProviderList(category: ProviderCategory.text),
            _ProviderList(category: ProviderCategory.vision),
            _ProviderList(category: ProviderCategory.tts),
          ],
        ),
      ),
    );
  }
}

class _ProviderList extends StatelessWidget {
  final ProviderCategory category;

  const _ProviderList({required this.category});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ProviderRegistry>();
    final providers = registry.getProvidersByCategory(category);

    if (providers.isEmpty) {
      return const Center(child: Text('No providers found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        return ProviderTile(provider: providers[index]);
      },
    );
  }
}
