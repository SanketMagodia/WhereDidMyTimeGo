class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
  );
}
