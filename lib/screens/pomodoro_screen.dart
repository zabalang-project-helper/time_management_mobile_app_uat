import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:audioplayers/audioplayers.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import 'today_tasks_screen.dart' show database;

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // Timer settings
  int _pomodoroMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;

  // Timer state
  int _currentSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;
  _TimerMode _timerMode = _TimerMode.focus;

  // Sound player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Selected task (by ID to handle updates)
  int? _selectedTaskId;
  Task? _cachedTask; // For display purposes

  int _sessionTimeSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await database.getSettings();
    setState(() {
      _pomodoroMinutes = settings.pomodoroMinutes;
      _shortBreakMinutes = settings.shortBreakMinutes;
      _longBreakMinutes = settings.longBreakMinutes;
      _currentSeconds = _pomodoroMinutes * 60;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentSeconds > 0) {
        setState(() {
          _currentSeconds--;
          if (_timerMode == _TimerMode.focus) {
            _sessionTimeSpent++;
          }
        });
      } else {
        _timer?.cancel();
        _onTimerComplete();
      }
    });
    setState(() {});
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _currentSeconds = _getModeDuration() * 60;
    });
  }

  int _getModeDuration() {
    switch (_timerMode) {
      case _TimerMode.focus:
        return _pomodoroMinutes;
      case _TimerMode.shortBreak:
        return _shortBreakMinutes;
      case _TimerMode.longBreak:
        return _longBreakMinutes;
    }
  }

  void _playSound() async {
    try {
      // Plays a default system sound or asset if available.
      // Since we don't know if the user added assets, we can try to play a source,
      // or just leave a placeholder logic.
      // Assuming user might add 'assets/sounds/ding.mp3', otherwise this might fail silently or log error.
      // For now, let's try to play a reliable source or catch error.
      // We will assume the user has configured assets in pubspec.yaml as requested.
      await _audioPlayer.play(AssetSource('sounds/ding.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _onTimerComplete() async {
    _playSound();

    // Save session if focus mode
    if (_timerMode == _TimerMode.focus && _selectedTaskId != null) {
      await database.insertPomodoroSession(
        PomodoroSessionsCompanion(
          taskId: drift.Value(_selectedTaskId!),
          durationSeconds: drift.Value(_sessionTimeSpent),
        ),
      );
      await database.addTimeToTask(_selectedTaskId!, _sessionTimeSpent);
      _sessionTimeSpent = 0;
    }

    setState(() => _isRunning = false);

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _timerMode == _TimerMode.focus
                ? 'Focus session complete! Take a break.'
                : 'Break is over! Ready to focus?',
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  void _switchMode(_TimerMode mode) {
    _timer?.cancel();
    setState(() {
      _timerMode = mode;
      _isRunning = false;
      _currentSeconds = _getModeDuration() * 60;
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _showSettingsDialog() async {
    int tempPomodoro = _pomodoroMinutes;
    int tempShortBreak = _shortBreakMinutes;
    int tempLongBreak = _longBreakMinutes;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Settings (Max 120m)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingTile(
                label: 'Focus Time',
                value: tempPomodoro,
                onChanged: (v) => tempPomodoro = v,
              ),
              _SettingTile(
                label: 'Short Break',
                value: tempShortBreak,
                onChanged: (v) => tempShortBreak = v,
              ),
              _SettingTile(
                label: 'Long Break',
                value: tempLongBreak,
                onChanged: (v) => tempLongBreak = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await database.updateSettings(
                AppSettingsCompanion(
                  pomodoroMinutes: drift.Value(tempPomodoro),
                  shortBreakMinutes: drift.Value(tempShortBreak),
                  longBreakMinutes: drift.Value(tempLongBreak),
                ),
              );
              setState(() {
                _pomodoroMinutes = tempPomodoro;
                _shortBreakMinutes = tempShortBreak;
                _longBreakMinutes = tempLongBreak;
                _currentSeconds = _getModeDuration() * 60;
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _markTaskComplete() async {
    if (_selectedTaskId == null) return;

    final task = _cachedTask;
    if (task != null) {
      await database.markTaskComplete(task);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${task.title}" marked as complete!')),
        );
        setState(() => _selectedTaskId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentSeconds / (_getModeDuration() * 60);

    return Scaffold(
      backgroundColor: _timerMode == _TimerMode.focus
          ? Theme.of(context).scaffoldBackgroundColor
          : _timerMode == _TimerMode.shortBreak
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            // Header with settings
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Focus',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _showSettingsDialog,
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
            ),

            // Mode selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<_TimerMode>(
                segments: const [
                  ButtonSegment(
                    value: _TimerMode.focus,
                    label: Text('Focus'),
                    icon: Icon(Icons.psychology, size: 16),
                  ),
                  ButtonSegment(
                    value: _TimerMode.shortBreak,
                    label: Text('Short'),
                    icon: Icon(Icons.coffee, size: 16),
                  ),
                  ButtonSegment(
                    value: _TimerMode.longBreak,
                    label: Text('Long'),
                    icon: Icon(Icons.self_improvement, size: 16),
                  ),
                ],
                selected: {_timerMode},
                onSelectionChanged: (set) => _switchMode(set.first),
              ),
            ),
            const SizedBox(height: 40),

            // Timer display
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _timerMode == _TimerMode.focus
                              ? AppTheme.primaryColor
                              : AppTheme.successColor,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(_currentSeconds),
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          _timerMode == _TimerMode.focus
                              ? 'Focus Time'
                              : _timerMode == _TimerMode.shortBreak
                              ? 'Short Break'
                              : 'Long Break',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Task selector (only in focus mode)
            if (_timerMode == _TimerMode.focus)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Task>>(
                  stream: database.watchTodayTasks(),
                  builder: (context, snapshot) {
                    final tasks = (snapshot.data ?? [])
                        .where((t) => !t.isCompleted)
                        .toList();

                    // Find current task by ID if it exists
                    Task? currentSelectedTask;
                    if (_selectedTaskId != null) {
                      final matchingTasks = tasks.where(
                        (t) => t.id == _selectedTaskId,
                      );
                      if (matchingTasks.isNotEmpty) {
                        currentSelectedTask = matchingTasks.first;
                        _cachedTask = currentSelectedTask;
                      } else {
                        // Task no longer available
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedTaskId != null) {
                            setState(() => _selectedTaskId = null);
                          }
                        });
                      }
                    }

                    return Column(
                      children: [
                        DropdownButtonFormField<int?>(
                          value: currentSelectedTask?.id,
                          decoration: const InputDecoration(
                            labelText: 'Select task to focus on',
                            prefixIcon: Icon(Icons.task_alt),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No task selected'),
                            ),
                            ...tasks.map(
                              (t) => DropdownMenuItem<int?>(
                                value: t.id,
                                child: Text(
                                  t.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (taskId) {
                            setState(() => _selectedTaskId = taskId);
                          },
                        ),
                        if (_selectedTaskId != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _markTaskComplete,
                            icon: const Icon(Icons.check),
                            label: const Text('Mark Complete'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset button
                  IconButton.filled(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Play/Pause button
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: FilledButton(
                      onPressed: _isRunning ? _pauseTimer : _startTimer,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: _timerMode == _TimerMode.focus
                            ? AppTheme.primaryColor
                            : AppTheme.successColor,
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        size: 40,
                      ),
                    ),
                  ),
                  // Skip button removed as requested
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SettingTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  late int _currentValue;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSliderChange(double value) {
    final intValue = value.round();
    setState(() {
      _currentValue = intValue;
      _controller.text = intValue.toString();
    });
    widget.onChanged(intValue);
  }

  void _handleTextChange(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      final clamped = parsed.clamp(1, 120);
      setState(() {
        _currentValue = clamped;
      });
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label),
            SizedBox(
              width: 60,
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    // Reset text to strict value on blur to ensure consistency
                    _controller.text = _currentValue.toString();
                  }
                },
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    suffixText: 'm',
                  ),
                  onChanged: _handleTextChange,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _currentValue.toDouble(),
          min: 1,
          max: 120,
          onChanged: _handleSliderChange,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

enum _TimerMode { focus, shortBreak, longBreak }
