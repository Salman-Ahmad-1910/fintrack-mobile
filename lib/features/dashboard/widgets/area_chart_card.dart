import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/formatters.dart';
import '../../../core/session.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../transaction/collection_details_screen.dart';

enum ChartKind { collection, growth }

const List<(String, String)> _periodTabs = [
  ('daily', '1D'),
  ('weekly', '1W'),
  ('monthly', '1M'),
  ('yearly', '1Y'),
];

/// Google-finance style area chart card — ports both
/// `daily-collection-chart.tsx` and `subscriber-growth-chart.tsx`
/// (step-after area, 1D/1W/1M/1Y tabs, 30s auto-refresh, summary footer).
class AreaChartCard extends StatefulWidget {
  const AreaChartCard({super.key, required this.kind, this.liveCount});

  final ChartKind kind;
  final int? liveCount;

  @override
  State<AreaChartCard> createState() => _AreaChartCardState();
}

class _AreaChartCardState extends State<AreaChartCard> {
  String _period = 'daily';
  String _selectedMonth = '';
  List<ChartPoint> _points = [];
  double _periodTotal = 0;
  bool _loading = true;
  double? _touchedX;
  Timer? _timer;
  Timer? _debounce;

  bool get _isCollection => widget.kind == ChartKind.collection;

  List<String> get _monthOptions {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  String get _currentMonth =>
      '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}';

  bool get _isCurrentMonth =>
      _selectedMonth.isEmpty || _selectedMonth == _currentMonth;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final path = _isCollection
        ? '/dashboard/collection-chart'
        : '/dashboard/subscriber-growth-chart';
    final query = <String, String>{
      'companyId': cid,
      'period': _period,
      if (_period == 'monthly' && _selectedMonth.isNotEmpty)
        'month': _selectedMonth,
    };

    try {
      final json = await ApiClient().get(path, query: query);
      final series = ChartSeries.fromJson(json);
      if (!mounted) return;
      setState(() {
        _points = series.points;
        _periodTotal = series.periodTotal;
        _loading = false;
        _touchedX = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _points = [];
        _loading = false;
      });
      if (e.isUnauthorized) return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _points = [];
        _loading = false;
      });
    }
  }

  void _setPeriod(String period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      if (period != 'monthly') _selectedMonth = '';
      _loading = true;
      _points = [];
      _touchedX = null;
    });
    _fetch();
  }

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _monthOptions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = _monthOptions[i];
            final d = DateTime.parse('$m-01');
            final label = '${kMonthNames[d.month - 1]} ${d.year}';
            final selected = m == _selectedMonth;
            return ListTile(
              dense: true,
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, m),
            );
          },
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedMonth = picked;
      _loading = true;
      _points = [];
    });
    _fetch();
  }

  // ---------------------------------------------------------------- data ----

  List<double> get _xValues {
    if (_period != 'daily') {
      return List.generate(_points.length, (i) => i.toDouble());
    }
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _points.map((p) {
      final d = parseServerDate(p.label);
      if (d == null) return 0.0;
      final local = d.toLocal();
      return local.difference(startOfDay).inMilliseconds / 3600000.0;
    }).toList();
  }

  List<FlSpot> _spots(List<double> xs) {
    final spots = <FlSpot>[];
    for (var i = 0; i < _points.length; i++) {
      spots.add(FlSpot(xs[i], _points[i].value));
      if (i < _points.length - 1) {
        spots.add(FlSpot(xs[i + 1], _points[i].value));
      }
    }
    return spots;
  }

  double get _maxX {
    if (_points.isEmpty) return 1;
    if (_period == 'daily') return 24;
    return (_points.length - 1).toDouble();
  }

  (double, double) get _yDomain {
    if (_points.isEmpty) return (0, 10);
    final values = _points.map((p) => p.value);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final padding = ((max - min) * 0.25).clamp(1, double.infinity);
    return ((min - padding) < 0 ? 0.0 : (min - padding), max + padding);
  }

  ({double endValue, double changeAbs, double changePct, bool isUp})
  get _summary {
    if (_points.isEmpty) {
      return (endValue: 0.0, changeAbs: 0.0, changePct: 0.0, isUp: true);
    }
    final start = _points.first.value;
    double end;
    if (!_isCollection) {
      final live = widget.liveCount;
      final fallback = _points.last.value;
      final effective = (live != null && !live.isNaN)
          ? live.toDouble()
          : fallback;
      end = (_period == 'daily' || _isCurrentMonth)
          ? effective
          : _points.last.value;
    } else {
      end = _points.last.value;
    }
    final abs = end - start;
    final pct = start != 0 ? (abs / start) * 100 : (abs > 0 ? 100.0 : 0.0);
    return (endValue: end, changeAbs: abs, changePct: pct, isUp: abs >= 0);
  }

  String get _tabLabel => _periodTabs
      .firstWhere((t) => t.$1 == _period, orElse: () => ('daily', '1D'))
      .$2;

  String get _summaryLabel {
    if (_period == 'daily') return "Today's Collection";
    if (_period == 'weekly') return "This Week's Collection";
    if (_period == 'yearly') return "This Year's Collection";
    if (_selectedMonth.isNotEmpty) {
      final d = DateTime.parse('$_selectedMonth-01');
      return '${kMonthNames[d.month - 1]} ${d.year} Collection';
    }
    return "This Month's Collection";
  }

  String _valueText(double v) =>
      _isCollection ? compactCurrency(v) : v.round().toString();

  // --------------------------------------------------------------- render ---

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final lineColor = summary.isUp ? AppColors.chartUp : AppColors.chartDown;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(lineColor, summary),
          const SizedBox(height: 8),
          SizedBox(height: 260, child: _buildBody(lineColor)),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _tabsRow(),
          if (_isCollection) ...[const SizedBox(height: 8), _footer()],
        ],
      ),
    );
  }

  Widget _header(
    Color lineColor,
    ({double endValue, double changeAbs, double changePct, bool isUp}) summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isCollection
                  ? Icons.account_balance_wallet_outlined
                  : Icons.people_outline,
              size: 14,
              color: context.mutedFg,
            ),
            const SizedBox(width: 8),
            Text(
              _isCollection ? 'Collection' : 'Active Subscribers',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
            const Spacer(),
            if (_isCollection)
              InkWell(
                onTap: () {
                  final month = _period == 'monthly' && _selectedMonth.isNotEmpty
                      ? _selectedMonth
                      : null;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CollectionDetailsScreen(
                        period: _period,
                        month: month,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View $_tabLabel Details',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.north_east,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isCollection
                          ? compactCurrency(summary.endValue)
                          : summary.endValue.round().toString(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.isUp ? '▲' : '▼'} ${_valueText(summary.changeAbs.abs())} '
                    '(${summary.isUp ? '+' : ''}${summary.changePct.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: lineColor,
                    ),
                  ),
                ],
              ),
            ),
            if (_period == 'monthly')
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: context.mutedFg,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedMonth.isEmpty
                            ? 'Select month'
                            : _monthLabel(_selectedMonth),
                        style: TextStyle(fontSize: 11, color: context.fg),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: context.mutedFg,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _monthLabel(String ym) {
    final d = DateTime.parse('$ym-01');
    return '${kMonthNames[d.month - 1]} ${d.year}';
  }

  Widget _buildBody(Color lineColor) {
    if (_loading && _points.isEmpty) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3, color: context.fg),
        ),
      );
    }
    if (_points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isCollection
                  ? Icons.account_balance_wallet_outlined
                  : Icons.people_outline,
              size: 28,
              color: context.mutedFg.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              _isCollection ? 'No collection data yet' : 'No subscribers yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.mutedFg,
              ),
            ),
          ],
        ),
      );
    }

    final xs = _xValues;
    final spots = _spots(xs);
    final (yMin, yMax) = _yDomain;
    final interval = _period == 'daily'
        ? 6.0
        : (_points.length / 6)
              .ceilToDouble()
              .clamp(1, double.infinity)
              .toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: _maxX,
        minY: yMin,
        maxY: yMax,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.lineBarSpots == null ||
                response.lineBarSpots!.isEmpty) {
              if (_touchedX != null) setState(() => _touchedX = null);
              return;
            }
            final x = response.lineBarSpots!.first.x;
            if (x != _touchedX) setState(() => _touchedX = x);
          },
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) => [
            TouchedSpotIndicatorData(
              FlLine(color: lineColor, strokeWidth: 1, dashArray: [4, 4]),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: lineColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
            ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.round().clamp(0, _points.length - 1);
                final label = _period == 'daily'
                    ? _dailyTimeLabel(spot.x)
                    : tooltipLabel(_points[index].label, _period);
                final value = _isCollection
                    ? compactCurrency(spot.y)
                    : '${spot.y.round()} active';
                return LineTooltipItem(
                  '$label\n$value',
                  TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (_touchedX != null)
              VerticalLine(
                x: _touchedX!,
                color: lineColor.withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.18),
                  lineColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                if (value < -0.001 || value > _maxX + 0.001) {
                  return const SizedBox.shrink();
                }
                String text;
                if (_period == 'daily') {
                  text = '${value.round()}:00';
                } else {
                  final index = value.round();
                  if (index < 0 || index >= _points.length) {
                    return const SizedBox.shrink();
                  }
                  text = axisLabel(_points[index].label, _period);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 11, color: context.mutedFg),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  String _dailyTimeLabel(double x) {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final t = dayStart.add(Duration(milliseconds: (x * 3600000).round()));
    return DateFormat('h:mm a').format(t);
  }

  Widget _tabsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (key, label) in _periodTabs)
          GestureDetector(
            onTap: () => _setPeriod(key),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _period == key ? context.fg : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _period == key ? context.bg : context.mutedFg,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.subtle.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _summaryLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.mutedFg,
              ),
            ),
          ),
          Text(
            compactCurrency(_periodTotal),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
