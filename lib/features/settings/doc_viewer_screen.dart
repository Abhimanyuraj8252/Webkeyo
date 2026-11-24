/// Simple in-app document viewer — shows a bundled Markdown file
/// (Privacy Policy, Terms of Use) as readable text. No web view, no
/// network: the docs ship in assets/docs/.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants.dart';

class DocViewerScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const DocViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text('Could not load $title.',
                  style: theme.textTheme.bodyMedium),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: SelectableText(
              snapshot.data!,
              style: theme.textTheme.bodyMedium,
            ),
          );
        },
      ),
    );
  }
}
