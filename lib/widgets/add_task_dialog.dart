import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database.dart';
import '../models/priority.dart';

/// Dialog for adding or editing tasks
class AddTaskDialog extends StatefulWidget {
  final Function(TasksCompanion) onSave;
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
      setState(() => _dueDate = picked);
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
      final companion = TasksCompanion(
        title: drift.Value(_titleController.text.trim()),
        description: drift.Value(
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
        color: drift.Value(_selectedColor.toARGB32()),
        priority: drift.Value(_priority.label),
        dueDate: drift.Value(_dueDate),
        isRepeating: drift.Value(_isRepeating),
        repeatEndDate: _isRepeating && _repeatEndDate != null
            ? drift.Value(_repeatEndDate)
            : const drift.Value(null),
      );

      widget.onSave(companion);
      Navigator.pop(context);
    }
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat),
                  title: const Text('Repeat Until'),
                  subtitle: Text(
                    _repeatEndDate != null
                        ? '${_repeatEndDate!.day}/${_repeatEndDate!.month}/${_repeatEndDate!.year}'
                        : 'Not set',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
