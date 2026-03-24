class JournalEntryModel {
  final String id;
  final DateTime date;
  final String content;
  final DateTime updatedAt;

  JournalEntryModel({
    required this.id,
    required this.date,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': DateTime(date.year, date.month, date.day).toIso8601String(),
    'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) =>
      JournalEntryModel(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        content: (json['content'] as String?) ?? '',
        updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );

  JournalEntryModel copyWith({
    String? content,
    DateTime? updatedAt,
  }) => JournalEntryModel(
    id: id,
    date: date,
    content: content ?? this.content,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
