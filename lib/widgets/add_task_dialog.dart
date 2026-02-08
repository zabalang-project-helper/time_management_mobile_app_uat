import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_management_mobile_app/screens/today_tasks_screen.dart';
import 'package:uuid/uuid.dart';
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
  int? _selectedCategoryId;
  late Color _selectedColor;
  late DateTime _dueDate;
  bool _isRepeating = false;
  bool _isReminding = false;
  DateTime? _repeatEndDate;

  // New Repetition State
  RepeatType _repeatType = RepeatType.daily;
  final Set<int> _selectedWeekDays = {}; // 1 (Mon) - 7 (Sun)
  final Set<int> _selectedMonthDays = {}; // 1 - 31

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
    _selectedCategoryId = task?.categoryId;
    _selectedColor = task != null ? Color(task.color) : const Color(0xFF2196F3);
    _dueDate = task?.dueDate ?? widget.initialDate ?? DateTime.now();
    _isRepeating = task?.isRepeating ?? false;
    _repeatEndDate = task?.repeatEndDate;
    // Default repetition values
    if (_dueDate.weekday != 0) _selectedWeekDays.add(_dueDate.weekday);
    if (_dueDate.day != 0) _selectedMonthDays.add(_dueDate.day);
    _isReminding = task?.isReminding ?? false;
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

  void _submit() {
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

      widget.onSave(tasksToSave);
      Navigator.pop(context);
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
      categoryId: drift.Value(_selectedCategoryId),
      color: drift.Value(_selectedColor.toARGB32()),
      priority: drift.Value(_priority.label),
      dueDate: drift.Value(date),
      isRepeating: drift.Value(_isRepeating),
      repeatEndDate: _isRepeating && _repeatEndDate != null
          ? drift.Value(_repeatEndDate)
          : const drift.Value(null),
      repeatId: drift.Value(repeatId),
      isReminding: drift.Value(_isReminding),
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

              // Category picker
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              StreamBuilder<List<Category>>(
                stream: database.watchAllCategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  final categories = snapshot.data!;

                  return DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: "Select A Category",
                      border: const OutlineInputBorder(),
                      suffixIcon: _selectedCategoryId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _selectedColor = Colors.grey;
                                });
                              },
                            )
                          : null,
                    ),

                    items: [
                      // Categories
                      ...categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.id,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(cat.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }),
                    ],

                    onChanged: (value) async {
                      final selected = categories.firstWhere((c) => c.id == value);

                      setState(() {
                        _selectedCategoryId = value;
                        _selectedColor = Color(selected.color);
                      });
                    },
                  );
                },
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
              const Divider(),

              // Repeat toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat Task'),
                subtitle: const Text('Create recurring tasks'),
                value: _isRepeating,
                onChanged: (value) {
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
                  onSelectionChanged: (Set<RepeatType> newSelection) {
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
                        onSelected: (bool selected) {
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
                          onTap: () {
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
              const SizedBox(height: 8),

              // Reminder
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                subtitle: const Text('Notify before task'),
                value: _isReminding,
                onChanged: (v) {
                  setState(() => _isReminding = v);
                },
              ),
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
