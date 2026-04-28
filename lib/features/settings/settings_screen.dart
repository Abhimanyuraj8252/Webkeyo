import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'providers_screen.dart';
import '../../core/constants.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _videoResolution = '1080p';
  String _exportPath = '/Movies/Webkeyo/';

  static const _prefResKey = 'global_video_resolution';
  static const _prefPathKey = 'global_export_path';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _videoResolution = prefs.getString(_prefResKey) ?? '1080p';
      _exportPath = prefs.getString(_prefPathKey) ?? '/Movies/Webkeyo/';
    });
  }

  Future<void> _saveResolution(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefResKey, value);
    setState(() => _videoResolution = value);
  }

  Future<void> _saveExportPath(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPathKey, value);
    setState(() => _exportPath = value);
  }

  void _showResolutionDialog() {
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Video Resolution', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        children: [
          _resOption(ctx, '720p', '1280×720 — Standard HD'),
          _resOption(ctx, '1080p', '1920×1080 — Full HD (recommended)'),
          _resOption(ctx, '1440p', '2560×1440 — Quad HD'),
          _resOption(ctx, '4K', '3840×2160 — Ultra HD'),
        ],
      ),
    ).then((val) {
      if (val != null) _saveResolution(val);
    });
  }

  SimpleDialogOption _resOption(BuildContext ctx, String value, String desc) {
    final selected = _videoResolution == value;
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_on : Icons.radio_button_off,
            color: selected ? Theme.of(context).colorScheme.primary : null,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                Text(desc, style: GoogleFonts.inter(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExportPath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Video Export Folder',
    );
    if (path != null) {
      await _saveExportPath(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export path updated: $path')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          _buildSectionHeader(theme, 'AI Configuration'),
          Card(
            child: ListTile(
              leading: Icon(Icons.hub, color: theme.primaryColor),
              title: const Text('AI Providers & Models'),
              subtitle: const Text('Configure OpenRouter, Groq, TTS, etc.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProvidersScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          _buildSectionHeader(theme, 'Appearance'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    themeNotifier.isDark ? 'Dark theme active' : 'Light theme active',
                    style: theme.textTheme.bodyMedium,
                  ),
                  secondary: Icon(
                    themeNotifier.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: theme.primaryColor,
                  ),
                  value: themeNotifier.isDark,
                  activeThumbColor: theme.primaryColor,
                  onChanged: (_) => themeNotifier.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          _buildSectionHeader(theme, 'Output'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.high_quality_rounded, color: theme.primaryColor),
                  title: const Text('Video Resolution'),
                  subtitle: Text(_videoResolution),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showResolutionDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.folder_outlined, color: theme.primaryColor),
                  title: const Text('Export Path'),
                  subtitle: Text(
                    _exportPath,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: _pickExportPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),

          _buildSectionHeader(theme, 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: theme.primaryColor),
                  title: const Text('Webkeyo'),
                  subtitle: Text(
                    'AI-Powered Manga & Study Video Generator\nVersion 1.0.0',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingXLarge),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.primaryColor,
        ),
      ),
    );
  }
}
