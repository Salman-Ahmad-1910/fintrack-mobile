import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';
import 'inventory_print.dart';
import 'vendor_invoice_form.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/inventory/vendor-invoices/page.tsx`.
class VendorInvoicesScreen extends StatefulWidget {
  const VendorInvoicesScreen({super.key});

  @override
  State<VendorInvoicesScreen> createState() => _VendorInvoicesScreenState();
}

class _VendorInvoicesScreenState extends State<VendorInvoicesScreen> {
  static final NumberFormat _money = NumberFormat('#,##0');

  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _search = TextEditingController();
  final Set<String> _expanded = {};

  List<VendorInvoice> _invoices = [];
  List<Vendor> _vendors = [];
  List<Product> _products = [];
  bool _loading = true;
  String _vendorFilter = 'all';
  String _pageSize = '10';
  int _page = 1;

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
    _search.dispose();
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
        _api.get('/inventory/vendor-invoices', query: {'companyId': cid}),
        _api.get('/inventory/vendors', query: {'companyId': cid}),
        _api.get('/inventory/products', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = _list<VendorInvoice>(results[0], VendorInvoice.fromJson);
        _vendors = _list<Vendor>(results[1], Vendor.fromJson);
        _products = _list<Product>(results[2], Product.fromJson);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static List<T> _list<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return ApiClient.listData(envelope)
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }

  List<VendorInvoice> get _filtered {
    var filtered = _invoices;
    final q = _search.text.trim();
    if (q.isNotEmpty) {
      filtered = invSmartSearch(q, filtered, (inv) => [
        [inv.invoiceNumber],
        [inv.vendorName, ...inv.items.map((i) => i.productName)],
      ]);
    }
    if (_vendorFilter != 'all') {
      filtered =
          filtered.where((inv) => inv.vendorId == _vendorFilter).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final flatRows = _flatten(filtered);
    final safePage = _currentPage(flatRows.length);
    final paged = _pagedRows(flatRows, safePage);
    final totalSpent = _invoices.fold<num>(0, (s, v) => s + v.totalAmount);
    final avg =
        _invoices.isEmpty ? 0 : (totalSpent / _invoices.length).round();
    final canCreate = invCrudGlobal('create');
    final canUpdate = invCrudGlobal('update');
    final canDelete = invCrudGlobal('delete');

    return NetworkScrollBody(
      children: [
        const NetworkPageHeader(
          icon: Icons.shopping_cart_outlined,
          title: 'Vendor Invoice',
          subtitle:
              'Manage vendor invoices and track product purchases with serial numbers.',
          gradient: invVendorInvoiceGradient,
        ),
        NetworkStatGrid(
          children: [
            NetworkStatCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Total Invoices',
              value: '${_invoices.length}',
              gradient: invAmberStatGradient,
            ),
            NetworkStatCard(
              icon: Icons.attach_money,
              label: 'Total Spent',
              value: 'PKR ${_money.format(totalSpent)}',
              gradient: invEmeraldStatGradient,
            ),
            NetworkStatCard(
              icon: Icons.receipt_outlined,
              label: 'Avg Per Purchase',
              value: 'PKR ${_money.format(avg)}',
              gradient: invBlueStatGradient,
              valueColor: context.isDark
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF2563EB),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(context, canCreate),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                NetworkTable<_FlatRow>(
                  emptyIcon: Icons.shopping_cart_outlined,
                  emptyTint: const Color(0xFFF59E0B),
                  emptyTitle: 'No vendor invoices found',
                  emptyHint: 'Try adjusting your search.',
                  rows: paged,
                  columns: _columns(context, canUpdate, canDelete),
                  rowKey: (row) => row.invoice.id,
                  rowCanExpand: (row) => row.invoice.items.fold<int>(
                        0,
                        (s, item) =>
                            s + parseSerialNumbers(item.serialNumber).length,
                      ) >
                      1,
                  expandedKeys: _expanded,
                  onToggleExpand: (key) => setState(() {
                    if (!_expanded.remove(key)) _expanded.add(key);
                  }),
                  expansionBuilder: (context, row, _) =>
                      _expansion(context, row.invoice),
                ),
              if (!_loading)
                InvCollectionPagination(
                  total: flatRows.length,
                  pageSize: _pageSize,
                  currentPage: _currentPage(flatRows.length),
                  onPageSizeChanged: (v) => setState(() {
                    _pageSize = v;
                    _page = 1;
                  }),
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, bool canCreate) {
    final search = TextField(
      controller: _search,
      onChanged: (_) => setState(() => _page = 1),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(context, hint: 'Search purchases...')
          .copyWith(
        prefixIcon: Icon(Icons.search, size: 16, color: context.mutedFg),
      ),
    );
    final vendorFilter = InventorySearchDropdown(
      label: 'Vendor',
      icon: Icons.store_outlined,
      iconColor: const Color(0xFFF59E0B),
      items: [
        const InventoryOption(id: 'all', name: 'All'),
        for (final v in _vendors) InventoryOption(id: v.id, name: v.name),
      ],
      value: _vendorFilter,
      placeholder: 'Search vendor...',
      onChanged: (v) => setState(() {
        _vendorFilter = v;
        _page = 1;
      }),
    );
    return InvFilterBar(
      filterWidth: 260,
      filters: [search, vendorFilter],
      actions: [
        if (canCreate)
          GradientButton(
            label: 'Buy a Product',
            icon: Icons.add_circle_outline,
            gradient: invEmeraldButtonGradient,
            onPressed: () => _openForm(null),
          ),
      ],
    );
  }

  int _currentPage(int total) {
    final isAll = _pageSize == 'all';
    final size =
        isAll ? (total < 1 ? 1 : total) : (int.tryParse(_pageSize) ?? 10);
    final totalPages = total == 0 ? 1 : (total / size).ceil();
    return _page.clamp(1, totalPages);
  }

  List<_FlatRow> _pagedRows(List<_FlatRow> rows, int page) {
    if (_pageSize == 'all') return rows;
    final size = int.tryParse(_pageSize) ?? 10;
    return rows.skip((page - 1) * size).take(size).toList();
  }

  List<NetColumn<_FlatRow>> _columns(
    BuildContext context,
    bool canUpdate,
    bool canDelete,
  ) {
    return [
      NetColumn(
        label: '#',
        width: 44,
        builder: (context, row, index) => Text(
          '${index + 1}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: context.mutedFg,
          ),
        ),
      ),
      NetColumn(
        label: 'Vendor',
        width: 140,
        builder: (context, row, _) => Row(
          children: [
            Icon(Icons.business, size: 15, color: context.mutedFg),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                row.isFirst ? row.invoice.vendorName : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      NetColumn(
        label: 'Buying Date',
        width: 130,
        builder: (context, row, _) => Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: context.mutedFg),
            const SizedBox(width: 6),
            Text(
              row.isFirst ? row.invoice.invoiceDate : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      NetColumn(
        label: 'Batch',
        width: 110,
        builder: (context, row, _) => Text(
          row.isFirst
              ? (row.invoice.batch.isEmpty ? '\u2014' : row.invoice.batch)
              : '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Product',
        width: 180,
        builder: (context, row, _) => Text(
          row.item.productName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      NetColumn(
        label: 'SN / MAC',
        width: 140,
        builder: (context, row, _) {
          final sns = parseSerialNumbers(row.item.serialNumber);
          if (sns.isEmpty) {
            return Text('\u2014',
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: context.mutedFg));
          }
          final display =
              sns.length == 1 ? sns[0] : '${sns[0]} (${sns.length}/${sns.length})';
          return Tooltip(
            message: row.item.serialNumber,
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: context.mutedFg),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Model',
        width: 130,
        builder: (context, row, _) {
          final models = parseModels(row.item.model);
          if (models.isEmpty) {
            return Text('\u2014',
                style: TextStyle(fontSize: 12, color: context.mutedFg));
          }
          final display = models.length > 1
              ? '${models[0]} +${models.length - 1}'
              : models[0];
          return Tooltip(
            message: models.join(', '),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.isDark
                    ? const Color(0xFF7DD3FC)
                    : const Color(0xFF0369A1),
              ),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Qty',
        width: 60,
        center: true,
        builder: (context, row, _) => Text(
          _num(row.item.quantity),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      NetColumn(
        label: 'Purchase Price',
        width: 130,
        builder: (context, row, _) {
          if (row.itemCount > 1) {
            return const Text('\u2014');
          }
          final price = row.item.purchasePrice != 0
              ? row.item.purchasePrice
              : row.item.unitPrice;
          return Text(
            'PKR ${price.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
          );
        },
      ),
      NetColumn(
        label: 'Total',
        width: 120,
        builder: (context, row, _) => Text(
          'PKR ${row.item.subtotal.toStringAsFixed(2)}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Invoice Total',
        width: 130,
        builder: (context, row, _) => row.isFirst
            ? Text(
                'PKR ${_money.format(row.invoice.totalAmount)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500),
              )
            : const SizedBox.shrink(),
      ),
      NetColumn(
        label: '',
        width: 56,
        isActions: true,
        builder: (context, row, _) => row.isFirst
            ? _rowMenu(context, row.invoice, canUpdate, canDelete)
            : const SizedBox.shrink(),
      ),
    ];
  }

  Widget _rowMenu(
    BuildContext context,
    VendorInvoice invoice,
    bool canUpdate,
    bool canDelete,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_horiz, size: 20, color: context.mutedFg),
      onSelected: (value) {
        switch (value) {
          case 'print':
            showVendorInvoicePrintDialog(context, invoice, _api);
          case 'edit':
            _openForm(invoice);
          case 'delete':
            _delete(invoice);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'print',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined, size: 18),
            title: Text('Print'),
          ),
        ),
        if (canUpdate)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit'),
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline,
                  size: 18, color: context.dangerText),
              title: const Text('Delete'),
            ),
          ),
      ],
    );
  }

  Widget _expansion(BuildContext context, VendorInvoice invoice) {
    final entries = <InventorySerialEntry>[];
    for (final item in invoice.items) {
      final sns = parseSerialNumbers(item.serialNumber);
      final models = parseModels(item.model);
      for (var i = 0; i < sns.length; i++) {
        entries.add(
          InventorySerialEntry(
            key: '${item.productId}-$i',
            productName: item.productName,
            serialNumber: sns[i],
            model: models.length == 1 ? models[0] : (i < models.length ? models[i] : null),
            price: item.purchasePrice != 0 ? item.purchasePrice : item.unitPrice,
          ),
        );
      }
    }
    return InventorySerialEntriesTable(entries: entries);
  }

  Future<void> _openForm(VendorInvoice? invoice) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VendorInvoiceFormDialog(
        invoice: invoice,
        vendors: _vendors,
        products: _products,
        api: _api,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      if (invoice != null) {
        await _api.put('/inventory/vendor-invoices/${invoice.id}', body: payload);
      } else {
        await _api.post('/inventory/vendor-invoices', body: payload);
      }
      if (!mounted) return;
      showToast(
        context,
        invoice != null
            ? 'Vendor invoice updated successfully'
            : 'Product purchased successfully',
      );
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(VendorInvoice invoice) async {
    await showNetworkDeleteDialog(
      context,
      itemName: invoice.invoiceNumber,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/vendor-invoices/${invoice.id}');
          if (!mounted) return;
          showToast(context, 'Vendor invoice deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  /// One row per invoice (all products consolidated), mirroring
  /// `flattenInvoiceItems` in the web `columns.tsx`.
  List<_FlatRow> _flatten(List<VendorInvoice> invoices) {
    final rows = <_FlatRow>[];
    for (final invoice in invoices) {
      final items = invoice.items;
      if (items.isEmpty) {
        rows.add(
          _FlatRow(
            invoice: invoice,
            item: VendorInvoiceItem(
              productId: '',
              productName: '\u2014',
              quantity: 0,
              unitPrice: 0,
              subtotal: invoice.totalAmount,
            ),
            itemCount: 0,
          ),
        );
        continue;
      }
      final grouped = <String, _Group>{};
      for (final item in items) {
        final group = grouped[item.productId];
        if (group != null) {
          group.quantity += item.quantity;
          group.subtotal += item.subtotal;
          group.serialNumbers.addAll(parseSerialNumbers(item.serialNumber));
          group.models.addAll(parseModels(item.model));
        } else {
          grouped[item.productId] = _Group(
            productName: item.productName,
            serialNumbers: parseSerialNumbers(item.serialNumber),
            models: parseModels(item.model),
          )
            ..quantity = item.quantity
            ..subtotal = item.subtotal;
        }
      }
      final productNames =
          grouped.values.map((g) => g.productName).join(', ');
      final totalQty = grouped.values.fold<num>(0, (s, g) => s + g.quantity);
      final allSNs = grouped.values
          .where((g) => g.serialNumbers.isNotEmpty)
          .expand((g) => g.serialNumbers)
          .join(', ');
      final allModels = grouped.values.expand((g) => g.models).join(', ');
      rows.add(
        _FlatRow(
          invoice: invoice,
          item: VendorInvoiceItem(
            productId: grouped.length == 1 ? grouped.keys.first : '',
            productName: productNames,
            quantity: totalQty,
            unitPrice: 0,
            subtotal: invoice.totalAmount,
            serialNumber: allSNs,
            model: allModels,
          ),
          itemCount: grouped.length,
        ),
      );
    }
    return rows;
  }

  static String _num(num? v) {
    if (v == null) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _FlatRow {
  _FlatRow({
    required this.invoice,
    required this.item,
    required this.itemCount,
  });

  final VendorInvoice invoice;
  final VendorInvoiceItem item;
  final bool isFirst = true;
  final int itemCount;
}

class _Group {
  _Group({
    required this.productName,
    required this.serialNumbers,
    required this.models,
  });

  final String productName;
  num quantity = 0;
  num subtotal = 0;
  final List<String> serialNumbers;
  final List<String> models;
}
