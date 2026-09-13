import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../../models/project_model.dart';
import '../../../services/provider_registry.dart';

class ImageEditorScreen extends StatefulWidget {
  final String projectId;
  const ImageEditorScreen({super.key, required this.projectId});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  ProjectModel? _project;
  
  @override
  void initState() {
    super.initState();
    _loadProject();
  }
  
  void _loadProject() {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    setState(() {
      _project = registry.projectsBox.get(widget.projectId);
    });
  }

  Future<void> _cropImage(String imagePath) async {
    // Capture context-dependent references before any async gaps
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Scene Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Scene Cropper',
        ),
      ],
    );

    if (croppedFile != null && _project != null) {
      // Save it as a new scene
      final editedList = List<String>.from(_project!.editedImagePaths);
      editedList.add(croppedFile.path);
      
      _project!.editedImagePaths = editedList;
      await _project!.save();
      
      registry.refreshProjects();
      _loadProject(); // Reload state
      
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Scene extracted and saved successfully')),
        );
      }
    }
  }

  void _removeEditedImage(int index) async {
    final registry = Provider.of<ProviderRegistry>(context, listen: false);
    final editedList = List<String>.from(_project!.editedImagePaths);
    editedList.removeAt(index);
    _project!.editedImagePaths = editedList;
    await _project!.save();
    registry.refreshProjects();
    _loadProject();
  }

  /// Scene number -> index in (extracted + edited) combined list.
  /// The pipeline resolves override indices against the same combined list.
  int? _overrideFor(Map<int, int> overrides, int sceneNumber) =>
      overrides[sceneNumber];

  void _setOverride(int sceneNumber, int? combinedIndex) {
    final project = _project!;
    final overrides = Map<int, int>.from(project.sceneImageOverrides);
    if (combinedIndex == null) {
      overrides.remove(sceneNumber);
    } else {
      overrides[sceneNumber] = combinedIndex;
    }
    project.sceneImageOverrides = overrides;
    project.save();
    _loadProject();
  }

  List<int> _sceneNumbers() {
    final project = _project;
    if (project == null || project.generatedScript == null) return [];
    try {
      final dynamic data = jsonDecode(project.generatedScript!);
      if (data is Map && data['scenes'] is List) {
        final nums = <int>[];
        for (final s in data['scenes'] as List) {
          if (s is Map && s['scene_number'] is num) {
            nums.add((s['scene_number'] as num).toInt());
          }
        }
        nums.sort();
        return nums;
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scene Editor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final originalImages = _project!.extractedImagePaths;
    final editedImages = _project!.editedImagePaths;
    final sceneNumbers = _sceneNumbers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scene Editor'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
        children: [
          // Original files section
          Expanded(
            flex: 1,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Original Pages (Tap to Crop)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: originalImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _cropImage(originalImages[index]),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Image.file(
                                  File(originalImages[index]),
                                  height: 200,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8),
                                Text('Page ${index + 1}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          const VerticalDivider(width: 1, thickness: 1),
          
          // Edited scenes section
          Expanded(
            flex: 1,
            child: Column(
              children: [
                 Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Extra Scenes for Video (${editedImages.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: editedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              File(editedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.red,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () => _removeEditedImage(index),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              color: Colors.black54,
                              child: Text('Scene ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    // Scene → Image overrides: point any script scene at any image
    // (original page or a cropped "extra scene").
    if (sceneNumbers.isNotEmpty)
      Container(
        height: 132,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.link_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'Scene overrides (optional): point a script scene at any image',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: sceneNumbers.map((num) {
                  final combinedCount = originalImages.length + editedImages.length;
                  final override = _overrideFor(_project!.sceneImageOverrides, num);
                  // -1 = "no override" sentinel (dropdowns can't hold null).
                  return DropdownButtonFormField<int>(
                    key: ValueKey('override_$num'),
                    initialValue: override ?? -1,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      labelStyle: TextStyle(fontSize: 11),
                    ),
                    hint: Text(
                      'Scene $num',
                      style: const TextStyle(fontSize: 11),
                    ),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    items: [
                      DropdownMenuItem(
                        value: -1,
                        child: Text('Scene $num → default',
                            style: const TextStyle(fontSize: 11)),
                      ),
                      for (int i = 0; i < combinedCount; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            'Scene $num → '
                            '${i < originalImages.length ? 'Page ${i + 1}' : 'Cropped ${i - originalImages.length + 1}'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => _setOverride(num, (v == null || v == -1) ? null : v),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ],
      ),
    );
  }
}
