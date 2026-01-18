import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../data/database.dart';

/// ViewModel for managing app settings
class SettingsViewModel extends ChangeNotifier {
  final AppDatabase _db;
  AppSetting? _settings;

  SettingsViewModel(this._db) {
    _loadSettings();
  }

  AppSetting? get settings => _settings;

  int get pomodoroMinutes => _settings?.pomodoroMinutes ?? 25;
  int get shortBreakMinutes => _settings?.shortBreakMinutes ?? 5;
  int get longBreakMinutes => _settings?.longBreakMinutes ?? 15;
  bool get hasSeenIntro => _settings?.hasSeenIntro ?? false;

  Future<void> _loadSettings() async {
    _settings = await _db.getSettings();
    notifyListeners();
  }

  Future<void> updatePomodoroTime(int minutes) async {
    await _db.updateSettings(
      AppSettingsCompanion(pomodoroMinutes: Value(minutes)),
    );
    await _loadSettings();
  }

  Future<void> updateShortBreakTime(int minutes) async {
    await _db.updateSettings(
      AppSettingsCompanion(shortBreakMinutes: Value(minutes)),
    );
    await _loadSettings();
  }

  Future<void> updateLongBreakTime(int minutes) async {
    await _db.updateSettings(
      AppSettingsCompanion(longBreakMinutes: Value(minutes)),
    );
    await _loadSettings();
  }

  Future<void> markIntroSeen() async {
    await _db.updateSettings(
      const AppSettingsCompanion(hasSeenIntro: Value(true)),
    );
    await _loadSettings();
  }
}
