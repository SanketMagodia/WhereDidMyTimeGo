import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class StockSearchResult {
  final String symbol;
  final String shortName;
  final String exchange;

  StockSearchResult({
    required this.symbol,
    required this.shortName,
    required this.exchange,
  });
}

class YahooFinanceService {
  /// Search for stocks
  static Future<List<StockSearchResult>> search(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search?q=${Uri.encodeComponent(query)}&quotesCount=10&newsCount=0',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      final quotes = data['quotes'] as List?;
      if (quotes == null) return [];

      return quotes
          .where((e) => e['quoteType'] == 'EQUITY' || e['quoteType'] == 'ETF')
          .map(
            (e) => StockSearchResult(
              symbol: e['symbol'] as String? ?? '',
              shortName:
                  e['shortname'] as String? ?? e['longname'] as String? ?? '',
              exchange: e['exchange'] as String? ?? '',
            ),
          )
          .where((s) => s.symbol.isNotEmpty && s.shortName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Yahoo search error: $e');
      return [];
    }
  }

  /// Get the latest price and historical data (1Y)
  /// Returns a map with 'latest' (double) and 'history' (Map<DateTime, double>)
  static Future<Map<String, dynamic>?> getChart(
    String symbol, {
    String range = '1y',
  }) async {
    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=$range&interval=1d',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body);
      final result = data['chart']?['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final meta = result[0]['meta'];
      final latestPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;

      final timestamps = result[0]['timestamp'] as List<dynamic>? ?? [];
      final indicators = result[0]['indicators']?['quote'] as List?;
      final closes = indicators != null && indicators.isNotEmpty
          ? (indicators[0]['close'] as List<dynamic>?)
          : null;

      Map<DateTime, double> history = {};
      if (closes != null && timestamps.length == closes.length) {
        for (int i = 0; i < timestamps.length; i++) {
          final ms = (timestamps[i] as num).toInt() * 1000;
          final dt = DateTime.fromMillisecondsSinceEpoch(ms);
          final close = (closes[i] as num?)?.toDouble();
          if (close != null) {
            final normalizedDate = DateTime(dt.year, dt.month, dt.day);
            history[normalizedDate] = close;
          }
        }
      }

      return {'latest': latestPrice, 'history': history};
    } catch (e) {
      debugPrint('Yahoo chart error: $e');
      return null;
    }
  }
}
