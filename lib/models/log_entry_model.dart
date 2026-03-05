class LogEntry {
  final String id;
  final DateTime timestamp;
  final String text;
  final bool isSleep;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.text,
    this.isSleep = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'text': text,
    'isSleep': isSleep,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    text: json['text'],
    isSleep: json['isSleep'] ?? false,
  );
}
