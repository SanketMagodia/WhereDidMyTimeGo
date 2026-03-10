import 'package:uuid/uuid.dart';

const List<String> kExpenseCategories = [
  'Food',
  'Travelling',
  'Clothes',
  'Gadgets',
  'Medical',
  'Other',
];

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final DateTime timestamp;
  final String category;
  final String? note;

  ExpenseModel({
    String? id,
    required this.title,
    required this.amount,
    required this.timestamp,
    required this.category,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'category': category,
    'note': note,
  };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String?,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    category: json['category'] as String? ?? 'Other',
    note: json['note'] as String?,
  );

  ExpenseModel copyWith({
    String? title,
    double? amount,
    DateTime? timestamp,
    String? category,
    String? note,
  }) => ExpenseModel(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    timestamp: timestamp ?? this.timestamp,
    category: category ?? this.category,
    note: note ?? this.note,
  );
}
