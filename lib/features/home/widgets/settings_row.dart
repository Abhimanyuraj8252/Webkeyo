/// Settings row — generation mode, language and the NSFW toggle.
library;

import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class HomeSettingsRow extends StatelessWidget {
  final String selectedMode;
  final List<String> modes;
  final ValueChanged<String> onModeChanged;
  final String selectedLanguage;
  final List<String> languages;
  final ValueChanged<String> onLanguageChanged;
  final bool isNsfwEnabled;
  final ValueChanged<bool> onNsfwChanged;

  const HomeSettingsRow({
    super.key,
    required this.selectedMode,
    required this.modes,
    required this.onModeChanged,
    required this.selectedLanguage,
    required this.languages,
    required this.onLanguageChanged,
    required this.isNsfwEnabled,
    required this.onNsfwChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DropdownBox(
            value: selectedMode,
            items: modes,
            icon: Icons.mode_edit_outline,
            onChanged: onModeChanged,
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          flex: 3,
          child: _DropdownBox(
            value: selectedLanguage,
            items: languages,
            icon: Icons.language_rounded,
            onChanged: onLanguageChanged,
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          flex: 2,
          child: _NsfwToggle(
            isEnabled: isNsfwEnabled,
            onChanged: onNsfwChanged,
          ),
        ),
      ],
    );
  }
}

class _DropdownBox extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _DropdownBox({
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(icon, size: 20),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _NsfwToggle extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _NsfwToggle({required this.isEnabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.redAccent.withAlpha(25) : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isEnabled
              ? Colors.redAccent.withAlpha(128)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'NSFW',
              style: TextStyle(
                fontSize: 11,
                color: isEnabled
                    ? Colors.redAccent
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: isEnabled,
              activeThumbColor: Colors.redAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
