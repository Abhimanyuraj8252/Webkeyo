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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scene Editor'),
      ),
      body: Row(
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
    );
  }
}
