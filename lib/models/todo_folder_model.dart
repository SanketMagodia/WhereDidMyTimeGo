import 'todo_model.dart';
import 'package:uuid/uuid.dart';

class TodoFolderModel {
  final String id;
  final String title;
  final List<TodoModel> todos;

  TodoFolderModel({String? id, required this.title, List<TodoModel>? todos})
    : id = id ?? const Uuid().v4(),
      todos = todos ?? [];

  factory TodoFolderModel.fromJson(Map<String, dynamic> json) {
    return TodoFolderModel(
      id: json['id'] as String?,
      title: json['title'] as String,
      todos:
          (json['todos'] as List?)
              ?.map((e) => TodoModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'todos': todos.map((e) => e.toJson()).toList(),
    };
  }

  TodoFolderModel copyWith({
    String? id,
    String? title,
    List<TodoModel>? todos,
  }) {
    return TodoFolderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      todos: todos ?? this.todos,
    );
  }
}
