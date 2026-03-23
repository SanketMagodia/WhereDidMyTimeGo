import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// Service for interacting with the MFapi.in mutual fund API.
class MfApiService {
  static const _base = 'https://api.mfapi.in';

  /// Search mutual fund schemes by name.
  /// Returns a list of {schemeCode, schemeName}.
  static Future<List<MfSearchResult>> search(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = Uri.parse('$_base/mf/search?q=${Uri.encodeComponent(query)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      if (data is! List) return [];
      return data
          .map(
            (e) => MfSearchResult(
              schemeCode: e['schemeCode'] as int,
              schemeName: e['schemeName'] as String,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('MF search error: $e');
      return [];
    }
  }

  /// Get latest NAV for a specific scheme.
  static Future<MfSchemeData?> getLatestNav(int schemeCode) async {
    try {
      final uri = Uri.parse('$_base/mf/$schemeCode/latest');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      return MfSchemeData.fromJson(data);
    } catch (e) {
      debugPrint('MF latest NAV error: $e');
      return null;
    }
  }

  /// Get NAV history for a specific scheme, optionally with date range.
  static Future<MfSchemeData?> getNavHistory(
    int schemeCode, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var url = '$_base/mf/$schemeCode';
      final params = <String>[];
      if (startDate != null) {
        params.add(
          'startDate=${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        );
      }
      if (endDate != null) {
        params.add(
          'endDate=${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        );
      }
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final uri = Uri.parse(url);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      return MfSchemeData.fromJson(data);
    } catch (e) {
      debugPrint('MF NAV history error: $e');
      return null;
    }
  }

  /// Find the closest NAV to a given date from a list of NAV entries.
  /// NAV data may not be available on weekends/holidays, so we find nearest.
  static NavEntry? findClosestNav(List<NavEntry> navs, DateTime target) {
    if (navs.isEmpty) return null;
    NavEntry? closest;
    int minDiff = 999999;
    for (final nav in navs) {
      final diff = (nav.date.difference(target).inDays).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = nav;
      }
      // If we found an exact match or we've passed and are getting further away
      if (diff == 0) break;
    }
    return closest;
  }
}

class MfSearchResult {
  final int schemeCode;
  final String schemeName;
  const MfSearchResult({required this.schemeCode, required this.schemeName});
}

class NavEntry {
  final DateTime date;
  final double nav;
  const NavEntry({required this.date, required this.nav});

  factory NavEntry.fromJson(Map<String, dynamic> json) {
    // Date format from API: "dd-MM-yyyy"
    final parts = (json['date'] as String).split('-');
    final date = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    return NavEntry(date: date, nav: double.parse(json['nav'] as String));
  }
}

class MfSchemeData {
  final String fundHouse;
  final String schemeName;
  final int schemeCode;
  final String schemeCategory;
  final List<NavEntry> navs;

  const MfSchemeData({
    required this.fundHouse,
    required this.schemeName,
    required this.schemeCode,
    required this.schemeCategory,
    required this.navs,
  });

  factory MfSchemeData.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final dataList = json['data'] as List? ?? [];

    return MfSchemeData(
      fundHouse: meta['fund_house'] as String? ?? '',
      schemeName: meta['scheme_name'] as String? ?? '',
      schemeCode: meta['scheme_code'] as int? ?? 0,
      schemeCategory: meta['scheme_category'] as String? ?? '',
      navs: dataList.map((e) => NavEntry.fromJson(e)).toList(),
    );
  }
}
