import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:time_management_mobile_app/screens/today_tasks_screen.dart';
import 'package:time_management_mobile_app/widgets/notification_service.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';

enum RepeatType { daily, weekly, monthly }

/// Dialog for adding or editing events
class AddEventDialog extends StatefulWidget {
  final Function(List<EventsCompanion>) onSave;
  final Event? existingEvent;
  final DateTime? initialDate;

  const AddEventDialog({
    super.key,
    required this.onSave,
    this.existingEvent,
    this.initialDate,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  int? _selectedCategoryId;
  late Color _selectedColor;
  late DateTime _dueDate;
  final now = DateTime.now();
  late DateTime _startTime = DateTime(now.year, now.month, now.day);
  late DateTime _endTime   = DateTime(now.year, now.month, now.day);
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
    final e = widget.existingEvent;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _selectedCategoryId = e?.categoryId;
    _selectedColor = e != null ? Color(e.color) : const Color(0xFF2196F3);
    _dueDate = e?.dueDate ?? widget.initialDate ?? DateTime.now();
    _startTime = e?.startTime ?? DateTime.now();
    _endTime = e?.endTime ?? DateTime.now();
    _isRepeating = e?.isRepeating ?? false;
    _repeatEndDate = e?.repeatEndDate;
    // Default repetition values
    if (_endTime.weekday != 0) _selectedWeekDays.add(_endTime.weekday);
    if (_endTime.day != 0) _selectedMonthDays.add(_endTime.day);
    _isReminding = e?.isReminding ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked == null) return;

    final newStart = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      picked.hour,
      picked.minute,
    );

    // Check if end is before start
    if (_endTime.isBefore(newStart)) {
      // Optionally, auto-adjust end to be same as start
      setState(() {
        _startTime = newStart;
        _endTime = newStart.add(const Duration(minutes: 30)); // default 30min duration
      });
    } else {
      setState(() {
        _startTime = newStart;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    if (picked == null) return;

    final newEnd = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      picked.hour,
      picked.minute,
    );

    if (newEnd.isBefore(_startTime)) {
      // Show prompt dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Invalid End Time"),
          content: const Text("End time cannot be earlier than start time."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return; // do not update endTime
    }

    setState(() {
      _endTime = newEnd;
    });
  }

  Future<void> _selectRepeatEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatEndDate ?? _endTime.add(const Duration(days: 7)),
      firstDate: _dueDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _repeatEndDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
        const SnackBar(content: Text('Please select at least one day of the week')),
      );
      return;
    }

    if (_isRepeating &&
        _repeatType == RepeatType.monthly &&
        _selectedMonthDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day of the month')),
      );
      return;
    }

    final List<EventsCompanion> eventsToSave = [];
    final String? repeatId = _isRepeating ? const Uuid().v4() : null;

    final duration =
        _endTime.difference(_startTime).inMinutes.clamp(1, 1440);

    if (!_isRepeating) {
      eventsToSave.add(_createEventCompanion(_dueDate, _startTime, repeatId, duration));
    } else {
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

      int count = 0;
      const maxLimit = 365 * 2;

      while (currentDate.isBefore(end.add(const Duration(days: 1))) &&
          count < maxLimit) {
        bool shouldAdd = false;

        if (_repeatType == RepeatType.daily) {
          shouldAdd = true;
        } else if (_repeatType == RepeatType.weekly) {
          shouldAdd = _selectedWeekDays.contains(currentDate.weekday);
        } else if (_repeatType == RepeatType.monthly) {
          shouldAdd = _selectedMonthDays.contains(currentDate.day);
        }

        if (shouldAdd) {
          final eventDate = DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            _dueDate.hour,
            _dueDate.minute,
          );

          eventsToSave.add(
            _createEventCompanion(eventDate, _startTime, repeatId, duration),
          );
        }

        currentDate = currentDate.add(const Duration(days: 1));
        count++;
      }
    }

    widget.onSave(eventsToSave);

    if (_isReminding) {
      for (final event in eventsToSave) {
        final String eventTitle = event.title.value; // unwrap Value<String>
        final DateTime eventStart = event.startTime.value; // unwrap Value<DateTime>

        print('Scheduling reminder for event: $eventTitle at $eventStart');

        await NotificationService.instance.scheduleReminder(
          title: eventTitle,
          body: 'Event reminder',
          scheduledAt: eventStart,
        );
      }
    }
    Navigator.pop(context);
  }

  EventsCompanion _createEventCompanion(DateTime date, DateTime start, String? repeatId, int duration) {
    return EventsCompanion(
      title: drift.Value(_titleController.text.trim()),
      description: drift.Value(
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
      categoryId: drift.Value(_selectedCategoryId),
      color: drift.Value(_selectedColor.toARGB32()),
      dueDate: drift.Value(date),
      startTime: drift.Value(start),
      endTime: drift.Value(start.add(Duration(minutes: duration))),
      durationMinutes: drift.Value(duration),
      isRepeating: drift.Value(_isRepeating),
      repeatEndDate: _isRepeating
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
                    widget.existingEvent != null ? 'Edit Event' : 'New Event',style: const TextStyle(
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
                  labelText: 'Event Title',
                  hintText: 'What is happening?',
                  prefixIcon: Icon(Icons.event),
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

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // DATE BOX
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Date", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_dueDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // START TIME BOX
                  InkWell(
                    onTap: _pickStartTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Start Time", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(DateFormat('HH:mm').format(_startTime), style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // END TIME BOX
                  InkWell(
                    onTap: _pickEndTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("End Time", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(DateFormat('HH:mm').format(_endTime), style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(),

              // Repeat toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat Event'),
                subtitle: const Text('Create recurring events'),
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
                subtitle: const Text('Notify before event'),
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
                    widget.existingEvent != null ? 'Save Changes' : 'Add Event',
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
