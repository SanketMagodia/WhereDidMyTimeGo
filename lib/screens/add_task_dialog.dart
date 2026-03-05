import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';

class AddTaskDialog extends StatefulWidget {
  final DateTime initialStartTime;
  final DateTime initialEndTime;
  final TaskModel? existingTask; // If we're editing

  const AddTaskDialog({
    super.key,
    required this.initialStartTime,
    required this.initialEndTime,
    this.existingTask,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _showDescription = false;

  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStartTime;
    _end = widget.initialEndTime;

    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
      _start = widget.existingTask!.startTime;
      _end = widget.existingTask!.endTime;
      if (widget.existingTask!.description != null &&
          widget.existingTask!.description!.isNotEmpty) {
        _descController.text = widget.existingTask!.description!;
        _showDescription = true;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              onPrimary: Colors.black,
              surface: AppColors.of(context).surface,
              onSurface: AppColors.of(context).text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _start.hour,
          _start.minute,
        );
        _end = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _end.hour,
          _end.minute,
        );
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              onPrimary: Colors.black,
              surface: AppColors.of(context).surface,
              onSurface: AppColors.of(context).text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final dur = _end.difference(_start);
        _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          picked.hour,
          picked.minute,
        );
        // keep duration if start moves
        _end = _start.add(dur);
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.accentPrimary,
              onPrimary: Colors.black,
              surface: AppColors.of(context).surface,
              onSurface: AppColors.of(context).text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final candidate = DateTime(
        _end.year,
        _end.month,
        _end.day,
        picked.hour,
        picked.minute,
      );
      if (candidate.isAfter(_start)) {
        setState(() => _end = candidate);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dateStr = DateFormat('EEE, d MMM').format(_start);
    final startStr = DateFormat('HH:mm').format(_start);
    final endStr = DateFormat('HH:mm').format(_end);

    return AlertDialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(
        widget.existingTask == null ? 'Add Task' : 'Edit Task',
        style: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: widget.existingTask == null,
                style: TextStyle(color: c.text),
                decoration: InputDecoration(
                  labelText: 'Task Name',
                  labelStyle: TextStyle(color: c.muted),
                  filled: true,
                  fillColor: c.surfaceMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.accentPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Date/Time Pickers ─────────────────────────────────────
              Text(
                'SCHEDULE',
                style: TextStyle(
                  color: c.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceMid,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildPickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateStr,
                      onTap: _pickDate,
                    ),
                    Divider(color: c.sep, height: 1, indent: 40),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerTile(
                            icon: Icons.access_time_rounded,
                            label: 'Start',
                            value: startStr,
                            onTap: _pickStartTime,
                          ),
                        ),
                        Container(width: 1, height: 30, color: c.sep),
                        Expanded(
                          child: _buildPickerTile(
                            icon: Icons.keyboard_tab_rounded,
                            label: 'End',
                            value: endStr,
                            onTap: _pickEndTime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (_showDescription)
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: c.muted),
                    filled: true,
                    fillColor: c.surfaceMid,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.accentPrimary,
                      ),
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showDescription = true);
                  },
                  icon: const Icon(
                    Icons.add,
                    color: AppTheme.accentPrimary,
                    size: 18,
                  ),
                  label: const Text(
                    'Add description',
                    style: TextStyle(
                      color: AppTheme.accentPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existingTask != null)
          TextButton(
            onPressed: () {
              Provider.of<AppProvider>(
                context,
                listen: false,
              ).removeTask(widget.existingTask!.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final task = TaskModel(
                id:
                    widget.existingTask?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                title: _titleController.text,
                description: _showDescription ? _descController.text : null,
                startTime: _start,
                endTime: _end,
              );

              final provider = Provider.of<AppProvider>(context, listen: false);
              if (widget.existingTask == null) {
                provider.addTask(task);
              } else {
                provider.updateTask(task);
              }
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentPrimary, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.muted, fontSize: 9)),
                Text(
                  value,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
