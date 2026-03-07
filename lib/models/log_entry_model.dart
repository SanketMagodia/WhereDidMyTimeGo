class LogEntry {
  final String id;
  final DateTime timestamp;
  final String text;
  final bool isSleep;
  final String? category;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    this.isSleep = false,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'isSleep': isSleep,
    'category': category,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    text: json['text'],
    isSleep: json['isSleep'] ?? false,
    category: json['category'],
  );

  LogEntry copyWith({String? text, String? category}) => LogEntry(
    id: id,
    timestamp: timestamp,
    text: text ?? this.text,
    isSleep: isSleep,
    category: category ?? this.category,
  );
}
