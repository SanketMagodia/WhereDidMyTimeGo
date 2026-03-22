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
  // true when auto-generated from a FixedExpenseTemplate; excluded from projection
  final bool isFixed;

  ExpenseModel({
    String? id,
    required this.title,
    required this.amount,
    required this.timestamp,
    required this.category,
    this.note,
    this.isFixed = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'category': category,
    'note': note,
    'isFixed': isFixed,
  };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String?,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    category: json['category'] as String? ?? 'Other',
    note: json['note'] as String?,
    isFixed: json['isFixed'] as bool? ?? false,
  );

  ExpenseModel copyWith({
    String? title,
    double? amount,
    DateTime? timestamp,
    String? category,
    String? note,
    bool? isFixed,
  }) => ExpenseModel(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    timestamp: timestamp ?? this.timestamp,
    category: category ?? this.category,
    note: note ?? this.note,
    isFixed: isFixed ?? this.isFixed,
  );
}

// ─── Fixed (recurring) expense template ──────────────────────────────────────
// One entry is auto-generated from this template on the 1st of every month.
class FixedExpenseTemplate {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String? note;

  FixedExpenseTemplate({
    String? id,
    required this.title,
    required this.amount,
    required this.category,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'category': category,
    'note': note,
  };

  factory FixedExpenseTemplate.fromJson(Map<String, dynamic> json) =>
      FixedExpenseTemplate(
        id: json['id'] as String?,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String? ?? 'Other',
        note: json['note'] as String?,
      );

  FixedExpenseTemplate copyWith({
    String? title,
    double? amount,
    String? category,
    String? note,
  }) => FixedExpenseTemplate(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    note: note ?? this.note,
  );
}
