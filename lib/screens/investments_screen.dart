import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/sip_model.dart';
import '../models/stock_model.dart';
import '../services/mf_api_service.dart';
import '../services/yahoo_finance_service.dart';
import '../theme/app_theme.dart';
import 'mf_tools_screen.dart';

final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

final _dateFmt = DateFormat('d MMM yyyy');
final _shortDate = DateFormat('MMM yy');

// ─── Main Screen ──────────────────────────────────────────────────────────────
class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});
  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  bool _refreshing = false;

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    for (final sip in provider.sips) {
      final data = await MfApiService.getLatestNav(sip.schemeCode);
      if (data != null && data.navs.isNotEmpty) {
        final latestNav = data.navs.first.nav;
        final currentValue = sip.totalUnits * latestNav;
        await provider.updateSip(
          sip.copyWith(
            latestNav: latestNav,
            currentValue: currentValue,
            lastUpdated: DateTime.now(),
            fundHouse: data.fundHouse.isNotEmpty ? data.fundHouse : null,
          ),
        );
      }
    }
    for (final stock in provider.stocks) {
      final res = await YahooFinanceService.getChart(stock.symbol);
      if (res != null) {
        final latestPrice = res['latest'] as double;
        await provider.updateStock(
          stock.copyWith(latestPrice: latestPrice, lastUpdated: DateTime.now()),
        );
      }
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _showAddOptions(BuildContext context) {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Investment',
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.show_chart_rounded),
              label: const Text('Add Mutual Fund SIP'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openAddSip(context);
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.candlestick_chart_rounded),
              label: const Text('Add Stock (One Time Buy)'),
              style: FilledButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _openAddStock(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_asset_fab',
        onPressed: () => _showAddOptions(context),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 5,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final sips = provider.sips;
            final stocks = provider.stocks;
            final hasAssets = sips.isNotEmpty || stocks.isNotEmpty;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(c, sips, stocks)),
                if (!hasAssets)
                  SliverFillRemaining(child: _buildEmpty(c))
                else ...[
                  SliverToBoxAdapter(child: _buildAnalytics(c, sips, stocks)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        if (i < sips.length) {
                          return _SipCard(sip: sips[i], onRefresh: _refreshAll);
                        } else {
                          return _StockCard(
                            stock: stocks[i - sips.length],
                            onRefresh: _refreshAll,
                          );
                        }
                      }, childCount: sips.length + stocks.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppColors c,
    List<SipModel> sips,
    List<StockModel> stocks,
  ) {
    final sipsInvested = sips.fold<double>(0, (s, e) => s + e.totalInvested);
    final stocksInvested = stocks.fold<double>(
      0,
      (s, e) => s + e.totalInvested,
    );
    final totalInvested = sipsInvested + stocksInvested;

    final sipsValue = sips.fold<double>(0, (s, e) => s + e.currentValue);
    final stocksValue = stocks.fold<double>(0, (s, e) => s + e.currentValue);
    final currentValue = sipsValue + stocksValue;

    final returnAmt = currentValue - totalInvested;
    final returnPct = totalInvested > 0
        ? (returnAmt / totalInvested) * 100
        : 0.0;
    final isPositive = returnAmt >= 0;
    final activeSips = sips.where((s) => s.status == SipStatus.active).length;
    final monthlySip = sips
        .where((s) => s.status == SipStatus.active)
        .fold<double>(0, (s, e) => s + e.monthlyAmount);

    return Column(
      children: [
        // Back + title
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.text),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                'Investments',
                style: TextStyle(
                  color: c.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              // Explorer & Tools button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MfToolsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.blue.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_rounded, color: c.blue, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Tools',
                        style: TextStyle(
                          color: c.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (sips.isNotEmpty)
                _refreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.muted,
                        ),
                      )
                    : GestureDetector(
                        onTap: _refreshAll,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: c.surfaceMid,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: c.muted,
                            size: 18,
                          ),
                        ),
                      ),
            ],
          ),
        ),
        // Summary card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withAlpha(100),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'PORTFOLIO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (activeSips > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$activeSips active SIP${activeSips > 1 ? "s" : ""}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _currency.format(currentValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Current value',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _summaryPill(
                    'Invested',
                    _currency.format(totalInvested),
                    Colors.white70,
                  ),
                  const SizedBox(width: 10),
                  _summaryPill(
                    'Returns',
                    '${isPositive ? "+" : ""}${_currency.format(returnAmt)}',
                    isPositive
                        ? const Color(0xFF81C784)
                        : const Color(0xFFEF5350),
                  ),
                  const SizedBox(width: 10),
                  _summaryPill(
                    'Return %',
                    '${isPositive ? "+" : ""}${returnPct.toStringAsFixed(1)}%',
                    isPositive
                        ? const Color(0xFF81C784)
                        : const Color(0xFFEF5350),
                  ),
                ],
              ),
              // ── Interactive Stock-Style Portfolio Chart ──────────────────
              if ((sips.isNotEmpty || stocks.isNotEmpty) &&
                  totalInvested > 0) ...[
                const SizedBox(height: 16),
                _PortfolioTrendChart(sips: sips, stocks: stocks),
              ],
              if (monthlySip > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      size: 13,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly SIP: ${_currency.format(monthlySip)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryPill(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics(
    AppColors c,
    List<SipModel> sips,
    List<StockModel> stocks,
  ) {
    final sipsInvested = sips.fold<double>(0, (s, e) => s + e.totalInvested);
    final stocksInvested = stocks.fold<double>(
      0,
      (s, e) => s + e.totalInvested,
    );
    final totalInvested = sipsInvested + stocksInvested;
    if (totalInvested == 0) return const SizedBox.shrink();

    double equityTotal = stocksInvested; // Stocks are equity
    double debtTotal = 0;
    double arbitrageTotal = 0;
    double otherTotal = 0;

    for (final sip in sips) {
      final nameLower = sip.schemeName.toLowerCase();
      if (nameLower.contains('arbitrage')) {
        arbitrageTotal += sip.totalInvested;
      } else if (nameLower.contains('debt') ||
          nameLower.contains('liquid') ||
          nameLower.contains('bond') ||
          nameLower.contains('gilt')) {
        debtTotal += sip.totalInvested;
      } else if (nameLower.contains('equity') ||
          nameLower.contains('midcap') ||
          nameLower.contains('smallcap') ||
          nameLower.contains('flexi') ||
          nameLower.contains('large') ||
          nameLower.contains('index') ||
          nameLower.contains('growth')) {
        equityTotal += sip.totalInvested;
      } else {
        otherTotal += sip.totalInvested;
      }
    }

    final pieces = <Map<String, dynamic>>[];
    if (equityTotal > 0)
      pieces.add({
        'label': 'Equity',
        'val': equityTotal,
        'color': const Color(0xFF4CAF50),
      });
    if (debtTotal > 0)
      pieces.add({
        'label': 'Debt',
        'val': debtTotal,
        'color': const Color(0xFF2196F3),
      });
    if (arbitrageTotal > 0)
      pieces.add({
        'label': 'Arbitrage',
        'val': arbitrageTotal,
        'color': const Color(0xFFFF9800),
      });
    if (otherTotal > 0)
      pieces.add({
        'label': 'Other',
        'val': otherTotal,
        'color': const Color(0xFF9C27B0),
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.sep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASSET CLASS ALLOCATION',
              style: TextStyle(
                color: c.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            // Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: pieces.map((p) {
                    final frac = (p['val'] as double) / totalInvested;
                    return Flexible(
                      flex: (frac * 1000).round().clamp(1, 1000),
                      child: Container(color: p['color'] as Color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: pieces.map((p) {
                final pct = ((p['val'] as double) / totalInvested * 100)
                    .round();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p['color'] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${p['label']} $pct%',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, color: c.muted, size: 48),
          const SizedBox(height: 12),
          Text(
            'No investments yet',
            style: TextStyle(
              color: c.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add a SIP',
            style: TextStyle(color: c.muted.withAlpha(150), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openAddSip(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AddSipScreen()),
    );
  }

  void _openAddStock(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AddStockScreen()),
    );
  }
}

// ─── Stock Card ─────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockModel stock;
  final VoidCallback onRefresh;
  const _StockCard({required this.stock, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isPositive = stock.currentValue >= stock.totalInvested;
    final returnAmt = stock.currentValue - stock.totalInvested;

    return GestureDetector(
      onTap: () => _openStockDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.sep),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    color: c.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.symbol,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock.name,
                        style: TextStyle(color: c.muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currency.format(stock.currentValue),
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: isPositive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFEF5350),
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${isPositive ? "+" : ""}${_currency.format(returnAmt)}',
                          style: TextStyle(
                            color: isPositive
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFEF5350),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openStockDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StockDetailSheet(stock: stock),
    );
  }
}

// ─── SIP Card ─────────────────────────────────────────────────────────────────
class _SipCard extends StatelessWidget {
  final SipModel sip;
  final VoidCallback onRefresh;
  const _SipCard({required this.sip, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isPositive = sip.returnAmount >= 0;
    final statusColor = sip.status == SipStatus.active
        ? const Color(0xFF4CAF50)
        : sip.status == SipStatus.paused
        ? const Color(0xFFFFA726)
        : const Color(0xFFEF5350);
    final statusLabel =
        sip.status.name[0].toUpperCase() + sip.status.name.substring(1);

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.sep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sip.schemeName,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (sip.fundHouse.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sip.fundHouse,
                style: TextStyle(color: c.muted, fontSize: 9),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _infoCol(c, 'Invested', _currency.format(sip.totalInvested)),
                _infoCol(c, 'Current', _currency.format(sip.currentValue)),
                _infoCol(
                  c,
                  'Returns',
                  '${isPositive ? "+" : ""}${sip.returnPercent.toStringAsFixed(1)}%',
                  valueColor: isPositive
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEF5350),
                ),
                _infoCol(c, 'Monthly', _currency.format(sip.monthlyAmount)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 10, color: c.muted),
                const SizedBox(width: 4),
                Text(
                  'SIP on ${sip.sipDay}${_daySuffix(sip.sipDay)} · Since ${_shortDate.format(sip.startDate)}',
                  style: TextStyle(color: c.muted, fontSize: 9),
                ),
                const Spacer(),
                if (sip.latestNav > 0)
                  Text(
                    'NAV: ${sip.latestNav.toStringAsFixed(2)}',
                    style: TextStyle(color: c.muted, fontSize: 9),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCol(
    AppColors c,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.muted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? c.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SipDetailSheet(sip: sip),
    );
  }
}

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

// ─── SIP Detail Sheet ─────────────────────────────────────────────────────────
class _SipDetailSheet extends StatelessWidget {
  final SipModel sip;
  const _SipDetailSheet({required this.sip});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isPositive = sip.returnAmount >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.muted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      sip.schemeName,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (sip.fundHouse.isNotEmpty)
                      Text(
                        sip.fundHouse,
                        style: TextStyle(color: c.muted, fontSize: 11),
                      ),
                    const SizedBox(height: 16),
                    // Summary row
                    _detailRow(
                      c,
                      'Total Invested',
                      _currency.format(sip.totalInvested),
                    ),
                    _detailRow(
                      c,
                      'Current Value',
                      _currency.format(sip.currentValue),
                    ),
                    _detailRow(
                      c,
                      'Returns',
                      '${isPositive ? "+" : ""}${_currency.format(sip.returnAmount)}',
                      valueColor: isPositive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                    ),
                    _detailRow(
                      c,
                      'Return %',
                      '${sip.returnPercent.toStringAsFixed(2)}%',
                      valueColor: isPositive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350),
                    ),
                    _detailRow(
                      c,
                      'Monthly SIP',
                      _currency.format(sip.monthlyAmount),
                    ),
                    _detailRow(
                      c,
                      'SIP Day',
                      '${sip.sipDay}${_daySuffix(sip.sipDay)} of each month',
                    ),
                    _detailRow(
                      c,
                      'Total Units',
                      sip.totalUnits.toStringAsFixed(4),
                    ),
                    _detailRow(
                      c,
                      'Latest NAV',
                      sip.latestNav.toStringAsFixed(4),
                    ),
                    _detailRow(c, 'Started', _dateFmt.format(sip.startDate)),
                    _detailRow(
                      c,
                      'Status',
                      sip.status.name[0].toUpperCase() +
                          sip.status.name.substring(1),
                    ),
                    if (sip.lastUpdated != null)
                      _detailRow(
                        c,
                        'Last Updated',
                        DateFormat(
                          'd MMM yyyy, HH:mm',
                        ).format(sip.lastUpdated!),
                      ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      children: [
                        if (sip.status == SipStatus.active)
                          Expanded(
                            child: _actionBtn(
                              context,
                              c,
                              'Pause SIP',
                              Icons.pause_rounded,
                              const Color(0xFFFFA726),
                              () => _updateStatus(context, SipStatus.paused),
                            ),
                          ),
                        if (sip.status == SipStatus.paused) ...[
                          Expanded(
                            child: _actionBtn(
                              context,
                              c,
                              'Resume SIP',
                              Icons.play_arrow_rounded,
                              const Color(0xFF4CAF50),
                              () => _showResumeDialog(context),
                            ),
                          ),
                        ],
                        if (sip.status != SipStatus.stopped) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionBtn(
                              context,
                              c,
                              'Stop SIP',
                              Icons.stop_rounded,
                              const Color(0xFFEF5350),
                              () => _updateStatus(context, SipStatus.stopped),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _actionBtn(
                        context,
                        c,
                        'Redeem (Remove)',
                        Icons.currency_rupee_rounded,
                        const Color(0xFFEF5350),
                        () => _redeem(context),
                      ),
                    ),
                    // Installment history
                    if (sip.installments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'INSTALLMENT HISTORY',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...sip.installments.reversed.map(
                        (inst) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c.surfaceMid,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _dateFmt.format(inst.date),
                                style: TextStyle(color: c.muted, fontSize: 10),
                              ),
                              const Spacer(),
                              Text(
                                _currency.format(inst.amount),
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'NAV: ${inst.nav.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: c.muted.withAlpha(180),
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${inst.units.toStringAsFixed(3)} u',
                                style: TextStyle(
                                  color: c.muted.withAlpha(180),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(
    AppColors c,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? c.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    BuildContext context,
    AppColors c,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, SipStatus status) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.updateSip(sip.copyWith(status: status));
    Navigator.pop(context);
  }

  void _showResumeDialog(BuildContext context) {
    int newDay = sip.sipDay;
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Resume SIP',
            style: TextStyle(
              color: c.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose the day for SIP deduction next month:',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_rounded, color: c.muted),
                    onPressed: () {
                      if (newDay > 1) setDlgState(() => newDay--);
                    },
                  ),
                  Text(
                    '$newDay',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_rounded, color: c.primary),
                    onPressed: () {
                      if (newDay < 28) setDlgState(() => newDay++);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final provider = Provider.of<AppProvider>(ctx, listen: false);
                provider.updateSip(
                  sip.copyWith(status: SipStatus.active, sipDay: newDay),
                );
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }

  void _redeem(BuildContext context) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Redeem Fund?',
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This will remove "${sip.schemeName}" from your portfolio. Current value: ${_currency.format(sip.currentValue)}',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.currency_rupee_rounded, size: 16),
            label: const Text(
              'Redeem',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              Provider.of<AppProvider>(ctx, listen: false).removeSip(sip.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Add SIP Screen ───────────────────────────────────────────────────────────
class _AddSipScreen extends StatefulWidget {
  const _AddSipScreen();
  @override
  State<_AddSipScreen> createState() => _AddSipScreenState();
}

class _AddSipScreenState extends State<_AddSipScreen> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  Timer? _debounce;
  List<MfSearchResult> _results = [];
  bool _searching = false;
  MfSearchResult? _selected;
  int _sipDay = DateTime.now().day.clamp(1, 28);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _durationCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final results = await MfApiService.search(query);
      if (mounted)
        setState(() {
          _results = results;
          _searching = false;
        });
    });
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'Please select a fund');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter valid monthly amount');
      return;
    }
    final months = int.tryParse(_durationCtrl.text.trim());
    if (months == null || months <= 0) {
      setState(() => _error = 'Enter duration in months');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // Calculate start date based on duration
      final now = DateTime.now();
      final startDate = DateTime(
        now.year,
        now.month - months,
        _sipDay.clamp(1, 28),
      );

      // Fetch NAV history
      final navData = await MfApiService.getNavHistory(
        _selected!.schemeCode,
        startDate: startDate,
      );

      if (navData == null || navData.navs.isEmpty) {
        if (mounted)
          setState(() {
            _error = 'Could not fetch NAV data. Try again.';
            _submitting = false;
          });
        return;
      }

      // Calculate installments
      final installments = <SipInstallment>[];
      double totalUnits = 0;
      double totalInvested = 0;

      for (int i = 0; i < months; i++) {
        final instDate = DateTime(
          startDate.year,
          startDate.month + i,
          _sipDay.clamp(1, 28),
        );
        if (instDate.isAfter(now)) break;

        final closestNav = MfApiService.findClosestNav(navData.navs, instDate);
        if (closestNav == null) continue;

        final units = amount / closestNav.nav;
        totalUnits += units;
        totalInvested += amount;
        installments.add(
          SipInstallment(
            date: instDate,
            nav: closestNav.nav,
            units: units,
            amount: amount,
          ),
        );
      }

      // Get latest NAV for current value
      final latestNavData = await MfApiService.getLatestNav(
        _selected!.schemeCode,
      );
      final latestNav = latestNavData?.navs.isNotEmpty == true
          ? latestNavData!.navs.first.nav
          : (navData.navs.isNotEmpty ? navData.navs.first.nav : 0.0);
      final currentValue = totalUnits * latestNav;

      final sip = SipModel(
        schemeCode: _selected!.schemeCode,
        schemeName: _selected!.schemeName,
        fundHouse: navData.fundHouse,
        monthlyAmount: amount,
        sipDay: _sipDay,
        startDate: startDate,
        totalInvested: totalInvested,
        currentValue: currentValue,
        latestNav: latestNav,
        totalUnits: totalUnits,
        lastUpdated: DateTime.now(),
        installments: installments,
      );

      if (mounted) {
        Provider.of<AppProvider>(context, listen: false).addSip(sip);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Error: $e';
          _submitting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Add SIP',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search
                    Text(
                      'SEARCH MUTUAL FUND',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: c.text, fontSize: 14),
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'e.g. HDFC, SBI, Axis Bluechip…',
                        hintStyle: TextStyle(color: c.muted),
                        filled: true,
                        fillColor: c.surfaceMid,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: c.muted,
                          size: 20,
                        ),
                        suffixIcon: _searching
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.muted,
                                  ),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF66BB6A),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selected!.schemeName,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selected = null;
                                _searchCtrl.clear();
                                _results = [];
                              }),
                              child: Icon(
                                Icons.close_rounded,
                                color: c.muted,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Search results
                    if (_results.isNotEmpty && _selected == null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: c.surfaceMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.sep),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _results.length.clamp(0, 20),
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c.sep),
                          itemBuilder: (_, i) {
                            final r = _results[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                r.schemeName,
                                style: TextStyle(color: c.text, fontSize: 11),
                              ),
                              onTap: () => setState(() {
                                _selected = r;
                                _results = [];
                                _searchCtrl.text = r.schemeName;
                              }),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Amount
                    Text(
                      'MONTHLY SIP AMOUNT (₹)',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: c.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '5000',
                        hintStyle: TextStyle(color: c.muted),
                        filled: true,
                        fillColor: c.surfaceMid,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Duration
                    Text(
                      'HOW LONG (MONTHS)',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: c.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '12',
                        hintStyle: TextStyle(color: c.muted),
                        filled: true,
                        fillColor: c.surfaceMid,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // SIP Day
                    Text(
                      'SIP DEDUCTION DAY',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceMid,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: c.muted,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$_sipDay${_daySuffix(_sipDay)} of each month',
                            style: TextStyle(color: c.text, fontSize: 13),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              if (_sipDay > 1) setState(() => _sipDay--);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.remove_rounded,
                                color: c.muted,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (_sipDay < 28) setState(() => _sipDay++);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: c.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: const Color(
                            0xFF2E7D32,
                          ).withAlpha(100),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Calculate & Add SIP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surfaceMid,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.sep),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: c.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Search and select your mutual fund scheme\n'
                            '• Enter your monthly SIP amount and how many months you\'ve been investing\n'
                            '• We\'ll fetch historical NAV data and calculate your returns\n'
                            '• Your SIP will also be counted as a fixed cost in expenses',
                            style: TextStyle(
                              color: c.muted,
                              fontSize: 10,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Interactive Portfolio Performance Trend Chart ──────────────────────────
class _PortfolioTrendChart extends StatefulWidget {
  final List<SipModel> sips;
  final List<StockModel> stocks;
  const _PortfolioTrendChart({required this.sips, required this.stocks});
  @override
  State<_PortfolioTrendChart> createState() => _PortfolioTrendChartState();
}

class _PortfolioTrendChartState extends State<_PortfolioTrendChart> {
  String _range = '3M'; // 1M, 3M, 1Y, ALL
  bool _loading = false;
  final Map<int, List<NavEntry>> _navHistories = {};
  final Map<String, Map<DateTime, double>> _stockHistories = {};
  List<double> _chartValues = [];
  double _minVal = 0;
  double _maxVal = 0;
  bool _isPos = true;

  @override
  void initState() {
    super.initState();
    _fetchAndCompute();
  }

  @override
  void didUpdateWidget(_PortfolioTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sips != widget.sips || oldWidget.stocks != widget.stocks) {
      _fetchAndCompute();
    }
  }

  Future<void> _fetchAndCompute() async {
    setState(() => _loading = true);
    for (final sip in widget.sips) {
      if (!_navHistories.containsKey(sip.schemeCode)) {
        final data = await MfApiService.getNavHistory(sip.schemeCode);
        if (data != null) {
          _navHistories[sip.schemeCode] = data.navs;
        } else {
          _navHistories[sip.schemeCode] = [];
        }
      }
    }
    for (final stock in widget.stocks) {
      if (!_stockHistories.containsKey(stock.symbol)) {
        final data = await YahooFinanceService.getChart(
          stock.symbol,
          range: 'ALL',
        );
        if (data != null) {
          _stockHistories[stock.symbol] =
              data['history'] as Map<DateTime, double>;
        } else {
          _stockHistories[stock.symbol] = {};
        }
      }
    }
    _computeChart();
  }

  void _computeChart() {
    if (!mounted) return;
    DateTime end = DateTime.now();
    DateTime start;
    if (_range == '1M') {
      start = DateTime(end.year, end.month - 1, end.day);
    } else if (_range == '3M') {
      start = DateTime(end.year, end.month - 3, end.day);
    } else if (_range == '1Y') {
      start = DateTime(end.year - 1, end.month, end.day);
    } else {
      DateTime minD = end;
      for (final sip in widget.sips) {
        if (sip.startDate.isBefore(minD)) minD = sip.startDate;
      }
      for (final stock in widget.stocks) {
        if (stock.buyDate.isBefore(minD)) minD = stock.buyDate;
      }
      start = minD;
    }

    if (end.difference(start).inDays < 7) {
      start = end.subtract(const Duration(days: 7)); // guarantee some width
    }

    List<double> values = [];
    double maxV = 0;
    double minV = double.infinity;
    double startVal = -1;

    final days = end.difference(start).inDays;
    final step = days > 90 ? (days / 90).ceil() : 1;

    for (int i = 0; i <= days; i += step) {
      final d = start.add(Duration(days: i));
      double totalVal = 0;

      for (final sip in widget.sips) {
        double units = 0;
        for (final inst in sip.installments) {
          if (inst.date.isBefore(d) || inst.date.isAtSameMomentAs(d)) {
            units += inst.units;
          }
        }
        if (units > 0 && _navHistories[sip.schemeCode] != null) {
          final nav = MfApiService.findClosestNav(
            _navHistories[sip.schemeCode]!,
            d,
          );
          if (nav != null) totalVal += units * nav.nav;
        }
      }

      for (final stock in widget.stocks) {
        if (stock.buyDate.isBefore(d) || stock.buyDate.isAtSameMomentAs(d)) {
          final hist = _stockHistories[stock.symbol];
          if (hist != null && hist.isNotEmpty) {
            // Find closest date before or equal to d
            DateTime? closest;
            for (final dt in hist.keys) {
              if (dt.isBefore(d) || dt.isAtSameMomentAs(d)) {
                if (closest == null || dt.isAfter(closest)) {
                  closest = dt;
                }
              }
            }
            if (closest != null) {
              totalVal += stock.quantity * hist[closest]!;
            } else {
              totalVal += stock.totalInvested; // fallback
            }
          } else {
            totalVal += stock
                .totalInvested; // Fallback to invested if historic chart fails
          }
        }
      }

      values.add(totalVal);
      if (totalVal > maxV) maxV = totalVal;
      if (totalVal < minV) minV = totalVal;
      if (startVal == -1 && totalVal > 0) startVal = totalVal;
    }

    if (minV == double.infinity) minV = 0;

    setState(() {
      _chartValues = values;
      _minVal = minV;
      _maxVal = maxV;
      _isPos =
          values.isNotEmpty && values.last >= (startVal > 0 ? startVal : 0);
      _loading = false;
    });
  }

  void _setRange(String r) {
    if (_range == r) return;
    setState(() {
      _range = r;
      _loading = true;
    });
    Future.microtask(() => _computeChart());
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1M', '3M', '1Y', 'ALL'].map((r) {
              final sel = _range == r;
              return GestureDetector(
                onTap: () => _setRange(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white24 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : _chartValues.isEmpty
                ? const Center(
                    child: Text(
                      'Not enough data',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  )
                : CustomPaint(
                    painter: _TrendPainter(
                      _chartValues,
                      _minVal * 0.99, // stretch chart a bit
                      _maxVal * 1.01,
                      accent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final double minVal;
  final double maxVal;
  final Color baseColor;

  _TrendPainter(this.values, this.minVal, this.maxVal, this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final range = maxVal - minVal;
    final w = size.width;
    final h = size.height;

    final path = Path();
    final stepX = w / (values.length > 1 ? values.length - 1 : 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = range <= 0 ? h : h - ((values[i] - minVal) / range * h);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paintLine = Paint()
      ..color = baseColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, paintLine);

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [baseColor.withAlpha(80), baseColor.withAlpha(0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, paintFill);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}

// ─── Add Stock Screen ─────────────────────────────────────────────────────────
class _AddStockScreen extends StatefulWidget {
  const _AddStockScreen();

  @override
  State<_AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<_AddStockScreen> {
  final _searchCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<StockSearchResult> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  StockSearchResult? _selectedStock;
  DateTime _purchaseDate = DateTime.now();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final q = _searchCtrl.text.trim();
      if (q.length < 2) {
        setState(() => _searchResults = []);
        return;
      }
      setState(() => _searching = true);
      final res = await YahooFinanceService.search(q);
      if (mounted) {
        setState(() {
          _searchResults = res;
          _searching = false;
        });
      }
    });
  }

  void _selectStock(StockSearchResult s) {
    setState(() {
      _selectedStock = s;
      _searchCtrl.text = s.shortName;
      _searchResults = [];
    });
  }

  Future<void> _submit() async {
    if (_selectedStock == null) {
      setState(() => _error = 'Please select a stock/asset first.');
      return;
    }
    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (qty <= 0) {
      setState(() => _error = 'Please enter a valid quantity.');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Please enter a valid average price.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final appProv = Provider.of<AppProvider>(context, listen: false);
      final chart = await YahooFinanceService.getChart(_selectedStock!.symbol);
      final latestPrice = chart?['latest'] as double? ?? price;

      final stock = StockModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: _selectedStock!.symbol,
        name: _selectedStock!.shortName,
        quantity: qty,
        averagePrice: price,
        buyDate: _purchaseDate,
        latestPrice: latestPrice,
      );

      await appProv.addStock(stock);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error adding stock: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Stock / Asset',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search
                    Text(
                      'Search Company / Symbol',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.sep),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) {
                          if (_selectedStock != null) {
                            setState(() => _selectedStock = null);
                          }
                          _onSearchChanged();
                        },
                        style: TextStyle(color: c.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Reliance, AAPL, TCS',
                          hintStyle: TextStyle(
                            color: c.muted.withAlpha(100),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: c.muted,
                            size: 18,
                          ),
                          suffixIcon: _searching
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.blue,
                                    ),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: c.surfaceMid,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.sep),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length > 5
                              ? 5
                              : _searchResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c.sep),
                          itemBuilder: (ctx, i) {
                            final res = _searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                res.shortName,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${res.symbol} • ${res.exchange}',
                                style: TextStyle(color: c.muted, fontSize: 10),
                              ),
                              onTap: () => _selectStock(res),
                            );
                          },
                        ),
                      ),
                    ],

                    if (_selectedStock != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Quantity (Units)',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.sep),
                        ),
                        child: TextField(
                          controller: _quantityCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            color: c.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: c.muted.withAlpha(50)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Average Buy Price',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.sep),
                        ),
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            color: c.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: c.muted.withAlpha(50)),
                            border: InputBorder.none,
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(color: c.text, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Purchase Date',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _purchaseDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _purchaseDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.sep),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}',
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_rounded,
                                color: c.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Add Asset',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stock Detail Sheet ────────────────────────────────────────────────────────
class _StockDetailSheet extends StatelessWidget {
  final StockModel stock;
  const _StockDetailSheet({required this.stock});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final returnAmt = stock.currentValue - stock.totalInvested;
    final isPos = returnAmt >= 0;

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.muted.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            stock.symbol,
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(stock.name, style: TextStyle(color: c.muted, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  c,
                  'Invested',
                  _currency.format(stock.totalInvested),
                  c.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  c,
                  'Current Value',
                  _currency.format(stock.currentValue),
                  c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  c,
                  'Total Return',
                  '${isPos ? "+" : ""}${_currency.format(returnAmt)}',
                  isPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  c,
                  'Return %',
                  '${isPos ? "+" : ""}${stock.returnPercent.toStringAsFixed(2)}%',
                  isPos ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  c,
                  'Quantity',
                  stock.quantity.toStringAsFixed(2),
                  c.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  c,
                  'Avg. Price',
                  _currency.format(stock.averagePrice),
                  c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Provider.of<AppProvider>(
                  context,
                  listen: false,
                ).removeStock(stock.id);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete Stock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(AppColors c, String label, String value, Color vColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: vColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
