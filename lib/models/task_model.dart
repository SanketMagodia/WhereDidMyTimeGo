class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  // Native calendar event ID returned by device_calendar after syncing.
  final String? calendarEventId;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.calendarEventId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'calendarEventId': calendarEventId,
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    calendarEventId: json['calendarEventId'] as String?,
  );

  TaskModel copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? calendarEventId,
  }) => TaskModel(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    calendarEventId: calendarEventId ?? this.calendarEventId,
  );
}
