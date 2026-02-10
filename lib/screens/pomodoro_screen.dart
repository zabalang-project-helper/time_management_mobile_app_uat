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

enum PomodoroPhase {
  focus,
  shortBreak,
  longBreak,
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Timer settings
  int _pomodoroMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;

  // Sound player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Selected task (by ID to handle updates)
  int? _selectedTaskId;
  Task? _cachedTask; // For display purposes

  int _totalSessions = 3;      // user selects 1–4
  int _currentSession = 1;     // starts at 1
  PomodoroPhase _phase = PomodoroPhase.focus;

  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _hasStartedOnce = false;
  Timer? _timer;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await database.getSettings();
    setState(() {
      _pomodoroMinutes = settings.pomodoroMinutes;
      _shortBreakMinutes = settings.shortBreakMinutes;
      _longBreakMinutes = settings.longBreakMinutes;

      _remainingSeconds = _pomodoroMinutes * 60;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;

    if (!_hasStartedOnce) {
      _remainingSeconds = _getPhaseDuration() * 60;
      _hasStartedOnce = true;
    }

    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    _isRunning = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining =
          (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).ceil();

      if (remaining > 0) {
        setState(() => _remainingSeconds = remaining);
      } else {
        _timer?.cancel();
        _onPhaseComplete();
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
      _currentSession = 1;
      _isRunning = false;
      _hasStartedOnce = false;
      _phase = PomodoroPhase.focus;
      _remainingSeconds = _getPhaseDuration() * 60;
    });
  }

  void _playSound() async {
    try {
      // Plays a default system sound or asset if available.
      // Since we don't know if the user added assets, we can try to play a source,
      // or just leave a placeholder logic.
      // Assuming user might add 'assets/sounds/ding.mp3', otherwise this might fail silently or log error.
      // For now, let's try to play a reliable source or catch error.
      // We will assume the user has configured assets in pubspec.yaml as requested.
      await _audioPlayer.play(AssetSource('sounds/alarms_rings.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _onPhaseComplete() {
    _playSound();

    setState(() {
      _isRunning = false;

      if (_phase == PomodoroPhase.focus) {
        if (_currentSession < _totalSessions) {
          // Focus → Short Break
          _phase = PomodoroPhase.shortBreak;
        } else {
          // Last focus → Long Break
          _phase = PomodoroPhase.longBreak;
        }
      } else if (_phase == PomodoroPhase.shortBreak) {
        // Break → Next Focus
        _currentSession++;
        _phase = PomodoroPhase.focus;
      } else {
        // Long break finished → reset cycle
        _resetTimer();
        return;
      }
    });

    _hasStartedOnce = false;

    // Auto-start next phase only if it's NOT the long break finishing after last session
    if (!(_phase == PomodoroPhase.focus && _currentSession == 1 && !_isRunning)) {
      _startTimer();
    }
  }

  int _getPhaseDuration() {
    switch (_phase) {
      case PomodoroPhase.focus:
        return _pomodoroMinutes;
      case PomodoroPhase.shortBreak:
        return _shortBreakMinutes;
      case PomodoroPhase.longBreak:
        return _longBreakMinutes;
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    final progress = (_remainingSeconds / (_getPhaseDuration() * 60)).clamp(0.0, 1.0);
    bool showTimer = _phase != PomodoroPhase.focus || _hasStartedOnce;
    return Scaffold(
      backgroundColor: _phase == PomodoroPhase.focus
        ? Theme.of(context).scaffoldBackgroundColor
        : _phase == PomodoroPhase.shortBreak
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _phase == PomodoroPhase.focus
                      ? 'Focus'
                      : _phase == PomodoroPhase.shortBreak
                          ? 'Short Break'
                          : 'Long Break',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Timer display (fixed size, never squashes)
            SizedBox(
              height: 320,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _phase == PomodoroPhase.focus
                              ? AppTheme.primaryColor
                              : AppTheme.successColor,
                        ),
                      ),
                    ),

                    // Center content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1️⃣ Show countdown only when running
                        if (showTimer)
                          Text(
                            _formatTime(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2,
                            ),
                          )
                        else
                          // 2️⃣ Show TimeEditChip before start
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TimeEditChip(
                                label: 'Focus',
                                value: _pomodoroMinutes,
                                isActive: true,
                                onChanged: (v) async {
                                  setState(() => _pomodoroMinutes = v);
                                  _remainingSeconds = _getPhaseDuration() * 60;
                                  await database.updateSettings(
                                    AppSettingsCompanion(
                                      pomodoroMinutes: drift.Value(v),
                                    ),
                                  );
                                },
                              ),
                              _TimeEditChip(
                                label: 'Break',
                                value: _shortBreakMinutes,
                                isActive: true,
                                onChanged: (v) async {
                                  setState(() => _shortBreakMinutes = v);
                                  await database.updateSettings(
                                    AppSettingsCompanion(
                                      shortBreakMinutes: drift.Value(v),
                                    ),
                                  );
                                },
                              ),
                              _TimeEditChip(
                                label: 'Long Break',
                                value: _longBreakMinutes,
                                isActive: true,
                                onChanged: (v) async {
                                  setState(() => _shortBreakMinutes = v);
                                  await database.updateSettings(
                                    AppSettingsCompanion(
                                      longBreakMinutes: drift.Value(v),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                        const SizedBox(height: 12),

                        // Phase text
                        Text(
                          _phase == PomodoroPhase.focus
                              ? 'Focus ($_currentSession / $_totalSessions)'
                              : _phase == PomodoroPhase.shortBreak
                                  ? 'Break'
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
            if (_phase == PomodoroPhase.focus)
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
                        backgroundColor: _phase == PomodoroPhase.focus
                            ? AppTheme.primaryColor
                            : AppTheme.successColor,
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        size: 40,
                      ),
                    ),
                  ),

                  // Sessions button (only show when timer not running)
                  if (!_isRunning) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            // Cycle _totalSessions from 1 -> 4
                            _totalSessions = _totalSessions < 4 ? _totalSessions + 1 : 1;
                          });
                        },
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          backgroundColor: Colors.grey.shade300,
                        ),
                        child: Text(
                          '$_totalSessions',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _TimeEditChip extends StatelessWidget {
  final String label;
  final int value;
  final bool isActive;
  final ValueChanged<int> onChanged;

  const _TimeEditChip({
    required this.label,
    required this.value,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: isActive
                ? () async {
                    final newValue = await showDialog<int>(
                      context: context,
                      builder: (context) {
                        int temp = value; // only declare once
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 40), // smaller dialog
                              title: Text('Set $label (minutes)'),
                              content: SizedBox(
                                width: 180, // smaller width
                                child: Column(
                                  mainAxisSize: MainAxisSize.min, // shrink height to content
                                  children: [
                                    Slider(
                                      value: temp.toDouble(),
                                      min: 1,
                                      max: 120,
                                      divisions: 119,
                                      label: temp.toString(),
                                      onChanged: (v) => setState(() => temp = v.round()),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      temp.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                  onPressed: () => Navigator.pop(context, temp),
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );

                    if (newValue != null) {
                      onChanged(newValue);
                    }
                  }
                : null, // do nothing if inactive
            child: Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.15)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
