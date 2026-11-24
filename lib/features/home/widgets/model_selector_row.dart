/// Quick model selector chips — Script / Vision / TTS.
/// Tapping a chip opens the model selector sheet for that category.
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/ai_provider_model.dart';

class ModelSelectorRow extends StatelessWidget {
  final String? selectedTextModel;
  final String? selectedVisionModel;
  final String? selectedTtsModel;
  final void Function(ProviderCategory category) onSelect;

  const ModelSelectorRow({
    super.key,
    required this.selectedTextModel,
    required this.selectedVisionModel,
    required this.selectedTtsModel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _SelectorChip(
            title: 'Script Model',
            selectedModel: selectedTextModel,
            onPressed: () => onSelect(ProviderCategory.text),
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          _SelectorChip(
            title: 'Vision Model',
            selectedModel: selectedVisionModel,
            onPressed: () => onSelect(ProviderCategory.vision),
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          _SelectorChip(
            title: 'TTS Model',
            selectedModel: selectedTtsModel,
            onPressed: () => onSelect(ProviderCategory.tts),
          ),
        ],
      ),
    );
  }
}

class _SelectorChip extends StatelessWidget {
  final String title;
  final String? selectedModel;
  final VoidCallback onPressed;

  const _SelectorChip({
    required this.title,
    required this.selectedModel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selectedModel != null;
    return ActionChip(
      avatar: Icon(
        hasSelection ? Icons.check_circle : Icons.add_circle_outline,
        size: 18,
        color: hasSelection
            ? theme.primaryColor
            : theme.textTheme.bodyMedium?.color,
      ),
      label: Text(
        hasSelection ? selectedModel! : title,
        style: TextStyle(
          color: hasSelection
              ? theme.primaryColor
              : theme.textTheme.bodyMedium?.color,
          fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor:
          hasSelection ? theme.primaryColor.withAlpha(25) : theme.cardColor,
      side: BorderSide(
        color: hasSelection ? theme.primaryColor : theme.dividerColor,
      ),
      onPressed: onPressed,
    );
  }
}
