import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_management_mobile_app/widgets/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'data/database.dart';
import 'theme/app_theme.dart';
import 'screens/intro_screen.dart';
import 'screens/main_shell.dart';
import 'screens/today_tasks_screen.dart' show database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await NotificationService.instance.init();
  if (Platform.isAndroid) {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      print('Notification permission status: $status');
    }
  }
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
    return FutureBuilder(
      future: _isLoading ? null : Future.value(true),
      builder: (context, _) {
        if (_isLoading) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return StreamBuilder<AppSetting>(
          stream: database.watchSettings(),
          builder: (context, snapshot) {
            final settings = snapshot.data;
            final themeModeString = settings?.themeMode ?? 'system';

            ThemeMode themeMode;
            switch (themeModeString) {
              case 'light':
                themeMode = ThemeMode.light;
                break;
              case 'dark':
                themeMode = ThemeMode.dark;
                break;
              case 'system':
              default:
                themeMode = ThemeMode.system;
            }

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
      },
    );
  }
}
