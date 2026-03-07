import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/todo_folder_model.dart';
import '../models/todo_model.dart';
import '../theme/app_theme.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  // Pastel/Autumn note colors
  static const List<Color> _noteColors = [
    Color(0xFFE8D3B9), // Sand
    Color(0xFFF0A786), // Peach
    Color(0xFF8BA694), // Sage
    Color(0xFFD4A373), // Tan
    Color(0xFF7D9C9F), // Slate blue
    Color(0xFFC4892A), // Gold
    Color(0xFFBB7E67), // Rust
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final folders = provider.todoFolders;
    final c = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Notes & Todos',
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai_plan_fab',
            onPressed: provider.isAiReady
                ? () => _showAiPlanDialog(context, provider)
                : null,
            backgroundColor: provider.isAiReady
                ? Colors.deepPurpleAccent
                : Colors.grey,
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            label: const Text(
              "AI Plan",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_folder_fab',
            onPressed: () => _showNewFolderDialog(context, provider),
            backgroundColor: AppTheme.accentPrimary,
            icon: const Icon(
              Icons.create_new_folder_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              "Folder",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: folders.isEmpty
          ? Center(
              child: Text(
                'No folders yet. Tap + Folder to create one!',
                style: TextStyle(color: c.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return _buildFolderCard(context, folder, provider, isLight);
              },
            ),
    );
  }

  Widget _buildFolderCard(
    BuildContext context,
    TodoFolderModel folder,
    AppProvider provider,
    bool isLight,
  ) {
    final c = AppColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: c.surfaceMid,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          iconColor: c.text,
          collapsedIconColor: c.muted,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  folder.title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_task_rounded, size: 22),
                color: AppTheme.accentPrimary,
                onPressed: () =>
                    _showEditDialog(context, provider, folderId: folder.id),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: c.muted,
                ),
                onPressed: () => provider.removeTodoFolder(folder.id),
              ),
            ],
          ),
          children: [
            if (folder.todos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Empty folder. Add some tasks!",
                  style: TextStyle(color: c.muted, fontStyle: FontStyle.italic),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: folder.todos.length,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderTodos(folder.id, oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 6,
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final todo = folder.todos[index];
                  return Padding(
                    key: ValueKey(todo.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NoteCard(
                      todo: todo,
                      color: _noteColors[todo.colorIndex % _noteColors.length],
                      isLight: isLight,
                      onTap: () => _copyToClipboard(context, todo.text),
                      onEdit: () => _showEditDialog(
                        context,
                        provider,
                        folderId: folder.id,
                        todo: todo,
                      ),
                      onDelete: () => provider.removeTodo(folder.id, todo.id),
                      onToggle: (val) =>
                          provider.toggleTodo(folder.id, todo.id),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAiPlanDialog(BuildContext context, AppProvider provider) {
    if (!provider.isAiReady) return;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        bool isGenerating = false;

        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Dialog(
              backgroundColor: c.surfaceMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.deepPurpleAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generate AI Plan',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      autofocus: true,
                      enabled: !isGenerating,
                      style: TextStyle(color: c.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'What do you want to plan for? (e.g., "Learn Economics", "Trip to Paris")',
                        hintStyle: TextStyle(color: c.muted),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isGenerating)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: c.muted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final text = textController.text.trim();
                              if (text.isNotEmpty) {
                                setStateBuilder(() => isGenerating = true);
                                await provider.generateAiTodoFolder(text);
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Generate'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNewFolderDialog(BuildContext context, AppProvider provider) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return Dialog(
          backgroundColor: c.surfaceMid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'New Folder',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: c.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Folder Name...',
                    hintStyle: TextStyle(color: c.muted),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(color: c.muted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final text = textController.text.trim();
                        if (text.isNotEmpty) {
                          provider.addTodoFolder(text);
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Note copied to clipboard',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: AppTheme.accentPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    AppProvider provider, {
    required String folderId,
    TodoModel? todo,
  }) {
    final textController = TextEditingController(text: todo?.text ?? '');
    int selectedColor = todo?.colorIndex ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Dialog(
              backgroundColor: c.surfaceMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      todo == null ? 'New Note' : 'Edit Note',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      minLines: 3,
                      autofocus: todo == null,
                      style: TextStyle(color: c.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type something...',
                        hintStyle: TextStyle(color: c.muted),
                        filled: true,
                        fillColor: c.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _noteColors.length,
                        separatorBuilder: (context, i) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final color = _noteColors[i];
                          final isSelected = selectedColor == i;
                          return GestureDetector(
                            onTap: () =>
                                setStateBuilder(() => selectedColor = i),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: c.text, width: 2)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: c.muted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isNotEmpty) {
                              if (todo == null) {
                                provider.addTodoToFolder(
                                  folderId,
                                  text,
                                  selectedColor,
                                );
                              } else {
                                provider.updateTodoText(
                                  folderId,
                                  todo.id,
                                  text,
                                );
                                provider.updateTodoColor(
                                  folderId,
                                  todo.id,
                                  selectedColor,
                                );
                              }
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(todo == null ? 'Add' : 'Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final TodoModel todo;
  final Color color;
  final bool isLight;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool?> onToggle;

  const _NoteCard({
    super.key,
    required this.todo,
    required this.color,
    required this.isLight,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const noteTextColor = Colors.black87;

    return Material(
      color: color.withAlpha(todo.isDone ? 150 : 255),
      borderRadius: BorderRadius.circular(12),
      elevation: todo.isDone ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: todo.isDone,
                onChanged: onToggle,
                activeColor: Colors.black54,
                checkColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Colors.black54, width: 1.5),
              ),
              Expanded(
                child: Text(
                  todo.text,
                  style: TextStyle(
                    color: todo.isDone ? Colors.black38 : noteTextColor,
                    fontSize: 15,
                    height: 1.4,
                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.drag_indicator_rounded, color: Colors.black38),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
