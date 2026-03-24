class DailyChecklistItemModel {
  final String id;
  final String title;
  final int orderIndex;

  const DailyChecklistItemModel({
    required this.id,
    required this.title,
    required this.orderIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'orderIndex': orderIndex,
  };

  factory DailyChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return DailyChecklistItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }

  DailyChecklistItemModel copyWith({
    String? id,
    String? title,
    int? orderIndex,
  }) {
    return DailyChecklistItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
