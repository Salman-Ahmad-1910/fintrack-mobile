import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/formatters.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'widgets/area_chart_card.dart';
import 'widgets/gauge_meter.dart';
import 'widgets/metric_cards.dart';
import 'widgets/tables.dart';

/// Same gates the web client uses (`lib/permission-pages.ts`).
const String kDashboardSummaryPermission = '15334';
const List<String> _adminRoles = ['admin', 'owner', 'manager'];

bool _hasPermission(
  List<String> granted,
  bool configured,
  bool isAdmin,
  String id,
) {
  if (isAdmin || !configured) return true;
  return granted.contains(id);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  DashboardData? _data;
  bool _loading = true;
  String? _error;

  bool _showSummary = false;
  String _selectedMonth = '';
  String _selectedYear = '';
  String _packageType = 'both';
  double _target = 0;

  bool _canViewSummary = true;

  static const String _timeRange = 'monthly';

  static void _handleUnauthorized() {
    Session.clear();
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();
    _selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedYear = now.year.toString();

    final role = Session.role ?? '';
    final isAdmin = _adminRoles.contains(role);
    _canViewSummary = _hasPermission(
      Session.permissions,
      Session.permissionsConfigured,
      isAdmin,
      kDashboardSummaryPermission,
    );

    Session.collectionTarget().then((value) {
      if (mounted) setState(() => _target = value);
    });

    _fetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _data != null) _fetch();
  }

  Future<void> _fetch() async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No company selected';
      });
      return;
    }
    if (_data == null) setState(() => _loading = true);

    try {
      final json = await _api.get(
        '/dashboard',
        query: {
          'companyId': cid,
          'range': _timeRange,
          'packageType': _packageType,
          'month': _selectedMonth,
          'year': _selectedYear,
        },
      );
      if (!mounted) return;
      setState(() {
        _data = DashboardData.fromJson(json);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _onTargetSave(double value) async {
    setState(() => _target = value);
    await Session.saveCollectionTarget(value);
  }

  void _notImplemented() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This section is not part of the dashboard build yet'),
      ),
    );
  }

  String get _companyName => Session.companyName ?? '';
  String get _monthName => kMonthNames[int.parse(_selectedMonth) - 1];

  // -------------------------------------------------------------- widgets ---

  @override
  Widget build(BuildContext context) {
    // The Scaffold (top bar + sidebar) is provided by AppShell; this screen
    // only renders the scrollable dashboard body.
    return RefreshIndicator(onRefresh: _fetch, child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _data == null) return _buildSkeleton();
    if (_data == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.cloud_off,
            size: 48,
            color: context.mutedFg.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Could not load dashboard data. Please try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.mutedFg),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _fetch();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final data = _data!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeader(data),
        const SizedBox(height: 24),
        if (_canViewSummary) ...[
          _summaryToggle(),
          if (_showSummary) ...[
            const SizedBox(height: 16),
            SubscriberStatsRow(
              stats: data.subscribersStats,
              packageType: _packageType,
              companyName: _companyName,
              onTap: (_) => _notImplemented(),
            ),
            const SizedBox(height: 16),
            _filtersRow(),
            const SizedBox(height: 16),
            FinancialMetricsGrid(
              data: data,
              monthName: _monthName,
              year: _selectedYear,
              onTap: (_) => _notImplemented(),
            ),
          ],
        ],
        const SizedBox(height: 32),
        AreaChartCard(
          key: const ValueKey('collection-chart'),
          kind: ChartKind.collection,
        ),
        const SizedBox(height: 24),
        AreaChartCard(
          key: const ValueKey('growth-chart'),
          kind: ChartKind.growth,
          liveCount: data.subscribersStats.active,
        ),
        const SizedBox(height: 32),
        DashboardTableCard(
          key: const ValueKey('recent-payments'),
          title: 'Recent Payments',
          description: 'Latest payments received from subscribers.',
          icon: Icons.account_balance_wallet_outlined,
          iconBackground: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF059669),
          emptyIcon: Icons.schedule,
          emptyText: 'No payments yet',
          onViewAll: _notImplemented,
          headers: const [
            _TableHead('Subscriber', flex: 3),
            _TableHead('Amount (PKR)', flex: 2, alignRight: true),
            _TableHead('Date', flex: 2),
            _TableHead('Method', flex: 2),
          ],
          children: [
            for (final payment in data.payments.take(5))
              PaymentRow(payment: payment),
          ],
        ),
        const SizedBox(height: 24),
        DashboardTableCard(
          key: const ValueKey('open-complaints'),
          title: 'Open Complaints',
          description: 'Tickets that need attention from the support team.',
          icon: Icons.confirmation_num_outlined,
          iconBackground: const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          emptyIcon: Icons.check_circle_outline,
          emptyText: 'No open complaints',
          onViewAll: _notImplemented,
          headers: const [
            _TableHead('Subscriber', flex: 3),
            _TableHead('Category', flex: 2),
            _TableHead('Opened On', flex: 2),
            _TableHead('Status', flex: 2),
          ],
          children: [
            for (final complaint in data.openComplaints.take(5))
              ComplaintRow(complaint: complaint),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(DashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _logo(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_companyName Dashboard',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Here's a real-time overview of your network and business operations.",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: context.mutedFg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _QuickButton(label: 'Drivers', onTap: _notImplemented),
              _QuickButton(
                label: 'Download Application',
                onTap: _notImplemented,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GaugeMeter(
            currentAmount: data.totalCollection,
            targetAmount: _target,
            onTargetSave: _onTargetSave,
          ),
        ),
      ],
    );
  }

  Widget _logo() {
    final cid = Session.companyId;
    return Container(
      width: 60,
      height: 60,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: (cid == null || cid.isEmpty)
          ? _logoFallback()
          : Image.network(
              '${ApiConfig.base}/uploads/company_images/$cid',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _logoFallback(),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: context.surface,
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _logoFallback() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 24),
    );
  }

  Widget _summaryToggle() {
    final visible = _showSummary;
    return GestureDetector(
      onTap: () => setState(() => _showSummary = !visible),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              visible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: context.mutedFg,
            ),
            const SizedBox(width: 6),
            Text(
              visible ? 'Hide Summary' : 'Show Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.calendar_today_outlined, size: 16, color: context.mutedFg),
        Text(
          'For the month of',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.mutedFg,
          ),
        ),
        _SelectorButton(
          width: 120,
          label: _monthName,
          onTap: () => _pickOption(
            title: 'Month',
            options: [
              for (var i = 1; i <= 12; i++)
                (i.toString().padLeft(2, '0'), kMonthNames[i - 1]),
            ],
            selected: _selectedMonth,
            onPicked: (value) => setState(() => _selectedMonth = value),
          ),
        ),
        _SelectorButton(
          width: 92,
          label: _selectedYear,
          onTap: () => _pickOption(
            title: 'Year',
            options: [
              for (var i = 0; i < 7; i++)
                (
                  (DateTime.now().year - 3 + i).toString(),
                  (DateTime.now().year - 3 + i).toString(),
                ),
            ],
            selected: _selectedYear,
            onPicked: (value) => setState(() => _selectedYear = value),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.tv_outlined, size: 16, color: context.mutedFg),
        _SelectorButton(
          width: 124,
          label: _packageType == 'both'
              ? 'All Types'
              : _packageType == 'tv_cable'
              ? 'TV Cable'
              : 'Internet',
          onTap: () => _pickOption(
            title: 'Connection Type',
            options: const [
              ('both', 'All Types'),
              ('tv_cable', 'TV Cable'),
              ('internet', 'Internet'),
            ],
            selected: _packageType,
            onPicked: (value) => setState(() => _packageType = value),
          ),
        ),
      ],
    );
  }

  Future<void> _pickOption({
    required String title,
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onPicked,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final (v, label) = options[i];
                  final isSelected = v == selected;
                  return ListTile(
                    dense: true,
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, v),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) onPicked(value);
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SkeletonBox(height: 90),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: _SkeletonBox(height: 110)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 110)),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 232,
            height: 220,
            decoration: _skeletonDecoration(context),
          ),
        ),
        const SizedBox(height: 24),
        const _SkeletonBox(height: 320),
      ],
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.label, {this.flex = 1, this.alignRight = false});

  final String label;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.mutedFg,
          ),
        ),
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({required this.label, required this.onTap, this.width});

  final String label;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 16, color: context.mutedFg),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF16A34A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _skeletonDecoration(BuildContext context) =>
    BoxDecoration(color: context.line, borderRadius: BorderRadius.circular(12));

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: _skeletonDecoration(context),
    );
  }
}
