/// Upload row — the big UploadCard plus the folder-picker button.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import 'upload_card.dart';

class UploadRow extends StatelessWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onPickFolder;

  const UploadRow({
    super.key,
    required this.onPickFiles,
    required this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: UploadCard(
            onTap: onPickFiles,
          ),
        ),
        const SizedBox(width: AppConstants.paddingMedium),
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: InkWell(
            onTap: onPickFolder,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_rounded,
                      color: theme.colorScheme.secondary, size: 24),
                  const SizedBox(height: 2),
                  Text('Folder',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: theme.colorScheme.secondary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
