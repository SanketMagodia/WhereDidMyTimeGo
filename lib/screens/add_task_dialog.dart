import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        widget.existingTask == null ? 'Add Task' : 'Edit Task',
        style: TextStyle(color: c.text),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: widget.existingTask == null,
            decoration: const InputDecoration(
              labelText: 'Task Name',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accentPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_showDescription)
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.accentPrimary),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () {
                setState(() => _showDescription = true);
              },
              icon: const Icon(Icons.add, color: AppTheme.accentPrimary),
              label: const Text(
                'Add description',
                style: TextStyle(color: AppTheme.accentPrimary),
              ),
            ),
        ],
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
          ),
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final task = TaskModel(
                id:
                    widget.existingTask?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                title: _titleController.text,
                description: _showDescription ? _descController.text : null,
                startTime:
                    widget.existingTask?.startTime ?? widget.initialStartTime,
                endTime: widget.existingTask?.endTime ?? widget.initialEndTime,
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
