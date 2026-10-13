import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../network/network_models.dart';
import 'connection_form.dart';
import 'crm_common.dart';
import 'crm_models.dart';

const List<Color> _slateGrayGradient = [Color(0xFF64748B), Color(0xFF4B5563)];
const List<Color> _redRoseGradient = [Color(0xFFEF4444), Color(0xFFE11D48)];

/// Flutter counterpart of `client/src/app/(app)/crm/subscriber-detail/page.tsx`
/// — full subscriber connection management.
class SubscriberDetailScreen extends StatefulWidget {
  const SubscriberDetailScreen({super.key});

  @override
  State<SubscriberDetailScreen> createState() => _SubscriberDetailScreenState();
}

class _SubscriberDetailScreenState extends State<SubscriberDetailScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<Conn> _connections = [];
  List<NetArea> _areas = [];
  List<NetBox> _boxes = [];
  List<CrmPackage> _packages = [];
  List<CrmCompany> _companies = [];
  List<NetSplitter> _splitters = [];
  bool _loading = true;

  String _search = '';
  String _filterSublocality = 'all';
  String _filterStatus = 'all';
  String _filterType = 'all';
  String _filterBox = 'all';
  String _filterPackage = 'all';
  String _filterDiscount = 'all';
  String _filterSortBy = 'all';
  String _filterProvider = 'all';

  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

  static void _handleUnauthorized() {
    Session.clear();
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  String? get _cid => Session.companyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/admin/connections', query: {'companyId': cid}),
        _api.get('/network/areas', query: {'companyId': cid}),
        _api.get('/network/boxes', query: {'companyId': cid}),
        _api.get('/billing/packages', query: {'companyId': cid}),
        _api.get('/companies'),
        _api.get('/network/splitters', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _connections = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(Conn.fromJson)
            .toList();
        _areas = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(NetArea.fromJson)
            .toList();
        _boxes = ApiClient.listData(results[2])
            .whereType<Map<String, dynamic>>()
            .map(NetBox.fromJson)
            .toList();
        _packages = ApiClient.listData(results[3])
            .whereType<Map<String, dynamic>>()
            .map(CrmPackage.fromJson)
            .toList();
        _companies = ApiClient.listData(results[4])
            .whereType<Map<String, dynamic>>()
            .map(CrmCompany.fromJson)
            .toList();
        _splitters = ApiClient.listData(results[5])
            .whereType<Map<String, dynamic>>()
            .map(NetSplitter.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Conn> get _filtered {
    var result = _connections;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((c) {
        final text = [
          c.name,
          c.address,
        ].any((v) => v.toLowerCase().contains(q));
        final id = [
          c.internetId,
          c.cell,
          c.mobile,
        ].any((v) => v.toLowerCase().contains(q));
        return text || id;
      }).toList();
    }
    if (_filterSublocality != 'all') {
      result = result
          .where((c) => c.sublocalityId == _filterSublocality)
          .toList();
    }
    if (_filterStatus != 'all') {
      result = result.where((c) => c.status == _filterStatus).toList();
    }
    if (_filterType != 'all') {
      const typeMap = {
        'both': 'both',
        'tv_cable': 'tv_cable',
        'internet': 'internet',
        'cable_all': 'tv_cable',
        'internet_all': 'internet',
      };
      final mapped = typeMap[_filterType] ?? _filterType;
      result = result.where((c) => c.connectionType == mapped).toList();
    }
    if (_filterBox != 'all') {
      result = result.where((c) => c.boxNumber == _filterBox).toList();
    }
    if (_filterPackage != 'all') {
      result = result
          .where(
            (c) =>
                c.packageInternet == _filterPackage ||
                c.packageCable == _filterPackage,
          )
          .toList();
    }
    if (_filterDiscount != 'all') {
      result = result
          .where(
            (c) =>
                c.discount == _filterDiscount ||
                (_filterDiscount == 'no_discount' && c.discount.isEmpty),
          )
          .toList();
    }
    if (_filterProvider != 'all') {
      result = result
          .where((c) => c.connectionProvider == _filterProvider)
          .toList();
    }

    if (_filterSortBy == 'name') {
      result = [...result]..sort((a, b) => a.name.compareTo(b.name));
    } else if (_filterSortBy == 'internetId') {
      result = [...result]
        ..sort((a, b) => a.internetId.compareTo(b.internetId));
    } else if (_filterSortBy == 'installationDate') {
      result = [...result]
        ..sort((a, b) => a.installationDate.compareTo(b.installationDate));
    }
    return result;
  }

  List<Conn> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  void _resetPage() => _page = 1;

  Future<void> _save(Map<String, dynamic> values, Conn? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/admin/connections/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/admin/connections?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
      }
      await _load();
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Success',
          message: existing != null
              ? 'Subscriber updated successfully.'
              : 'Subscriber added successfully.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'error',
          title: 'Error',
          message: e.message,
        );
      }
    }
  }

  Future<void> _delete(Conn connection) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: connection.name,
      onConfirm: () async {
        try {
          await _api.delete(
            '/admin/connections/${connection.id}?companyId=$cid',
          );
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Subscriber deleted successfully.',
            );
          }
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'error',
              title: 'Error',
              message: e.message,
            );
          }
        }
      },
    );
  }

  Future<void> _deactivate(Conn connection) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    final result = await showDialog<_DeactivateResult>(
      context: context,
      builder: (_) => _DeactivateDialog(connection: connection),
    );
    if (result == null) return;
    try {
      await _api.put(
        '/admin/connections/${connection.id}?companyId=$cid',
        body: {
          'status': 'deactivated',
          'deactivationReason': result.reason,
          'comments': result.comments,
          'leavingDate': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _load();
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Success',
          message: 'Subscriber deactivated successfully.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'error',
          title: 'Error',
          message: e.message,
        );
      }
    }
  }

  Future<void> _openForm(Conn? connection) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ConnectionFormDialog(
        connection: connection,
        areas: _areas,
        boxes: _boxes,
        packages: _packages,
        companies: _companies,
        splitters: _splitters,
      ),
    );
    if (result != null) await _save(result, connection);
  }

  Future<void> _openImportExport() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ImportExportDialog(
        connections: _connections,
        areas: _areas,
        api: _api,
        companyId: _cid,
        onImported: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    final active = _connections.where((c) => c.status == 'active').length;
    final inactive = _connections.where((c) => c.status == 'inactive').length;
    final deactivated = _connections
        .where((c) => c.status == 'deactivated')
        .length;
    final suspended = _connections.where((c) => c.status == 'suspended').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.people_outline,
            title: 'Subscriber Detail',
            subtitle: 'Manage subscriber connections and details.',
            gradient: crmBlueGradient,
          ),
          if (cid == null || cid.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Please select a company to manage subscribers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedFg),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NetworkStatGrid(
                      maxColumns: 5,
                      children: [
                        NetworkStatCard(
                          icon: Icons.people_outline,
                          label: 'Total',
                          value: '${_connections.length}',
                          gradient: crmBlueGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.wifi,
                          label: 'Active',
                          value: '$active',
                          gradient: crmGreenGradient,
                          valueColor: crmStatusActive,
                        ),
                        NetworkStatCard(
                          icon: Icons.wifi_off,
                          label: 'Inactive',
                          value: '$inactive',
                          gradient: _slateGrayGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.person_off_outlined,
                          label: 'Deactivated',
                          value: '$deactivated',
                          gradient: _redRoseGradient,
                          valueColor: crmStatusDeactivated,
                        ),
                        NetworkStatCard(
                          icon: Icons.pause_circle_outline,
                          label: 'Suspended',
                          value: '$suspended',
                          gradient: crmAmberGradient,
                          valueColor: crmStatusSuspended,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _filters(context),
                    const SizedBox(height: 16),
                    _searchRow(context),
                    const SizedBox(height: 16),
                    NetworkTable<Conn>(
                      rows: _pageRows,
                      emptyIcon: Icons.people_outline,
                      emptyTitle: 'No subscribers found.',
                      emptyHint: 'Get started by adding a new subscriber.',
                      emptyTint: AppColors.primary,
                      mobileTrailing: (context, c, _) => _rowMenu(context, c),
                      columns: [
                        NetColumn(
                          label: 'Internet ID',
                          width: 120,
                          builder: (context, c, _) => Text(c.internetId),
                        ),
                        NetColumn(
                          label: 'Name',
                          width: 160,
                          builder: (context, c, _) => Text(c.name),
                        ),
                        NetColumn(
                          label: 'Address',
                          width: 200,
                          builder: (context, c, _) => Text(
                            c.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        NetColumn(
                          label: 'Contact',
                          width: 140,
                          builder: (context, c, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.cell.isNotEmpty) Text(c.cell),
                              if (c.mobile.isNotEmpty)
                                Text(
                                  c.mobile,
                                  style: TextStyle(color: context.mutedFg),
                                ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Type',
                          width: 100,
                          builder: (context, c, _) =>
                              Text(connTypeLabel(c.connectionType)),
                        ),
                        NetColumn(
                          label: 'Install Date',
                          width: 120,
                          builder: (context, c, _) => Text(c.installationDate),
                        ),
                        NetColumn(
                          label: 'Cable / Internet',
                          width: 160,
                          builder: (context, c, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.packageCable.isNotEmpty)
                                Text('C: ${c.packageCable}'),
                              if (c.packageInternet.isNotEmpty)
                                Text('I: ${c.packageInternet}'),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Status',
                          width: 110,
                          builder: (context, c, _) => Text(
                            _titleCase(c.status),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: connStatusColor(c.status),
                            ),
                          ),
                        ),
                        NetColumn(
                          label: '',
                          width: 56,
                          isActions: true,
                          builder: (context, c, _) => Align(
                            alignment: Alignment.centerRight,
                            child: _rowMenu(context, c),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'entries',
                      pageSizes: const [10, 50, 100],
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rowMenu(BuildContext context, Conn c) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 20, color: context.mutedFg),
      tooltip: 'Open menu',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openForm(c);
          case 'deactivate':
            _deactivate(c);
          case 'delete':
            _delete(c);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('Edit subscriber'),
            ],
          ),
        ),
        if (c.status != 'deactivated')
          const PopupMenuItem(
            value: 'deactivate',
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline, size: 16),
                SizedBox(width: 8),
                Text('Deactivate subscriber'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: context.dangerText),
              const SizedBox(width: 8),
              Text(
                'Delete subscriber',
                style: TextStyle(color: context.dangerText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filter(
          width: 170,
          value: _filterSublocality,
          items: {
            'all': 'All Sublocality',
            for (final a in _areas)
              a.id: a.subLocality.isNotEmpty
                  ? a.subLocality
                  : (a.locality.isNotEmpty
                        ? a.locality
                        : a.id.substring(
                            0,
                            a.id.length >= 8 ? 8 : a.id.length,
                          )),
          },
          onChanged: (v) => setState(() {
            _filterSublocality = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 130,
          value: _filterStatus,
          items: const {
            'all': 'All',
            'active': 'Active',
            'inactive': 'Inactive',
          },
          onChanged: (v) => setState(() {
            _filterStatus = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 140,
          value: _filterType,
          items: const {
            'all': 'All',
            'both': 'Both',
            'tv_cable': 'TV Cable',
            'cable_all': 'Cable All',
            'internet': 'Internet',
            'internet_all': 'Internet All',
          },
          onChanged: (v) => setState(() {
            _filterType = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 160,
          value: _filterBox,
          items: {'all': 'All Boxes', for (final b in _boxes) b.name: b.name},
          onChanged: (v) => setState(() {
            _filterBox = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 150,
          value: _filterPackage,
          items: {
            'all': 'All Packages',
            for (final p in _packages) p.name: p.name,
          },
          onChanged: (v) => setState(() {
            _filterPackage = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 140,
          value: _filterDiscount,
          items: const {
            'all': 'All Discounts',
            'no_discount': 'No Discount',
            'quarter': 'Quarter',
            'half': 'Half',
            'full_free': 'Full Free',
            'custom': 'Custom',
          },
          onChanged: (v) => setState(() {
            _filterDiscount = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 130,
          value: _filterSortBy,
          items: const {
            'all': 'Default',
            'name': 'Name',
            'internetId': 'Internet ID',
            'installationDate': 'Install Date',
          },
          onChanged: (v) => setState(() {
            _filterSortBy = v;
            _resetPage();
          }),
        ),
        _filter(
          width: 170,
          value: _filterProvider,
          items: {
            'all': 'All Providers',
            for (final c in _companies) c.name: c.name,
          },
          onChanged: (v) => setState(() {
            _filterProvider = v;
            _resetPage();
          }),
        ),
      ],
    );
  }

  Widget _filter({
    required double width,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: netInputDecoration(context),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _searchRow(BuildContext context) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() {
        _search = v;
        _resetPage();
      }),
      style: const TextStyle(fontSize: 14),
      decoration:
          netInputDecoration(
            context,
            hint: 'Search by name, ID, address, or contact...',
          ).copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    final importExport = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: const Color(0xFF047857),
        side: const BorderSide(color: Color(0xFFA7F3D0)),
      ),
      onPressed: _openImportExport,
      icon: const Icon(Icons.grid_on, size: 16),
      label: const Text('Import/Export'),
    );
    final add = GradientButton(
      label: 'Add Subscriber',
      icon: Icons.add_circle_outline,
      gradient: crmGreenGradient,
      onPressed: () => _openForm(null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              importExport,
              const SizedBox(width: 12),
              add,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: importExport),
                const SizedBox(width: 10),
                Flexible(child: add),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _DeactivateResult {
  const _DeactivateResult(this.reason, this.comments);
  final String reason;
  final String comments;
}

class _DeactivateDialog extends StatefulWidget {
  const _DeactivateDialog({required this.connection});

  final Conn connection;

  @override
  State<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<_DeactivateDialog> {
  static const List<MapEntry<String, String>> _reasons = [
    MapEntry('voluntary', 'Voluntary'),
    MapEntry('non-payment', 'Non-Payment'),
    MapEntry('relocation', 'Relocation'),
    MapEntry('switched_provider', 'Switched Provider'),
    MapEntry('service_issues', 'Service Issues'),
    MapEntry('financial', 'Financial Reasons'),
    MapEntry('other', 'Other'),
  ];

  String? _reason;
  final TextEditingController _comments = TextEditingController();

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Deactivate Subscriber'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.subtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${widget.connection.name}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Internet ID: ${widget.connection.internetId}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NetField(
              label: 'Reason for Leaving *',
              child: DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: netInputDecoration(context),
                hint: const Text('Select reason'),
                items: [
                  for (final r in _reasons)
                    DropdownMenuItem(value: r.key, child: Text(r.value)),
                ],
                onChanged: (v) => setState(() => _reason = v),
              ),
            ),
            const SizedBox(height: 14),
            NetField(
              label: 'Comments',
              child: TextField(
                controller: _comments,
                maxLines: 3,
                decoration: netInputDecoration(
                  context,
                  hint: 'Enter any additional comments...',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            backgroundColor: context.dangerText,
          ),
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context)
                    .pop(_DeactivateResult(_reason!, _comments.text.trim())),
          child: const Text('Deactivate'),
        ),
      ],
    );
  }
}

class _ImportExportDialog extends StatefulWidget {
  const _ImportExportDialog({
    required this.connections,
    required this.areas,
    required this.api,
    required this.companyId,
    required this.onImported,
  });

  final List<Conn> connections;
  final List<NetArea> areas;
  final ApiClient api;
  final String? companyId;
  final Future<void> Function() onImported;

  @override
  State<_ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<_ImportExportDialog> {
  static const List<String> _templateHeaders = [
    'Internet ID*',
    'Name*',
    'Address',
    'Cell',
    'Mobile',
    'Sublocality',
    'Connection Provider',
    'Connection Type',
    'Box Number',
    'Package Cable',
    'Cable Discount',
    'Cable Amount',
    'Package Internet',
    'Internet Discount',
    'Internet Amount',
    'Installation Amount',
    'Other Amount',
    'Installation Date',
    'Recharge Date',
    'Status',
  ];

  static const List<String> _exampleRow = [
    'INT-001',
    'Ahmed Khan',
    'House 123, Street 5',
    '0300-1234567',
    '0312-7654321',
    'DHA Phase 5',
    'My ISP',
    'both',
    'BOX-01',
    'Basic Cable',
    'no_discount',
    '1500',
    'Basic Internet',
    'no_discount',
    '2000',
    '5000',
    '1000',
    '2026-01-15',
    '2026-01-15',
    'active',
  ];

  int _tab = 0;
  PlatformFile? _pickedFile;
  bool _importing = false;
  _ImportResult? _result;

  String? get _fileName => _pickedFile?.name;

  Future<void> _export() async {
    final rows = <List<String>>[
      [
        '#',
        'Internet ID',
        'Name',
        'Address',
        'Cell',
        'Mobile',
        'Sublocality',
        'Connection Provider',
        'Connection Type',
        'Box Number',
        'Package Cable',
        'Cable Discount',
        'Cable Amount',
        'Package Internet',
        'Internet Discount',
        'Internet Amount',
        'Installation Amount',
        'Other Amount',
        'Installation Date',
        'Recharge Date',
        'Status',
      ],
      for (var i = 0; i < widget.connections.length; i++)
        _exportRow(widget.connections[i], i + 1),
    ];
    final csv = rows.map(_csvLine).join('\r\n');
    await _writeCsv('subscribers_export_${_today()}.csv', csv);
    if (mounted) {
      await showCrmFeedback(
        context,
        type: 'success',
        title: 'Export complete',
        message: 'Exported ${widget.connections.length} subscribers.',
      );
    }
  }

  Future<void> _downloadTemplate() async {
    final rows = <List<String>>[_templateHeaders, _exampleRow];
    final csv = rows.map(_csvLine).join('\r\n');
    await _writeCsv('subscriber_import_template.csv', csv);
    if (mounted) {
      await showCrmFeedback(
        context,
        type: 'success',
        title: 'Template downloaded',
        message: 'Fill in the template and upload it back.',
      );
    }
  }

  Future<void> _writeCsv(String name, String content) async {
    // Bytes are mandatory on Android/iOS (the plugin writes the file).
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $name',
      fileName: name,
      bytes: utf8.encode(content),
    );
    if (path == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsString(content);
    }
  }

  List<String> _exportRow(Conn c, int index) {
    String areaName = '';
    for (final a in widget.areas) {
      if (a.id == c.sublocalityId) {
        areaName = a.subLocality.isNotEmpty ? a.subLocality : a.locality;
        break;
      }
    }
    return [
      '$index',
      c.internetId,
      c.name,
      c.address,
      c.cell,
      c.mobile,
      areaName,
      c.connectionProvider,
      c.connectionType,
      c.boxNumber,
      c.packageCable,
      c.discount,
      '${c.amount}',
      c.packageInternet,
      c.sameDiscount,
      '${c.sameAmount}',
      '${c.installationAmount}',
      '${c.otherAmount}',
      c.installationDate,
      c.rechargeDate,
      c.status,
    ];
  }

  String _csvLine(List<String> cells) => cells.map(_csvCell).join(',');

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() {
      _pickedFile = picked.files.first;
      _result = null;
    });
  }

  Future<void> _import() async {
    final cid = widget.companyId;
    final file = _pickedFile;
    if (cid == null || cid.isEmpty || file == null) return;
    setState(() {
      _importing = true;
      _result = null;
    });

    int success = 0;
    int failed = 0;
    final errors = <String>[];
    try {
      final content = file.path != null
          ? await File(file.path!).readAsString()
          : utf8.decode(file.bytes ?? const []);
      final rows = _parseCsv(content);
      if (rows.length <= 1) {
        setState(() => _importing = false);
        if (mounted) {
          await showCrmFeedback(
            context,
            type: 'error',
            title: 'Empty file',
            message: 'The uploaded file contains no data rows.',
          );
        }
        return;
      }

      final headers = rows.first;
      bool hasInternetId = headers.any((h) => h.contains('Internet ID'));
      bool hasName = headers.any((h) => h.contains('Name'));
      if (!hasInternetId || !hasName) {
        setState(() => _importing = false);
        if (mounted) {
          await showCrmFeedback(
            context,
            type: 'error',
            title: 'Invalid template',
            message:
                'File must have "Internet ID*" and "Name*" columns. '
                'Please download the template first.',
          );
        }
        return;
      }

      String cellAt(List<String> row, String exact) {
        for (var i = 0; i < headers.length; i++) {
          if (headers[i] == exact) return i < row.length ? row[i].trim() : '';
        }
        return '';
      }

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final rowNum = i + 1;
        final internetId = _containsValue(row, headers, 'Internet ID');
        final name = _exactValue(row, headers, 'Name');
        if (internetId.isEmpty || name.isEmpty) {
          failed++;
          errors.add(
            'Row $rowNum: Missing required fields (Internet ID or Name)',
          );
          continue;
        }
        final sublocalityName = cellAt(row, 'Sublocality');
        var sublocalityId = '';
        for (final a in widget.areas) {
          if (_eq(a.subLocality, sublocalityName) ||
              _eq(a.locality, sublocalityName)) {
            sublocalityId = a.id;
            break;
          }
        }
        final connectionType = cellAt(row, 'Connection Type');
        final status = cellAt(row, 'Status');
        final payload = <String, dynamic>{
          'internetId': internetId,
          'name': name,
          'address': cellAt(row, 'Address'),
          'cell': cellAt(row, 'Cell'),
          'mobile': cellAt(row, 'Mobile'),
          'sublocalityId': sublocalityId,
          'connectionProvider': cellAt(row, 'Connection Provider'),
          'connectionType':
              const ['both', 'internet', 'tv_cable'].contains(connectionType)
              ? connectionType
              : 'both',
          'boxNumber': cellAt(row, 'Box Number'),
          'packageCable': cellAt(row, 'Package Cable'),
          'discount': cellAt(row, 'Cable Discount'),
          'amount': double.tryParse(cellAt(row, 'Cable Amount')) ?? 0,
          'packageInternet': cellAt(row, 'Package Internet'),
          'sameDiscount': cellAt(row, 'Internet Discount'),
          'sameAmount': double.tryParse(cellAt(row, 'Internet Amount')) ?? 0,
          'installationAmount':
              double.tryParse(cellAt(row, 'Installation Amount')) ?? 0,
          'otherAmount': double.tryParse(cellAt(row, 'Other Amount')) ?? 0,
          'installationDate': cellAt(row, 'Installation Date'),
          'rechargeDate': cellAt(row, 'Recharge Date'),
          'status':
              const [
                'active',
                'inactive',
                'deactivated',
                'suspended',
              ].contains(status)
              ? status
              : 'active',
          'companyId': cid,
        };
        try {
          await widget.api.post(
            '/admin/connections?companyId=$cid',
            body: payload,
          );
          success++;
        } on ApiException catch (e) {
          failed++;
          errors.add('Row $rowNum ($internetId): ${e.message}');
        }
      }

      setState(() {
        _importing = false;
        _result = _ImportResult(success, failed, errors);
      });
      await widget.onImported();
      if (mounted && success > 0) {
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Import complete',
          message: '$success subscribers imported successfully.',
        );
      }
    } catch (_) {
      setState(() => _importing = false);
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'error',
          title: 'Parse error',
          message:
              'Could not read the file. Please ensure it is a valid CSV file.',
        );
      }
    }
  }

  static String _exactValue(
    List<String> row,
    List<String> headers,
    String label,
  ) {
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h == label || h == '$label*') {
        return i < row.length ? row[i].trim() : '';
      }
    }
    return '';
  }

  static String _containsValue(
    List<String> row,
    List<String> headers,
    String needle,
  ) {
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].contains(needle)) {
        return i < row.length ? row[i].trim() : '';
      }
    }
    return '';
  }

  static bool _eq(String a, String b) => a.toLowerCase() == b.toLowerCase();

  static String _today() => DateTime.now().toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          const Icon(Icons.grid_on, size: 20, color: Color(0xFF047857)),
          const SizedBox(width: 8),
          const Text('Subscriber Import and Export'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export existing subscribers or import new subscribers from a CSV file',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: context.subtle,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _tabButton('Export Subscribers', 0),
                  _tabButton('Import Subscribers', 1),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_tab == 0) _exportTab(context) else _importTab(context),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? context.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? context.fg : context.mutedFg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _exportTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Export Subscribers',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Export all subscribers of your company to a CSV file',
          style: TextStyle(fontSize: 13, color: context.mutedFg),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.subtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${widget.connections.length} subscriber(s) will be exported.',
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: GradientButton(
            label: 'Export CSV',
            icon: Icons.download,
            gradient: crmGreenGradient,
            onPressed: _export,
          ),
        ),
      ],
    );
  }

  Widget _importTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Subscribers',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Import subscribers from a CSV file',
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download, size: 15),
              label: const Text('Download Template'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _importing ? null : _pickFile,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.line,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _fileName == null
                      ? Icons.upload_file
                      : Icons.description_outlined,
                  size: 40,
                  color: _fileName == null
                      ? context.mutedFg
                      : const Color(0xFF047857),
                ),
                const SizedBox(height: 8),
                Text(
                  _fileName ?? 'Drop your CSV file here or browse',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supports .csv files',
                  style: TextStyle(fontSize: 12, color: context.mutedFg),
                ),
              ],
            ),
          ),
        ),
        if (_fileName != null && _result == null) ...[
          const SizedBox(height: 14),
          GradientButton(
            label: _importing ? 'Importing...' : 'Import Subscribers',
            icon: Icons.upload,
            gradient: crmGreenGradient,
            loading: _importing,
            onPressed: _importing ? null : _import,
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _result!.failed > 0
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _result!.failed > 0
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFF6EE7B7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_result!.success} imported, ${_result!.failed} failed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_result!.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final err in _result!.errors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                err,
                                style: const TextStyle(fontSize: 11),
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
      ],
    );
  }

  /// Minimal RFC-4180 CSV parser (handles quoted fields and escaped quotes).
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          row.add(field.toString());
          field.clear();
        } else if (ch == '\n') {
          row.add(field.toString());
          field.clear();
          rows.add(row);
          row = <String>[];
        } else if (ch == '\r') {
          // Skip; handled with '\n'.
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  }
}

class _ImportResult {
  const _ImportResult(this.success, this.failed, this.errors);
  final int success;
  final int failed;
  final List<String> errors;
}
