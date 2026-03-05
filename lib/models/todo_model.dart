class TodoModel {
  final String id;
  final String text;
  final int colorIndex;
  final int orderIndex;

  TodoModel({
    required this.id,
    required this.text,
    this.colorIndex = 0,
    required this.orderIndex,
  });

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    return TodoModel(
      id: json['id'] as String,
      text: json['text'] as String,
      colorIndex: json['colorIndex'] as int? ?? 0,
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'colorIndex': colorIndex,
      'orderIndex': orderIndex,
    };
  }

  TodoModel copyWith({
    String? id,
    String? text,
    int? colorIndex,
    int? orderIndex,
  }) {
    return TodoModel(
      id: id ?? this.id,
      text: text ?? this.text,
      colorIndex: colorIndex ?? this.colorIndex,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
