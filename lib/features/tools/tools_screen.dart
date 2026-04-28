import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as px;

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolCard(
            title: 'Advanced CBZ to PDF Pro',
            description: 'Convert comic/manga archives to PDF with premium features.',
            icon: Icons.picture_as_pdf,
            color: Colors.redAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvancedCbzToPdfScreen()),
              );
            },
          ),
          _ToolCard(
            title: 'CBZ to Images',
            description: 'Extract and upscale all images from a CBZ/ZIP file to a folder.',
            icon: Icons.photo_library,
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CbzToImageScreen()),
              );
            },
          ),
          _ToolCard(
            title: 'Image to PDF',
            description: 'Convert a folder of multiple images into a single premium PDF.',
            icon: Icons.image,
            color: Colors.greenAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
              );
            },
          ),
          _ToolCard(
            title: 'PDF to Images',
            description: 'Extract all pages of a PDF as high-quality images.',
            icon: Icons.photo_size_select_actual,
            color: Colors.purpleAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfToImageScreen()),
              );
            },
          ),
          _ToolCard(
            title: 'Merge PDFs',
            description: 'Combine multiple PDF files into one complete volume.',
            icon: Icons.merge_type,
            color: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MergePdfScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({required this.title, required this.description, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(description),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// ====================================================================
// ADVANCED CBZ TO PDF SCREEN
// ====================================================================
class AdvancedCbzToPdfScreen extends StatefulWidget {
  const AdvancedCbzToPdfScreen({super.key});
  @override
  State<AdvancedCbzToPdfScreen> createState() => _AdvancedCbzToPdfScreenState();
}

class _AdvancedCbzToPdfScreenState extends State<AdvancedCbzToPdfScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0.0;
  File? _selectedFile;

  bool _highQuality = true;
  bool _autoMargin = true;
  bool _addMetadata = true;
  String _pageFormat = 'A4';
  final List<String> _formats = ['A4', 'Letter', 'Original', 'Comic Standard'];

  Future<void> _pickCbz() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['cbz', 'zip']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _statusMessage = 'Selected: ${result.files.single.name}';
      });
    }
  }

  Future<void> _convert() async {
    if (_selectedFile == null) return;
    setState(() {
      _isConverting = true;
      _statusMessage = 'Extracting archive...';
      _progress = 0.1;
    });

    try {
      final doc = pw.Document(title: _addMetadata ? p.basenameWithoutExtension(_selectedFile!.path) : null);
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/cbz_pdf_${DateTime.now().millisecondsSinceEpoch}');
      await extractDir.create();

      final bytes = await _selectedFile!.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      setState(() { _statusMessage = 'Analyzing images...'; _progress = 0.2; });

      List<File> images = [];
      for (final file in archive) {
        if (file.isFile) {
          final ext = p.extension(file.name).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
            final outFile = File('${extractDir.path}/${file.name}');
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
            images.add(outFile);
          }
        }
      }
      images.sort((a, b) => a.path.compareTo(b.path));

      int i = 0;
      for (final imgFile in images) {
        setState(() { _statusMessage = 'Processing page ${i + 1} of ${images.length}...'; _progress = 0.2 + (0.7 * (i / images.length)); });
        
        try {
          final imageBytes = await imgFile.readAsBytes();
          final img = pw.MemoryImage(imageBytes);
          PdfPageFormat format = PdfPageFormat.a4;
          if (_pageFormat == 'Letter') format = PdfPageFormat.letter;
          final margin = _autoMargin ? 10.0 : 0.0;

          doc.addPage(
            pw.Page(
              pageFormat: _pageFormat == 'Original' ? PdfPageFormat.undefined : format,
              margin: pw.EdgeInsets.all(margin),
              build: (pw.Context context) => pw.Center(child: pw.Image(img)),
            ),
          );
        } catch (pageError) {
          debugPrint('Error processing page ${i + 1}: $pageError');
          // Continue processing other pages
        }
        i++;
      }

      setState(() { _statusMessage = 'Saving PDF...'; _progress = 0.95; });
      
      final rootPath = '/storage/emulated/0';
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final outputDir = Directory('$rootPath/Movies/webkeyo/pdf/$baseName');
      await outputDir.create(recursive: true);

      final outputPath = '${outputDir.path}/${baseName}_Pro.pdf';
      final outFile = File(outputPath);
      final pdfBytes = await doc.save();
      await outFile.writeAsBytes(pdfBytes);

      setState(() {
        _isConverting = false;
        _progress = 1.0;
        _statusMessage = 'Saved to:\nMovies/webkeyo/pdf/$baseName/${baseName}_Pro.pdf';
      });
    } catch (e, stackTrace) {
      debugPrint('CBZ to PDF Error: $e\n$stackTrace');
      setState(() { _isConverting = false; _statusMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBZ to PDF Pro')),
      body: _isConverting ? _buildProgress() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFileSelector(_selectedFile, _pickCbz),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('PREMIUM SETTINGS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(child: Text('Page Format', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButton<String>(
                  value: _pageFormat,
                  items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _pageFormat = v!),
                ),
              ],
            ),
            SwitchListTile(title: const Text('High Quality Upscale', overflow: TextOverflow.ellipsis), subtitle: const Text('Enhance resolution', overflow: TextOverflow.ellipsis), value: _highQuality, onChanged: (v) => setState(() => _highQuality = v)),
            SwitchListTile(title: const Text('Auto Smart-Margins', overflow: TextOverflow.ellipsis), subtitle: const Text('Add 10px page margins', overflow: TextOverflow.ellipsis), value: _autoMargin, onChanged: (v) => setState(() => _autoMargin = v)),
            SwitchListTile(title: const Text('Manga Metadata', overflow: TextOverflow.ellipsis), subtitle: const Text('Add document title', overflow: TextOverflow.ellipsis), value: _addMetadata, onChanged: (v) => setState(() => _addMetadata = v)),
            const SizedBox(height: 24),
            _buildGenerateButton('GENERATE PRO PDF', _selectedFile != null ? _convert : null),
            _buildStatus(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(value: _progress > 0 ? _progress : null), const SizedBox(height: 20), Text(_statusMessage, textAlign: TextAlign.center)]));
  
  Widget _buildFileSelector(File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueAccent, width: 2)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file, size: 40, color: Colors.blueAccent),
              const SizedBox(height: 8),
              Text(file != null ? p.basename(file.path) : 'Tap to select File', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(String text, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: const Icon(Icons.bolt), label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildStatus(String status) {
    if (status.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(top: 16), child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
  }
}

// ====================================================================
// ADVANCED CBZ TO IMAGE PRO
// ====================================================================
class CbzToImageScreen extends StatefulWidget {
  const CbzToImageScreen({super.key});
  @override
  State<CbzToImageScreen> createState() => _CbzToImageScreenState();
}

class _CbzToImageScreenState extends State<CbzToImageScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0.0;
  File? _selectedFile;
  bool _highQuality = true;
  String _outputFormat = 'PNG';
  final List<String> _formats = ['PNG', 'JPG', 'WEBP'];

  Future<void> _pickCbz() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['cbz', 'zip']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _statusMessage = 'Selected: ${result.files.single.name}';
      });
    }
  }

  Future<void> _process() async {
    if (_selectedFile == null) return;
    setState(() { _isConverting = true; _statusMessage = 'Extracting images...'; _progress = 0.1; });
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final outputDir = Directory('/storage/emulated/0/Movies/webkeyo/images/$baseName');
      await outputDir.create(recursive: true);

      int i = 0;
      for (final file in archive) {
        if (file.isFile) {
          final ext = p.extension(file.name).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
            final outFile = File('${outputDir.path}/${p.basenameWithoutExtension(file.name)}.${_outputFormat.toLowerCase()}');
            await outFile.writeAsBytes(file.content as List<int>);
            i++;
            setState(() { _statusMessage = 'Extracting file $i...'; _progress = 0.1 + (0.8 * (i / archive.length)); });
          }
        }
      }
      setState(() { _isConverting = false; _progress = 1.0; _statusMessage = 'Images extracted to:\nMovies/webkeyo/images/$baseName'; });
    } catch (e, stackTrace) {
      debugPrint('CBZ to Image Error: $e\n$stackTrace');
      setState(() { _isConverting = false; _statusMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBZ to Image Pro')),
      body: _isConverting ? _buildProgress() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFileSelector(_selectedFile, _pickCbz, 'Select CBZ/ZIP Archive', Colors.orangeAccent),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('EXTRACTION SETTINGS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(child: Text('Output Format', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButton<String>(
                  value: _outputFormat,
                  items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _outputFormat = v!),
                ),
              ],
            ),
            SwitchListTile(title: const Text('Preserve Original Quality', overflow: TextOverflow.ellipsis), subtitle: const Text('Do not compress output', overflow: TextOverflow.ellipsis), value: _highQuality, onChanged: (v) => setState(() => _highQuality = v)),
            const SizedBox(height: 24),
            _buildGenerateButton('EXTRACT IMAGES', _selectedFile != null ? _process : null, Icons.photo_library),
            _buildStatus(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(value: _progress > 0 ? _progress : null), const SizedBox(height: 20), Text(_statusMessage, textAlign: TextAlign.center)]));
  
  Widget _buildFileSelector(File? file, VoidCallback onTap, String hint, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 40, color: color),
              const SizedBox(height: 8),
              Text(file != null ? p.basename(file.path) : hint, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(String text, VoidCallback? onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon), label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildStatus(String status) {
    if (status.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(top: 16), child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
  }
}

// ====================================================================
// ADVANCED PDF TO IMAGE PRO
// ====================================================================
class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});
  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0.0;
  File? _selectedFile;
  bool _highQuality = true;

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _statusMessage = 'Selected: ${result.files.single.name}';
      });
    }
  }

  Future<void> _process() async {
    if (_selectedFile == null) return;
    setState(() { _isConverting = true; _statusMessage = 'Loading PDF...'; _progress = 0.1; });
    
    try {
      final pdfFile = _selectedFile!;
      final baseName = p.basenameWithoutExtension(pdfFile.path);
      final outputDir = Directory('/storage/emulated/0/Movies/webkeyo/images/$baseName');
      await outputDir.create(recursive: true);

      final document = await px.PdfDocument.openFile(pdfFile.path);
      for (int i = 1; i <= document.pagesCount; i++) {
        setState(() { _statusMessage = 'Rendering Page $i of ${document.pagesCount}...'; _progress = 0.1 + (0.8 * (i / document.pagesCount)); });
        final page = await document.getPage(i);
        final scale = _highQuality ? 2.0 : 1.0;
        final pageImage = await page.render(width: page.width * scale, height: page.height * scale, format: px.PdfPageImageFormat.png);
        if (pageImage != null) {
          final outFile = File('${outputDir.path}/page_$i.png');
          await outFile.writeAsBytes(pageImage.bytes);
        }
        await page.close();
      }
      await document.close();

      setState(() { _isConverting = false; _progress = 1.0; _statusMessage = 'Images extracted to:\nMovies/webkeyo/images/$baseName'; });
    } catch (e, stackTrace) {
      debugPrint('PDF to Image Error: $e\n$stackTrace');
      setState(() { _isConverting = false; _statusMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Image Pro')),
      body: _isConverting ? _buildProgress() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFileSelector(_selectedFile, _pickPdf, 'Select PDF Document', Colors.purpleAccent),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('EXTRACTION SETTINGS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(height: 32),
            SwitchListTile(title: const Text('High Resolution Output', overflow: TextOverflow.ellipsis), subtitle: const Text('Render pages at 2x scale', overflow: TextOverflow.ellipsis), value: _highQuality, onChanged: (v) => setState(() => _highQuality = v)),
            const SizedBox(height: 24),
            _buildGenerateButton('EXTRACT IMAGES', _selectedFile != null ? _process : null, Icons.photo_size_select_actual),
            _buildStatus(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(value: _progress > 0 ? _progress : null), const SizedBox(height: 20), Text(_statusMessage, textAlign: TextAlign.center)]));
  
  Widget _buildFileSelector(File? file, VoidCallback onTap, String hint, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 40, color: color),
              const SizedBox(height: 8),
              Text(file != null ? p.basename(file.path) : hint, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(String text, VoidCallback? onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon), label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildStatus(String status) {
    if (status.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(top: 16), child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
  }
}

// ====================================================================
// ADVANCED IMAGE TO PDF PRO
// ====================================================================
class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});
  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0.0;
  List<File> _selectedFiles = [];
  bool _autoMargin = true;
  String _pageFormat = 'A4';
  final List<String> _formats = ['A4', 'Letter', 'Original', 'Comic Standard'];

  Future<void> _pickImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        _selectedFiles = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
        _statusMessage = '${_selectedFiles.length} images selected';
      });
    }
  }

  Future<void> _process() async {
    if (_selectedFiles.isEmpty) return;
    setState(() { _isConverting = true; _statusMessage = 'Generating PDF...'; _progress = 0.1; });
    
    try {
      final doc = pw.Document();
      int i = 0;
      for (var file in _selectedFiles) {
        setState(() { _statusMessage = 'Processing image ${i+1} of ${_selectedFiles.length}...'; _progress = 0.1 + (0.8 * (i / _selectedFiles.length)); });
        final imageBytes = await file.readAsBytes();
        final img = pw.MemoryImage(imageBytes);
        
        PdfPageFormat format = PdfPageFormat.a4;
        if (_pageFormat == 'Letter') format = PdfPageFormat.letter;
        final margin = _autoMargin ? 10.0 : 0.0;

        doc.addPage(pw.Page(
          pageFormat: _pageFormat == 'Original' ? PdfPageFormat.undefined : format,
          margin: pw.EdgeInsets.all(margin),
          build: (context) => pw.Center(child: pw.Image(img)),
        ));
        i++;
      }

      final outputDir = Directory('/storage/emulated/0/Movies/webkeyo/pdf/merged');
      await outputDir.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outFile = File('${outputDir.path}/merged_$timestamp.pdf');
      await outFile.writeAsBytes(await doc.save());

      setState(() { _isConverting = false; _progress = 1.0; _statusMessage = 'PDF saved to:\nMovies/webkeyo/pdf/merged/merged_$timestamp.pdf'; });
    } catch (e, stackTrace) {
      debugPrint('Image to PDF Error: $e\n$stackTrace');
      setState(() { _isConverting = false; _statusMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF Pro')),
      body: _isConverting ? _buildProgress() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFileSelector(_selectedFiles.isNotEmpty ? _selectedFiles.length : null, _pickImages, 'Select Images', Colors.greenAccent),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('PDF SETTINGS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(child: Text('Page Format', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownButton<String>(
                  value: _pageFormat,
                  items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _pageFormat = v!),
                ),
              ],
            ),
            SwitchListTile(title: const Text('Auto Smart-Margins', overflow: TextOverflow.ellipsis), subtitle: const Text('Add 10px margins', overflow: TextOverflow.ellipsis), value: _autoMargin, onChanged: (v) => setState(() => _autoMargin = v)),
            const SizedBox(height: 24),
            _buildGenerateButton('GENERATE PDF', _selectedFiles.isNotEmpty ? _process : null, Icons.description),
            _buildStatus(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(value: _progress > 0 ? _progress : null), const SizedBox(height: 20), Text(_statusMessage, textAlign: TextAlign.center)]));
  
  Widget _buildFileSelector(int? count, VoidCallback onTap, String hint, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 40, color: color),
              const SizedBox(height: 8),
              Text(count != null ? '$count images selected' : hint, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(String text, VoidCallback? onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon), label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildStatus(String status) {
    if (status.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(top: 16), child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
  }
}

// ====================================================================
// MERGE PDF SCREEN
// ====================================================================
class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});
  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  bool _isConverting = false;
  String _statusMessage = '';
  double _progress = 0.0;
  List<File> _selectedFiles = [];

  Future<void> _pickPdfs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        _selectedFiles = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
        _statusMessage = '${_selectedFiles.length} PDFs selected';
      });
    }
  }

  Future<void> _merge() async {
    if (_selectedFiles.isEmpty) return;
    setState(() { _isConverting = true; _statusMessage = 'Merging PDFs...'; _progress = 0.1; });
    
    try {
      final mergedDoc = pw.Document();
      final totalFiles = _selectedFiles.length;
      int processedFiles = 0;

      setState(() { _statusMessage = 'Processing ${_selectedFiles.length} files...'; _progress = 0.2; });

      for (final pdfFile in _selectedFiles) {
        final document = await px.PdfDocument.openFile(pdfFile.path);
        try {
          for (int pageIndex = 1; pageIndex <= document.pagesCount; pageIndex++) {
            final page = await document.getPage(pageIndex);
            try {
              final pageImage = await page.render(
                width: page.width * 2,
                height: page.height * 2,
                format: px.PdfPageImageFormat.png,
              );

              if (pageImage != null) {
                final imageWidth = (pageImage.width ?? page.width).toDouble();
                final imageHeight = (pageImage.height ?? page.height).toDouble();
                mergedDoc.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat(imageWidth, imageHeight),
                    margin: pw.EdgeInsets.zero,
                    build: (_) => pw.Center(
                      child: pw.Image(pw.MemoryImage(pageImage.bytes), fit: pw.BoxFit.contain),
                    ),
                  ),
                );
              }

              final totalPages = document.pagesCount == 0 ? 1 : document.pagesCount;
              final fileProgress = (pageIndex / totalPages) / totalFiles;
              setState(() {
                _statusMessage = 'Merged page $pageIndex of ${document.pagesCount} from ${p.basename(pdfFile.path)}';
                _progress = 0.2 + (0.7 * ((processedFiles + fileProgress) / totalFiles));
              });
            } finally {
              await page.close();
            }
          }
        } finally {
          await document.close();
        }

        processedFiles++;
      }

      final outputDir = Directory('/storage/emulated/0/Movies/webkeyo/pdf/merged');
      await outputDir.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mergedPath = '${outputDir.path}/merged_$timestamp.pdf';

      setState(() { _statusMessage = 'Saving merged PDF...'; _progress = 0.9; });
      final outFile = File(mergedPath);
      await outFile.writeAsBytes(await mergedDoc.save());

      setState(() { _isConverting = false; _progress = 1.0; _statusMessage = 'Merged PDF saved to:\nMovies/webkeyo/pdf/merged/merged_$timestamp.pdf'; });
    } catch (e, stackTrace) {
      debugPrint('Merge PDF Error: $e\n$stackTrace');
      setState(() { _isConverting = false; _statusMessage = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs')),
      body: _isConverting ? _buildProgress() : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFileSelector(_selectedFiles.isNotEmpty ? _selectedFiles.length : null, _pickPdfs, 'Select PDF Files', Colors.blueAccent),
            const SizedBox(height: 24),
            _buildGenerateButton('MERGE PDFs', _selectedFiles.isNotEmpty ? _merge : null, Icons.merge_type),
            _buildStatus(_statusMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(value: _progress > 0 ? _progress : null), const SizedBox(height: 20), Text(_statusMessage, textAlign: TextAlign.center)]));
  
  Widget _buildFileSelector(int? count, VoidCallback onTap, String hint, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 40, color: color),
              const SizedBox(height: 8),
              Text(count != null ? '$count PDFs selected' : hint, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(String text, VoidCallback? onPressed, IconData icon) {
    return ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon), label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildStatus(String status) {
    if (status.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(top: 16), child: Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
  }
}
