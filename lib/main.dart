import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'data/database.dart';
import 'theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _checkIntroStatus();
  }

  Future<void> _checkIntroStatus() async {
    final settings = await database.getSettings();
    setState(() {
      _showIntro = !settings.hasSeenIntro;
      _isLoading = false;
    });
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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Task Scheduler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: _showIntro
          ? IntroScreen(onComplete: _onIntroComplete)
          : const MainShell(),
    );
  }
}
