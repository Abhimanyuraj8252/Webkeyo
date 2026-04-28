import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/project_model.dart';


class CharacterAssignment {
  final String faceImagePath;
  String name;
  String role;
  String traits;

  CharacterAssignment({
    required this.faceImagePath,
    this.name = '',
    this.role = 'Main Character',
    this.traits = '',
  });

  String toContextString() {
    return 'Character Name: $name\nRole: $role\nTraits/Description: $traits\n---\n';
  }
}

class CharacterAssignmentScreen extends StatefulWidget {
  final ProjectModel project;
  final List<String> faceImagePaths;

  const CharacterAssignmentScreen({
    super.key,
    required this.project,
    required this.faceImagePaths,
  });

  @override
  State<CharacterAssignmentScreen> createState() => _CharacterAssignmentScreenState();
}

class _CharacterAssignmentScreenState extends State<CharacterAssignmentScreen> {
  late List<CharacterAssignment> _assignments;
  bool _isSaving = false;

  final List<String> _roleOptions = [
    'Main Character',
    'Supporter',
    'Antagonist',
    'Side Character',
    'Mentor',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _assignments = widget.faceImagePaths
        .map((path) => CharacterAssignment(faceImagePath: path))
        .toList();
  }

  Future<void> _saveAssignments() async {
    setState(() => _isSaving = true);
    
    // Compile to context string
    final buffer = StringBuffer();
    for (var char in _assignments) {
      if (char.name.isNotEmpty) {
        buffer.write(char.toContextString());
      }
    }
    
    final contextString = buffer.toString();
    
    widget.project.charactersContext = widget.project.charactersContext != null && widget.project.charactersContext!.isNotEmpty
        ? '${widget.project.charactersContext}\n$contextString'
        : contextString;
    
    await widget.project.save();
    
    setState(() => _isSaving = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Character assignments saved successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context); // Go back to Project Context Screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use theme to style Scaffold

    if (_assignments.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Assign Characters')),
        body: Center(
          child: Text('No faces detected in the provided images.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Characters'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveAssignments,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save & Continue', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingLarge),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Face Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    child: Image.file(
                      File(assignment.faceImagePath),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingMedium),
                  
                  // Inputs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          initialValue: assignment.name,
                          decoration: const InputDecoration(
                            labelText: 'Character Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => assignment.name = val,
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        DropdownButtonFormField<String>(
                          initialValue: assignment.role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _roleOptions.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => assignment.role = val);
                            }
                          },
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        TextFormField(
                          initialValue: assignment.traits,
                          decoration: const InputDecoration(
                            labelText: 'Traits / Description (e.g., Red hair, arrogant)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                          onChanged: (val) => assignment.traits = val,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
