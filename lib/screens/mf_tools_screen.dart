import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mf_api_service.dart';
import '../theme/app_theme.dart';

final _cur = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

// ─── Main MF Tools Screen ─────────────────────────────────────────────────────
class MfToolsScreen extends StatefulWidget {
  const MfToolsScreen({super.key});
  @override
  State<MfToolsScreen> createState() => _MfToolsScreenState();
}

class _MfToolsScreenState extends State<MfToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'MF Explorer & Tools',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: c.surfaceMid,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: c.muted,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Explorer'),
                  Tab(text: 'Compare'),
                  Tab(text: 'Calculator'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _ExplorerTab(),
                  _CompareTab(),
                  _CalculatorTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: EXPLORER
// ═══════════════════════════════════════════════════════════════════════════════
class _ExplorerTab extends StatefulWidget {
  const _ExplorerTab();
  @override
  State<_ExplorerTab> createState() => _ExplorerTabState();
}

class _ExplorerTabState extends State<_ExplorerTab>
    with AutomaticKeepAliveClientMixin {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<MfSearchResult> _results = [];
  bool _searching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.trim().length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await MfApiService.search(q);
      if (mounted)
        setState(() {
          _results = r;
          _searching = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search mutual funds…',
              hintStyle: TextStyle(color: c.muted),
              filled: true,
              fillColor: c.surfaceMid,
              prefixIcon: Icon(Icons.search_rounded, color: c.muted, size: 20),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
        ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_rounded, color: c.muted, size: 44),
                      const SizedBox(height: 8),
                      Text(
                        'Search any mutual fund',
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                      Text(
                        'e.g. HDFC, SBI Bluechip, Axis…',
                        style: TextStyle(
                          color: c.muted.withAlpha(120),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _results.length.clamp(0, 30),
                  separatorBuilder: (_, __) => Divider(height: 1, color: c.sep),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      title: Text(
                        r.schemeName,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Code: ${r.schemeCode}',
                        style: TextStyle(color: c.muted, fontSize: 9),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.muted,
                        size: 18,
                      ),
                      onTap: () => _showFundDetail(context, r),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showFundDetail(BuildContext context, MfSearchResult r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FundDetailScreen(
          schemeCode: r.schemeCode,
          schemeName: r.schemeName,
        ),
      ),
    );
  }
}

// ─── Fund Detail Screen ───────────────────────────────────────────────────────
class _FundDetailScreen extends StatefulWidget {
  final int schemeCode;
  final String schemeName;
  const _FundDetailScreen({required this.schemeCode, required this.schemeName});
  @override
  State<_FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<_FundDetailScreen> {
  MfSchemeData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await MfApiService.getNavHistory(widget.schemeCode);
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
        if (data == null) _error = 'Could not load fund data';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.schemeName,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(_error!, style: TextStyle(color: c.muted)),
                ),
              )
            else if (_data != null)
              Expanded(child: _buildContent(c, _data!)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColors c, MfSchemeData data) {
    final latestNav = data.navs.isNotEmpty ? data.navs.first.nav : 0.0;
    final nav1y = data.navs.length > 250
        ? data.navs[250].nav
        : (data.navs.isNotEmpty ? data.navs.last.nav : 0.0);
    final ret1y = nav1y > 0 ? ((latestNav - nav1y) / nav1y * 100) : 0.0;
    final nav3y = data.navs.length > 750 ? data.navs[750].nav : null;
    final ret3y = nav3y != null && nav3y > 0
        ? ((latestNav - nav3y) / nav3y * 100)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Fund info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.fundHouse.isNotEmpty)
                Text(
                  data.fundHouse,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'NAV: ₹${latestNav.toStringAsFixed(4)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (data.navs.isNotEmpty)
                Text(
                  'as of ${data.navs.first.date.day}/${data.navs.first.date.month}/${data.navs.first.date.year}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _retPill(
                    '1Y Return',
                    '${ret1y.toStringAsFixed(1)}%',
                    ret1y >= 0,
                  ),
                  const SizedBox(width: 8),
                  if (ret3y != null)
                    _retPill(
                      '3Y Return',
                      '${ret3y.toStringAsFixed(1)}%',
                      ret3y >= 0,
                    ),
                ],
              ),
              if (data.schemeCategory.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.schemeCategory,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // NAV history
        Text(
          'RECENT NAV HISTORY',
          style: TextStyle(
            color: c.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        // Simple chart using bars
        _SimpleNavChart(navs: data.navs.take(60).toList(), c: c),
        const SizedBox(height: 16),
        // Table
        ...data.navs
            .take(30)
            .map(
              (n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${n.date.day.toString().padLeft(2, '0')}/${n.date.month.toString().padLeft(2, '0')}/${n.date.year}',
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                    Text(
                      '₹${n.nav.toStringAsFixed(4)}',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _retPill(String label, String value, bool positive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: positive
                  ? const Color(0xFF81C784)
                  : const Color(0xFFEF5350),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// Simple NAV chart
class _SimpleNavChart extends StatelessWidget {
  final List<NavEntry> navs;
  final AppColors c;
  const _SimpleNavChart({required this.navs, required this.c});

  @override
  Widget build(BuildContext context) {
    if (navs.isEmpty) return const SizedBox.shrink();
    final reversed = navs.reversed.toList();
    final maxNav = reversed.fold<double>(0, (m, n) => n.nav > m ? n.nav : m);
    final minNav = reversed.fold<double>(
      double.infinity,
      (m, n) => n.nav < m ? n.nav : m,
    );
    final range = maxNav - minNav;
    if (range == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: reversed.map((n) {
          final frac = (n.nav - minNav) / range;
          final isUp = reversed.last.nav >= reversed.first.nav;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: 10 + frac * 65,
              decoration: BoxDecoration(
                color: isUp
                    ? const Color(0xFF4CAF50).withAlpha(180)
                    : const Color(0xFFEF5350).withAlpha(180),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: COMPARE 2 MFs
// ═══════════════════════════════════════════════════════════════════════════════
class _CompareTab extends StatefulWidget {
  const _CompareTab();
  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab>
    with AutomaticKeepAliveClientMixin {
  MfSearchResult? _fund1, _fund2;
  int _fromYear = DateTime.now().year - 3;
  int _toYear = DateTime.now().year;
  double _monthlyAmount = 5000;
  final _amtCtrl = TextEditingController(text: '5000');
  bool _comparing = false;
  _CompareResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    if (_fund1 == null || _fund2 == null) return;
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) return;
    _monthlyAmount = amt;
    setState(() => _comparing = true);

    final start = DateTime(_fromYear, 1, 1);
    final end = DateTime(_toYear, 12, 31);

    final d1 = await MfApiService.getNavHistory(
      _fund1!.schemeCode,
      startDate: start,
      endDate: end,
    );
    final d2 = await MfApiService.getNavHistory(
      _fund2!.schemeCode,
      startDate: start,
      endDate: end,
    );

    if (d1 != null && d2 != null && d1.navs.isNotEmpty && d2.navs.isNotEmpty) {
      final r1 = _calcSipReturns(d1.navs, start, end, _monthlyAmount);
      final r2 = _calcSipReturns(d2.navs, start, end, _monthlyAmount);
      if (mounted) {
        setState(() {
          _result = _CompareResult(
            fund1Name: _fund1!.schemeName,
            fund2Name: _fund2!.schemeName,
            fund1House: d1.fundHouse,
            fund2House: d2.fundHouse,
            r1: r1,
            r2: r2,
          );
          _comparing = false;
        });
      }
    } else {
      if (mounted) setState(() => _comparing = false);
    }
  }

  _SipCalcResult _calcSipReturns(
    List<NavEntry> navs,
    DateTime start,
    DateTime end,
    double monthlyAmt,
  ) {
    double totalUnits = 0, totalInvested = 0;
    int installments = 0;
    var d = DateTime(start.year, start.month, 1);
    while (d.isBefore(end) || d.isAtSameMomentAs(end)) {
      final nav = MfApiService.findClosestNav(navs, d);
      if (nav != null) {
        totalUnits += monthlyAmt / nav.nav;
        totalInvested += monthlyAmt;
        installments++;
      }
      d = DateTime(d.year, d.month + 1, 1);
    }
    final latestNav = navs.isNotEmpty ? navs.first.nav : 0.0;
    final currentValue = totalUnits * latestNav;
    return _SipCalcResult(
      totalInvested: totalInvested,
      currentValue: currentValue,
      totalUnits: totalUnits,
      installments: installments,
      latestNav: latestNav,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPARE TWO MUTUAL FUNDS',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _FundPicker(
            label: 'Fund 1',
            selected: _fund1,
            color: const Color(0xFF4CAF50),
            onSelected: (r) => setState(() => _fund1 = r),
          ),
          const SizedBox(height: 8),
          _FundPicker(
            label: 'Fund 2',
            selected: _fund2,
            color: const Color(0xFF2196F3),
            onSelected: (r) => setState(() => _fund2 = r),
          ),
          const SizedBox(height: 16),
          // Year range
          Text(
            'INVESTMENT PERIOD',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _yearPicker(
                  c,
                  'From',
                  _fromYear,
                  (y) => setState(() => _fromYear = y),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: c.muted,
                  size: 18,
                ),
              ),
              Expanded(
                child: _yearPicker(
                  c,
                  'To',
                  _toYear,
                  (y) => setState(() => _toYear = y),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            controller: _amtCtrl,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _comparing ? null : _compare,
              icon: _comparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.compare_arrows_rounded, size: 18),
              label: Text(
                _comparing ? 'Comparing…' : 'Compare Funds',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildCompareResults(c, _result!),
          ],
        ],
      ),
    );
  }

  Widget _yearPicker(
    AppColors c,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final now = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceMid,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: c.muted, fontSize: 11)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (value > 2000) onChanged(value - 1);
            },
            child: Icon(
              Icons.remove_circle_outline_rounded,
              color: c.muted,
              size: 18,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$value',
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (value < now) onChanged(value + 1);
            },
            child: Icon(
              Icons.add_circle_outline_rounded,
              color: c.primary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareResults(AppColors c, _CompareResult r) {
    final r1 = r.r1;
    final r2 = r.r2;
    final r1ret = r1.currentValue - r1.totalInvested;
    final r2ret = r2.currentValue - r2.totalInvested;
    final r1pct = r1.totalInvested > 0 ? (r1ret / r1.totalInvested * 100) : 0.0;
    final r2pct = r2.totalInvested > 0 ? (r2ret / r2.totalInvested * 100) : 0.0;
    final winner = r1pct >= r2pct ? 1 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESULTS',
          style: TextStyle(
            color: c.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        // Winner banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (winner == 1
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2196F3))
                    .withAlpha(30),
                (winner == 1
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2196F3))
                    .withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  (winner == 1
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2196F3))
                      .withAlpha(80),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: winner == 1
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${winner == 1 ? r.fund1Name : r.fund2Name} wins with ${(winner == 1 ? r1pct : r2pct).toStringAsFixed(1)}% returns!',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Comparison cards
        _compareCard(c, r.fund1Name, r.fund1House, r1, const Color(0xFF4CAF50)),
        const SizedBox(height: 8),
        _compareCard(c, r.fund2Name, r.fund2House, r2, const Color(0xFF2196F3)),
      ],
    );
  }

  Widget _compareCard(
    AppColors c,
    String name,
    String house,
    _SipCalcResult r,
    Color accent,
  ) {
    final ret = r.currentValue - r.totalInvested;
    final pct = r.totalInvested > 0 ? (ret / r.totalInvested * 100) : 0.0;
    final isPos = ret >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          if (house.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(house, style: TextStyle(color: c.muted, fontSize: 9)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _col(c, 'Invested', _cur.format(r.totalInvested)),
              _col(c, 'Current', _cur.format(r.currentValue)),
              _col(
                c,
                'Returns',
                '${isPos ? "+" : ""}${pct.toStringAsFixed(1)}%',
                color: isPos
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFEF5350),
              ),
              _col(
                c,
                'Gain',
                '${isPos ? "+" : ""}${_cur.format(ret)}',
                color: isPos
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(AppColors c, String label, String value, {Color? color}) {
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
                color: color ?? c.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareResult {
  final String fund1Name, fund2Name, fund1House, fund2House;
  final _SipCalcResult r1, r2;
  const _CompareResult({
    required this.fund1Name,
    required this.fund2Name,
    required this.fund1House,
    required this.fund2House,
    required this.r1,
    required this.r2,
  });
}

class _SipCalcResult {
  final double totalInvested, currentValue, totalUnits, latestNav;
  final int installments;
  const _SipCalcResult({
    required this.totalInvested,
    required this.currentValue,
    required this.totalUnits,
    required this.installments,
    required this.latestNav,
  });
}

// ─── Reusable Fund Picker ─────────────────────────────────────────────────────
class _FundPicker extends StatefulWidget {
  final String label;
  final MfSearchResult? selected;
  final Color color;
  final ValueChanged<MfSearchResult> onSelected;
  const _FundPicker({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });
  @override
  State<_FundPicker> createState() => _FundPickerState();
}

class _FundPickerState extends State<_FundPicker> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<MfSearchResult> _results = [];
  bool _searching = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.trim().length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await MfApiService.search(q);
      if (mounted)
        setState(() {
          _results = r;
          _searching = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.selected != null && !_showSearch) {
      return GestureDetector(
        onTap: () => setState(() => _showSearch = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.color.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.selected!.schemeName,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.edit_rounded, color: c.muted, size: 14),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          style: TextStyle(color: c.text, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Search ${widget.label}…',
            hintStyle: TextStyle(color: c.muted),
            filled: true,
            fillColor: c.surfaceMid,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: widget.color,
              size: 18,
            ),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: c.surfaceMid,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.sep),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length.clamp(0, 15),
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    r.schemeName,
                    style: TextStyle(color: c.text, fontSize: 10),
                  ),
                  onTap: () {
                    widget.onSelected(r);
                    setState(() {
                      _showSearch = false;
                      _results = [];
                      _ctrl.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3: SIP CALCULATOR
// ═══════════════════════════════════════════════════════════════════════════════
class _CalculatorTab extends StatefulWidget {
  const _CalculatorTab();
  @override
  State<_CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<_CalculatorTab>
    with AutomaticKeepAliveClientMixin {
  MfSearchResult? _fund;
  int _fromYear = DateTime.now().year - 5;
  int _toYear = DateTime.now().year;
  final _amtCtrl = TextEditingController(text: '5000');
  String _freq = 'Monthly'; // Monthly, Quarterly, Half-Yearly
  bool _calculating = false;
  _CalcOutput? _output;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_fund == null) return;
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) return;
    setState(() => _calculating = true);

    final start = DateTime(_fromYear, 1, 1);
    final end = DateTime(_toYear, 12, 31);
    final data = await MfApiService.getNavHistory(
      _fund!.schemeCode,
      startDate: start,
      endDate: end,
    );

    if (data != null && data.navs.isNotEmpty) {
      final monthStep = _freq == 'Monthly' ? 1 : (_freq == 'Quarterly' ? 3 : 6);
      double totalUnits = 0, totalInvested = 0;
      int installments = 0;
      final yearlyBreakdown = <int, _YearBreak>{};

      var d = DateTime(start.year, start.month, 1);
      while (d.isBefore(end) || d.isAtSameMomentAs(end)) {
        final nav = MfApiService.findClosestNav(data.navs, d);
        if (nav != null) {
          totalUnits += amt / nav.nav;
          totalInvested += amt;
          installments++;
          yearlyBreakdown.putIfAbsent(d.year, () => _YearBreak());
          yearlyBreakdown[d.year]!.invested += amt;
          yearlyBreakdown[d.year]!.installments++;
        }
        d = DateTime(d.year, d.month + monthStep, 1);
      }
      final latestNav = data.navs.first.nav;
      final currentValue = totalUnits * latestNav;

      // Fill in current value for each year
      for (final yr in yearlyBreakdown.keys) {
        final yrEnd = DateTime(yr, 12, 31);
        final navAtEnd = MfApiService.findClosestNav(data.navs, yrEnd);
        if (navAtEnd != null) {
          yearlyBreakdown[yr]!.navAtEnd = navAtEnd.nav;
        }
      }

      if (mounted) {
        setState(() {
          _output = _CalcOutput(
            fundName: _fund!.schemeName,
            fundHouse: data.fundHouse,
            totalInvested: totalInvested,
            currentValue: currentValue,
            totalUnits: totalUnits,
            installments: installments,
            latestNav: latestNav,
            freq: _freq,
            amount: amt,
            yearly: yearlyBreakdown,
          );
          _calculating = false;
        });
      }
    } else {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIP RETURN CALCULATOR',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'See how much you would have earned investing in any fund',
            style: TextStyle(color: c.muted, fontSize: 10),
          ),
          const SizedBox(height: 12),
          _FundPicker(
            label: 'Fund',
            selected: _fund,
            color: const Color(0xFFFF9800),
            onSelected: (r) => setState(() => _fund = r),
          ),
          const SizedBox(height: 14),
          // Period
          Text(
            'PERIOD',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _yrPicker(
                  c,
                  'From',
                  _fromYear,
                  (y) => setState(() => _fromYear = y),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: c.muted,
                  size: 16,
                ),
              ),
              Expanded(
                child: _yrPicker(
                  c,
                  'To',
                  _toYear,
                  (y) => setState(() => _toYear = y),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'AMOUNT PER INSTALLMENT (₹)',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amtCtrl,
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
          const SizedBox(height: 14),
          Text(
            'FREQUENCY',
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: ['Monthly', 'Quarterly', 'Half-Yearly'].map((f) {
              final sel = _freq == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _freq = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? c.primary : c.surfaceMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? c.primary : c.sep),
                    ),
                    child: Center(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: sel ? Colors.white : c.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _calculating ? null : _calculate,
              icon: _calculating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.calculate_rounded, size: 18),
              label: Text(
                _calculating ? 'Calculating…' : 'Calculate Returns',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_output != null) ...[
            const SizedBox(height: 20),
            _buildCalcOutput(c, _output!),
          ],
        ],
      ),
    );
  }

  Widget _yrPicker(
    AppColors c,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final now = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceMid,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('$label ', style: TextStyle(color: c.muted, fontSize: 10)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (value > 2000) onChanged(value - 1);
            },
            child: Icon(
              Icons.remove_circle_outline_rounded,
              color: c.muted,
              size: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (value < now) onChanged(value + 1);
            },
            child: Icon(
              Icons.add_circle_outline_rounded,
              color: c.primary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcOutput(AppColors c, _CalcOutput o) {
    final ret = o.currentValue - o.totalInvested;
    final pct = o.totalInvested > 0 ? (ret / o.totalInvested * 100) : 0.0;
    final isPos = ret >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big result card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF9800).withAlpha(25),
                const Color(0xFFFFA726).withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFF9800).withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                o.fundName,
                style: TextStyle(
                  color: c.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
              ),
              if (o.fundHouse.isNotEmpty)
                Text(
                  o.fundHouse,
                  style: TextStyle(color: c.muted, fontSize: 9),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _col2(c, 'Invested', _cur.format(o.totalInvested)),
                  _col2(c, 'Current Value', _cur.format(o.currentValue)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _col2(
                    c,
                    'Total Gain',
                    '${isPos ? "+" : ""}${_cur.format(ret)}',
                    color: isPos
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFEF5350),
                  ),
                  _col2(
                    c,
                    'Return %',
                    '${isPos ? "+" : ""}${pct.toStringAsFixed(1)}%',
                    color: isPos
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFEF5350),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _col2(c, 'Frequency', o.freq),
                  _col2(c, 'Installments', '${o.installments}'),
                  _col2(c, 'Per Installment', _cur.format(o.amount)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _col2(AppColors c, String label, String value, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
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
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color ?? c.text,
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
}

class _CalcOutput {
  final String fundName, fundHouse, freq;
  final double totalInvested, currentValue, totalUnits, latestNav, amount;
  final int installments;
  final Map<int, _YearBreak> yearly;
  const _CalcOutput({
    required this.fundName,
    required this.fundHouse,
    required this.totalInvested,
    required this.currentValue,
    required this.totalUnits,
    required this.installments,
    required this.latestNav,
    required this.freq,
    required this.amount,
    required this.yearly,
  });
}

class _YearBreak {
  double invested = 0;
  int installments = 0;
  double navAtEnd = 0;
}
