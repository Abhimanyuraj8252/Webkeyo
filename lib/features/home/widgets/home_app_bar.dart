/// Home app bar — logo + title, Quick Tools and Settings actions.
library;

import 'package:flutter/material.dart';

import '../../settings/settings_screen.dart';
import '../../tools/tools_screen.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: AssetImage('assets/logo.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Webkeyo', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.handyman_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ToolsScreen()),
            );
          },
          tooltip: 'Quick Tools',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }
}
