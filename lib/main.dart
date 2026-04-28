import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'services/provider_registry.dart';

/// Global theme state management using Hive for persistence.
class ThemeNotifier extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  static const String _themeKey = 'is_dark_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    final isDark = box.get(_themeKey, defaultValue: true) as bool;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final box = Hive.box(_boxName);
    await box.put(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  bool get isDark => _themeMode == ThemeMode.dark;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  await Hive.initFlutter();

  // Initialize provider registry
  final providerRegistry = ProviderRegistry();
  await providerRegistry.init();

  // Initialize theme
  final themeNotifier = ThemeNotifier();
  await themeNotifier.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: providerRegistry),
        ChangeNotifierProvider.value(value: themeNotifier),
      ],
      child: const GlobalMediaApp(),
    ),
  );
}

class GlobalMediaApp extends StatefulWidget {
  const GlobalMediaApp({super.key});

  @override
  State<GlobalMediaApp> createState() => _GlobalMediaAppState();
}

class _GlobalMediaAppState extends State<GlobalMediaApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions on Android
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
    // Android 11+ needs MANAGE_EXTERNAL_STORAGE for public directory writes
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
    // Android 13+ granular media permissions
    await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();

    return MaterialApp(
      title: 'Webkeyo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      home: const HomeScreen(),
    );
  }
}
