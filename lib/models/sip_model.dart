import 'package:uuid/uuid.dart';

enum SipStatus { active, paused, stopped }

class SipModel {
  final String id;
  final int schemeCode;
  final String schemeName;
  final String fundHouse;
  final double monthlyAmount;
  final int sipDay; // day of month SIP is deducted (1–28)
  final DateTime startDate; // when the SIP was started
  final SipStatus status;

  // Snapshot data calculated from NAV history
  final double totalInvested;
  final double currentValue;
  final double latestNav;
  final double totalUnits;
  final DateTime? lastUpdated;

  // installment history: list of {date, nav, units, amount}
  final List<SipInstallment> installments;

  SipModel({
    String? id,
    required this.schemeCode,
    required this.schemeName,
    this.fundHouse = '',
    required this.monthlyAmount,
    required this.sipDay,
    required this.startDate,
    this.status = SipStatus.active,
    this.totalInvested = 0,
    this.currentValue = 0,
    this.latestNav = 0,
    this.totalUnits = 0,
    this.lastUpdated,
    this.installments = const [],
  }) : id = id ?? const Uuid().v4();

  double get returnAmount => currentValue - totalInvested;
  double get returnPercent =>
      totalInvested > 0 ? (returnAmount / totalInvested) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'schemeCode': schemeCode,
    'schemeName': schemeName,
    'fundHouse': fundHouse,
    'monthlyAmount': monthlyAmount,
    'sipDay': sipDay,
    'startDate': startDate.toIso8601String(),
    'status': status.name,
    'totalInvested': totalInvested,
    'currentValue': currentValue,
    'latestNav': latestNav,
    'totalUnits': totalUnits,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'installments': installments.map((i) => i.toJson()).toList(),
  };

  factory SipModel.fromJson(Map<String, dynamic> json) => SipModel(
    id: json['id'] as String?,
    schemeCode: json['schemeCode'] as int,
    schemeName: json['schemeName'] as String,
    fundHouse: json['fundHouse'] as String? ?? '',
    monthlyAmount: (json['monthlyAmount'] as num).toDouble(),
    sipDay: json['sipDay'] as int? ?? 1,
    startDate: DateTime.parse(json['startDate'] as String),
    status: SipStatus.values.firstWhere(
      (s) => s.name == (json['status'] as String? ?? 'active'),
      orElse: () => SipStatus.active,
    ),
    totalInvested: (json['totalInvested'] as num?)?.toDouble() ?? 0,
    currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
    latestNav: (json['latestNav'] as num?)?.toDouble() ?? 0,
    totalUnits: (json['totalUnits'] as num?)?.toDouble() ?? 0,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.tryParse(json['lastUpdated'] as String)
        : null,
    installments: json['installments'] != null
        ? (json['installments'] as List)
              .map((e) => SipInstallment.fromJson(e))
              .toList()
        : [],
  );

  SipModel copyWith({
    String? schemeName,
    String? fundHouse,
    double? monthlyAmount,
    int? sipDay,
    DateTime? startDate,
    SipStatus? status,
    double? totalInvested,
    double? currentValue,
    double? latestNav,
    double? totalUnits,
    DateTime? lastUpdated,
    List<SipInstallment>? installments,
  }) => SipModel(
    id: id,
    schemeCode: schemeCode,
    schemeName: schemeName ?? this.schemeName,
    fundHouse: fundHouse ?? this.fundHouse,
    monthlyAmount: monthlyAmount ?? this.monthlyAmount,
    sipDay: sipDay ?? this.sipDay,
    startDate: startDate ?? this.startDate,
    status: status ?? this.status,
    totalInvested: totalInvested ?? this.totalInvested,
    currentValue: currentValue ?? this.currentValue,
    latestNav: latestNav ?? this.latestNav,
    totalUnits: totalUnits ?? this.totalUnits,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    installments: installments ?? this.installments,
  );
}

class SipInstallment {
  final DateTime date;
  final double nav;
  final double units;
  final double amount;

  const SipInstallment({
    required this.date,
    required this.nav,
    required this.units,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'nav': nav,
    'units': units,
    'amount': amount,
  };

  factory SipInstallment.fromJson(Map<String, dynamic> json) => SipInstallment(
    date: DateTime.parse(json['date'] as String),
    nav: (json['nav'] as num).toDouble(),
    units: (json['units'] as num).toDouble(),
    amount: (json['amount'] as num).toDouble(),
  );
}
