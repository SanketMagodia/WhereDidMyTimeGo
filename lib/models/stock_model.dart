class StockModel {
  final String id;
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice;
  final DateTime buyDate;
  final double latestPrice;
  final DateTime lastUpdated;

  StockModel({
    required this.id,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.buyDate,
    this.latestPrice = 0.0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  double get totalInvested => quantity * averagePrice;
  double get currentValue => quantity * latestPrice;
  double get returnPercent => totalInvested == 0
      ? 0
      : ((currentValue - totalInvested) / totalInvested) * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'name': name,
    'quantity': quantity,
    'averagePrice': averagePrice,
    'buyDate': buyDate.toIso8601String(),
    'latestPrice': latestPrice,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory StockModel.fromJson(Map<String, dynamic> json) => StockModel(
    id: json['id'] as String? ?? '',
    symbol: json['symbol'] as String? ?? '',
    name: json['name'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0.0,
    buyDate: json['buyDate'] != null
        ? DateTime.parse(json['buyDate'])
        : DateTime.now(),
    latestPrice: (json['latestPrice'] as num?)?.toDouble() ?? 0.0,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.parse(json['lastUpdated'])
        : DateTime.now(),
  );

  StockModel copyWith({
    String? id,
    String? symbol,
    String? name,
    double? quantity,
    double? averagePrice,
    DateTime? buyDate,
    double? latestPrice,
    DateTime? lastUpdated,
  }) {
    return StockModel(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
      buyDate: buyDate ?? this.buyDate,
      latestPrice: latestPrice ?? this.latestPrice,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
