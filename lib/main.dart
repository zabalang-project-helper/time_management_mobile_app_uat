import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'data/database.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'services/notification_service.dart';
import 'screens/intro_screen.dart';
import 'screens/main_shell.dart';
import 'screens/today_tasks_screen.dart' show database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showIntro = true;
  bool _isLoading = true;
  final ThemeNotifier _themeNotifier = ThemeNotifier();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Load theme preference
    await _themeNotifier.loadTheme();

    // Initialize notifications with tap handler
    await NotificationService().init(
      onTap: (payload) {
        if (payload == 'pomodoro') {
          // Navigate to Focus tab (index 0)
          MainShell.tabNotifier.value = 0;
        }
      },
    );
    await NotificationService().requestPermissions();

    // Check intro status
    final settings = await database.getSettings();

    if (mounted) {
      setState(() {
        _showIntro = !settings.hasSeenIntro;
        _isLoading = false;
      });
    }
  }

  void _onIntroComplete() async {
    await database.updateSettings(
      const AppSettingsCompanion(hasSeenIntro: drift.Value(true)),
    );
    setState(() => _showIntro = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading screen that adapts to system theme initially or just dark/light default
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'TimeOptimize',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: _showIntro
              ? IntroScreen(onComplete: _onIntroComplete)
              : const MainShell(),
        );
      },
    );
  }
}
