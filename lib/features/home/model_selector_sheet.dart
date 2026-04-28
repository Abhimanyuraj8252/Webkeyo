import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/ai_model.dart';
import '../../models/ai_provider_model.dart';
import '../../services/provider_registry.dart';

class ModelSelectorSheet extends StatefulWidget {
  final ProviderCategory category;

  const ModelSelectorSheet({super.key, required this.category});

  static Future<AIModel?> show(BuildContext context, ProviderCategory category) {
    return showModalBottomSheet<AIModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModelSelectorSheet(category: category),
    );
  }

  @override
  State<ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<ModelSelectorSheet> {
  AIProviderModel? _selectedProvider;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final registry = context.watch<ProviderRegistry>();

    // Only show enabled providers for this category
    final providers = registry.getProvidersByCategory(widget.category)
        .where((p) => p.isEnabled)
        .toList();

    if (providers.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusLarge)),
        ),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: AppConstants.paddingMedium),
            Text('No Enabled Providers', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Please go to Settings → AI Providers, enable a provider and fetch its models first.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    _selectedProvider ??= providers.first;

    final allModels = registry.getModelsByProvider(_selectedProvider!.id);
    // Filter by search query
    final filteredModels = _searchQuery.isEmpty
        ? allModels
        : allModels.where((m) {
            final q = _searchQuery.toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q) ||
                m.description.toLowerCase().contains(q);
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLarge)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Model',
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${filteredModels.length} models available',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: cs.onSurface.withAlpha(150)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Search Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withAlpha(40),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              // ── Provider Chips ──────────────────────────────────────
              SizedBox(
                height: 46,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMedium, vertical: 4),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final provider = providers[index];
                    final isSelected = _selectedProvider?.id == provider.id;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: AppConstants.paddingSmall),
                      child: ChoiceChip(
                        label: Text(provider.name,
                            style: GoogleFonts.inter(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: cs.primaryContainer,
                        labelStyle: TextStyle(
                          color:
                              isSelected ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedProvider = provider;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // ── Models List ─────────────────────────────────────────
              Expanded(
                child: filteredModels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: cs.onSurface.withAlpha(80)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No models fetched for ${_selectedProvider?.name}.\nGo to Settings to fetch models.'
                                  : 'No results for "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: cs.onSurface.withAlpha(150)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final model = filteredModels[index];
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withAlpha(60),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.memory_rounded,
                                  color: cs.primary, size: 20),
                            ),
                            title: Text(
                              model.name,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: model.description.isNotEmpty
                                ? Text(
                                    model.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 12),
                                  )
                                : Text(
                                    model.id,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: cs.onSurface.withAlpha(120)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing:
                                const Icon(Icons.check_circle_outline, size: 18),
                            onTap: () => Navigator.pop(context, model),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
