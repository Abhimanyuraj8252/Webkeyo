import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/billing_service.dart';
import 'services/engagement_service.dart';
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
  // Sentry crash reporting (free tier) is OFF unless a DSN is passed
  // at build time: flutter build apk --dart-define=SENTRY_DSN=https://...
  // No DSN is ever hardcoded. The app works fully without it.
  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
      },
      appRunner: () => runApp(const AppRoot()),
    );
  } else {
    runApp(const AppRoot());
  }
}

/// Root widget: shows a splash screen immediately (never a black
/// screen), boots the local services in the background with timeouts,
/// then shows onboarding on first run or the home screen.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

enum _BootState { loading, ready, failed }

class _AppRootState extends State<AppRoot> {
  _BootState _state = _BootState.loading;
  String _bootLabel = 'Starting Webkeyo…';
  String? _bootError;
  ProviderRegistry? _providerRegistry;
  ThemeNotifier? _themeNotifier;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Each step gets its own timeout — a slow disk or a stuck Hive box
    // must never leave the user on a black screen.
    try {
      setState(() => _bootLabel = 'Opening local storage…');
      await Hive.initFlutter().timeout(const Duration(seconds: 10));

      setState(() => _bootLabel = 'Loading providers…');
      final registry = ProviderRegistry();
      await registry.init().timeout(const Duration(seconds: 15));

      setState(() => _bootLabel = 'Loading theme…');
      final themeNotifier = ThemeNotifier();
      await themeNotifier.init().timeout(const Duration(seconds: 10));

      setState(() => _bootLabel = 'Loading usage & streaks…');
      final billing = BillingService();
      await billing.init().timeout(const Duration(seconds: 10));
      final engagement = EngagementService();
      await engagement.init().timeout(const Duration(seconds: 10));

      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 10));
      final done = prefs.getBool('webkeyo_onboarding_done') ?? false;

      if (!mounted) return;
      setState(() {
        _providerRegistry = registry;
        _themeNotifier = themeNotifier;
        _showOnboarding = !done;
        _state = _BootState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootError = e.toString();
        _state = _BootState.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _BootState.loading:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: _SplashScreen(label: _bootLabel),
        );
      case _BootState.failed:
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: _BootFailedScreen(
            error: _bootError ?? 'Unknown error',
            onRetry: () {
              setState(() {
                _state = _BootState.loading;
                _bootError = null;
              });
              _boot();
            },
          ),
        );
      case _BootState.ready:
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _providerRegistry!),
            ChangeNotifierProvider.value(value: _themeNotifier!),
          ],
          child: GlobalMediaApp(showOnboarding: _showOnboarding),
        );
    }
  }
}

class _SplashScreen extends StatelessWidget {
  final String label;
  const _SplashScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_creation_outlined, size: 72),
            const SizedBox(height: 16),
            Text(
              'Webkeyo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _BootFailedScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _BootFailedScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              const Text('Webkeyo could not start.'),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalMediaApp extends StatefulWidget {
  final bool showOnboarding;
  const GlobalMediaApp({super.key, this.showOnboarding = false});

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
      home: widget.showOnboarding
          ? const OnboardingScreen()
          : const HomeScreen(),
    );
  }
}
