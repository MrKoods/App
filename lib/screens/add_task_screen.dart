import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  static const Color _backgroundColor = Color(0xFF090B10);
  static const Color _surfaceColor = Color(0xFF121826);
  static const Color _surfaceAltColor = Color(0xFF101522);
  static const Color _accentColor = Color(0xFF55E6C1);
  static const Color _secondaryAccent = Color(0xFFFFC857);

  // List of task input rows
  final List<TaskInput> _tasks = [];
  late DateTime _selectedDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Start with one empty task input
    _tasks.add(TaskInput());
  }

  Color _categoryColor(String category) {
    if (category == 'School') {
      return const Color(0xFF6EA8FE);
    }

    if (category == 'Health') {
      return const Color(0xFF5CF2B5);
    }

    if (category == 'Productivity') {
      return const Color(0xFFFF9F5A);
    }

    if (category == 'Personal') {
      return const Color(0xFFFF6FAE);
    }

    return Colors.white70;
  }

  /// Format date as "Monday, March 23, 2024"
  String _formatDate(DateTime date) {
    const List<String> dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const List<String> monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final String dayName = dayNames[date.weekday - 1];
    final String monthName = monthNames[date.month - 1];

    return '$dayName, $monthName ${date.day}, ${date.year}';
  }

  /// Save multiple tasks for the selected date
  Future<void> _saveTasks() async {
    // Get all non-empty task inputs
    final List<TaskInput> nonEmptyTasks =
        _tasks.where((t) => t.controller.text.trim().isNotEmpty).toList();

    if (nonEmptyTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one task'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _firestoreService.addMultipleTasks(
        taskInputs: nonEmptyTasks,
        selectedDate: _selectedDate,
      );

      await _firestoreService.addHistory(
        'Added ${nonEmptyTasks.length} task(s) for ${_formatDate(_selectedDate)}',
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save tasks'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Save multiple tasks as a preset
  Future<void> _saveAsPreset() async {
    // Get all non-empty task inputs
    final List<TaskInput> nonEmptyTasks =
        _tasks.where((t) => t.controller.text.trim().isNotEmpty).toList();

    if (nonEmptyTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one task'),
        ),
      );
      return;
    }

    // Show dialog to get preset name
    final String? presetName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final TextEditingController nameController = TextEditingController();

        return AlertDialog(
          backgroundColor: _surfaceColor,
          title: const Text(
            'Save as Preset',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Preset name',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _accentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (presetName == null || presetName.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _firestoreService.savePreset(
        name: presetName,
        taskInputs: nonEmptyTasks,
      );

      await _firestoreService.addHistory(
        'Created preset: $presetName',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset "$presetName" saved!'),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save preset'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Open date picker and update selected date
  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentColor,
              surface: _surfaceColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  /// Add a new empty task input row
  void _addTaskInput() {
    setState(() {
      _tasks.add(TaskInput());
    });
  }

  /// Remove a task input row
  void _removeTaskInput(int index) {
    setState(() {
      _tasks[index].controller.dispose();
      _tasks.removeAt(index);
    });
  }

  @override
  void dispose() {
    // Dispose all task controllers
    for (final task in _tasks) {
      task.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Add Tasks'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2335), Color(0xFF101522)],
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create tasks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add multiple tasks for the same day or save as a preset.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Bright goals, focused progress',
                      style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Date picker card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today, color: _secondaryAccent, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Select Date',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surfaceAltColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, color: _accentColor),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date for these tasks',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Task inputs card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: _secondaryAccent, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Task Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Task input rows
                  ..._tasks.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final TaskInput task = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          // Task name input
                          TextField(
                            controller: task.controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Task ${index + 1}',
                              prefixIcon: const Icon(Icons.task_alt, color: _accentColor),
                              suffixIcon: _tasks.length > 1
                                  ? IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white38),
                                      onPressed: () => _removeTaskInput(index),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Category dropdown
                          DropdownButtonFormField<String>(
                            initialValue: task.category,
                            dropdownColor: _surfaceAltColor,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.palette_outlined, color: _secondaryAccent),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'School',
                                child: Text('School', style: TextStyle(color: _categoryColor('School'))),
                              ),
                              DropdownMenuItem(
                                value: 'Health',
                                child: Text('Health', style: TextStyle(color: _categoryColor('Health'))),
                              ),
                              DropdownMenuItem(
                                value: 'Productivity',
                                child: Text('Productivity',
                                    style: TextStyle(color: _categoryColor('Productivity'))),
                              ),
                              DropdownMenuItem(
                                value: 'Personal',
                                child: Text('Personal', style: TextStyle(color: _categoryColor('Personal'))),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                task.category = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                    }),

                  // Add task button
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addTaskInput,
                      icon: const Icon(Icons.add, color: _accentColor),
                      label: const Text(
                        'Add Task',
                        style: TextStyle(color: _accentColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save buttons row
            Row(
              children: [
                // Save as preset button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _saveAsPreset,
                    icon: const Icon(Icons.bookmark_add, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _surfaceColor,
                      foregroundColor: _accentColor,
                      disabledBackgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: _accentColor),
                    ),
                    label: const Text('Save Preset'),
                  ),
                ),
                const SizedBox(width: 12),

                // Save task button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveTasks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryAccent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text('Save Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple class to hold task input data
class TaskInput {
  final TextEditingController controller = TextEditingController();
  String category = 'School';
}