import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../data/database.dart';
import '../models/priority.dart';

enum RepeatType { daily, weekly, monthly }

/// Dialog for adding or editing tasks
class AddTaskDialog extends StatefulWidget {
  final Function(List<TasksCompanion>) onSave;
  final Task? existingTask;
  final DateTime? initialDate;

  const AddTaskDialog({
    super.key,
    required this.onSave,
    this.existingTask,
    this.initialDate,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late Priority _priority;
  late Color _selectedColor;
  late DateTime _dueDate;
  bool _isRepeating = false;
  DateTime? _repeatEndDate;
  bool _isReminderActive = false;
  int _reminderMinutesBefore = 0;

  // New Repetition State
  RepeatType _repeatType = RepeatType.daily;
  final Set<int> _selectedWeekDays = {}; // 1 (Mon) - 7 (Sun)
  final Set<int> _selectedMonthDays = {}; // 1 - 31

  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFF44336), // Red
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFE91E63), // Pink
    const Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _priority = task != null
        ? Priority.fromString(task.priority)
        : Priority.medium;
    _selectedColor = task != null ? Color(task.color) : const Color(0xFF2196F3);
    _dueDate = task?.dueDate ?? widget.initialDate ?? DateTime.now();
    _isRepeating = task?.isRepeating ?? false;
    _repeatEndDate = task?.repeatEndDate;
    _isReminderActive = task?.isReminderActive ?? false;
    _reminderMinutesBefore = task?.reminderMinutesBefore ?? 0;
    // Default repetition values
    if (_dueDate.weekday != 0) _selectedWeekDays.add(_dueDate.weekday);
    if (_dueDate.day != 0) _selectedMonthDays.add(_dueDate.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        // Update defaults if empty
        if (_selectedWeekDays.isEmpty) _selectedWeekDays.add(_dueDate.weekday);
        if (_selectedMonthDays.isEmpty) _selectedMonthDays.add(_dueDate.day);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _selectRepeatEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatEndDate ?? _dueDate.add(const Duration(days: 7)),
      firstDate: _dueDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _repeatEndDate = picked);
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_isRepeating && _repeatEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a repeat until date')),
        );
        return;
      }

      if (_isRepeating &&
          _repeatType == RepeatType.weekly &&
          _selectedWeekDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one day of the week'),
          ),
        );
        return;
      }

      if (_isRepeating &&
          _repeatType == RepeatType.monthly &&
          _selectedMonthDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one day of the month'),
          ),
        );
        return;
      }

      final List<TasksCompanion> tasksToSave = [];
      final String? repeatId = _isRepeating ? const Uuid().v4() : null;

      if (!_isRepeating) {
        tasksToSave.add(_createTaskCompanion(_dueDate, repeatId));
      } else {
        // Generate instances
        DateTime currentDate = DateTime(
          _dueDate.year,
          _dueDate.month,
          _dueDate.day,
        );
        final end = DateTime(
          _repeatEndDate!.year,
          _repeatEndDate!.month,
          _repeatEndDate!.day,
        );

        // Safety cap (e.g. 365 days) to preventing infinite loops or massive creates
        int count = 0;
        const int maxLimit = 365 * 2; // 2 years max

        while (currentDate.isBefore(end.add(const Duration(days: 1))) &&
            count < maxLimit) {
          bool shouldAdd = false;

          if (_repeatType == RepeatType.daily) {
            shouldAdd = true;
          } else if (_repeatType == RepeatType.weekly) {
            if (_selectedWeekDays.contains(currentDate.weekday)) {
              shouldAdd = true;
            }
          } else if (_repeatType == RepeatType.monthly) {
            if (_selectedMonthDays.contains(currentDate.day)) {
              shouldAdd = true;
            }
          }

          if (shouldAdd) {
            // Adjust time to match _dueDate time
            final taskDate = DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              _dueDate.hour,
              _dueDate.minute,
            );
            tasksToSave.add(_createTaskCompanion(taskDate, repeatId));
          }

          currentDate = currentDate.add(const Duration(days: 1));
          count++;
        }
      }

      final FutureOr<void> result = widget.onSave(tasksToSave);
      if (result is Future) {
        await result;
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  TasksCompanion _createTaskCompanion(DateTime date, String? repeatId) {
    return TasksCompanion(
      title: drift.Value(_titleController.text.trim()),
      description: drift.Value(
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
      color: drift.Value(_selectedColor.toARGB32()),
      priority: drift.Value(_priority.label),
      dueDate: drift.Value(date),
      isRepeating: drift.Value(_isRepeating),
      repeatEndDate: _isRepeating && _repeatEndDate != null
          ? drift.Value(_repeatEndDate)
          : const drift.Value(null),
      repeatId: drift.Value(repeatId),
      isReminderActive: drift.Value(_isReminderActive),
      reminderMinutesBefore: drift.Value(_reminderMinutesBefore),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingTask != null ? 'Edit Task' : 'New Task',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'What needs to be done?',
                  prefixIcon: Icon(Icons.task_alt),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add more details...',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Color picker
              const Text(
                'Color',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: _colorOptions.map((color) {
                  final isSelected =
                      _selectedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Priority
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<Priority>(
                segments: Priority.values
                    .map(
                      (p) => ButtonSegment(
                        value: p,
                        label: Text(p.label),
                        icon: Icon(
                          p == Priority.high
                              ? Icons.arrow_upward
                              : p == Priority.low
                              ? Icons.arrow_downward
                              : Icons.remove,
                          size: 16,
                        ),
                      ),
                    )
                    .toList(),
                selected: {_priority},
                onSelectionChanged: (set) {
                  setState(() => _priority = set.first);
                },
              ),
              const SizedBox(height: 24),

              // Due Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Due Date'),
                subtitle: Text(
                  '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
              // Due Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Due Time'),
                subtitle: Text(
                  '${_dueDate.hour.toString().padLeft(2, '0')}:${_dueDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectTime,
              ),
              const Divider(),

              // Reminder Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_active),
                title: const Text('Set Reminder'),
                subtitle: const Text('Notify me before due time'),
                value: _isReminderActive,
                onChanged: (value) {
                  setState(() => _isReminderActive = value);
                },
              ),

              // Reminder offset selector
              if (_isReminderActive)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: DropdownButtonFormField<int>(
                    initialValue: _reminderMinutesBefore,
                    decoration: const InputDecoration(
                      labelText: 'Remind me',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('At due time')),
                      DropdownMenuItem(value: 5, child: Text('5 min before')),
                      DropdownMenuItem(value: 10, child: Text('10 min before')),
                      DropdownMenuItem(value: 15, child: Text('15 min before')),
                      DropdownMenuItem(value: 30, child: Text('30 min before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                      DropdownMenuItem(
                        value: 1440,
                        child: Text('1 day before'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _reminderMinutesBefore = value);
                      }
                    },
                  ),
                ),
              const Divider(),

              // Repeat toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat Task'),
                subtitle: Text(
                  widget.existingTask?.repeatId != null
                      ? 'Recurring settings cannot be changed during edit'
                      : 'Create recurring tasks',
                ),
                value: _isRepeating,
                onChanged: widget.existingTask?.repeatId != null
                    ? null
                    : (value) {
                        setState(() => _isRepeating = value);
                      },
              ),

              if (_isRepeating) ...[
                const SizedBox(height: 16),
                const Text(
                  'Frequency',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<RepeatType>(
                  segments: const [
                    ButtonSegment(
                      value: RepeatType.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: RepeatType.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment(
                      value: RepeatType.monthly,
                      label: Text('Monthly'),
                    ),
                  ],
                  selected: {_repeatType},
                  onSelectionChanged: widget.existingTask?.repeatId != null
                      ? null
                      : (Set<RepeatType> newSelection) {
                          setState(() {
                            _repeatType = newSelection.first;
                          });
                        },
                ),
                const SizedBox(height: 16),

                if (_repeatType == RepeatType.weekly) ...[
                  const Text(
                    'Repeat on',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (index) {
                      final dayIndex = index + 1; // 1 = Mon, 7 = Sun
                      final dayName = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][index];
                      final isSelected = _selectedWeekDays.contains(dayIndex);
                      return FilterChip(
                        label: Text(dayName),
                        selected: isSelected,
                        onSelected: widget.existingTask?.repeatId != null
                            ? null
                            : (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedWeekDays.add(dayIndex);
                                  } else {
                                    _selectedWeekDays.remove(dayIndex);
                                  }
                                });
                              },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_repeatType == RepeatType.monthly) ...[
                  const Text(
                    'Repeat on day(s)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200, // Limit height for Month grid
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemCount: 31,
                      itemBuilder: (context, index) {
                        final dayNum = index + 1;
                        final isSelected = _selectedMonthDays.contains(dayNum);
                        return InkWell(
                          onTap: widget.existingTask?.repeatId != null
                              ? null
                              : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedMonthDays.remove(dayNum);
                                    } else {
                                      _selectedMonthDays.add(dayNum);
                                    }
                                  });
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : null,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat),
                  title: const Text('Repeat Until'),
                  subtitle: Text(
                    _repeatEndDate != null
                        ? '${_repeatEndDate!.day}/${_repeatEndDate!.month}/${_repeatEndDate!.year}'
                        : 'Select End Date',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _repeatEndDate == null ? Colors.red : null,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectRepeatEndDate,
                ),
              ],
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.existingTask != null ? 'Save Changes' : 'Add Task',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
