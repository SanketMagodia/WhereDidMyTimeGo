class TodoModel {
  final String id;
  final String text;
  final int colorIndex;
  final int orderIndex;
  final bool isDone;

  TodoModel({
    required this.id,
    required this.text,
    this.colorIndex = 0,
    required this.orderIndex,
    this.isDone = false,
  });

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      text: json['text'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      orderIndex: json['orderIndex'] as int? ?? 0,
      isDone: json['isDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'colorIndex': colorIndex,
      'orderIndex': orderIndex,
      'isDone': isDone,
    };
  }

  TodoModel copyWith({
    String? id,
    String? text,
    int? colorIndex,
    int? orderIndex,
    bool? isDone,
  }) {
    return TodoModel(
      id: id ?? this.id,
      text: text ?? this.text,
      colorIndex: colorIndex ?? this.colorIndex,
      orderIndex: orderIndex ?? this.orderIndex,
      isDone: isDone ?? this.isDone,
    );
  }
}
