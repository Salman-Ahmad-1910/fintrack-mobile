import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/offline_api.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Flutter counterpart of the web `vendor-invoice-form.tsx`. Returns the
/// payload map to POST/PUT, or `null` when cancelled.
class VendorInvoiceFormDialog extends StatefulWidget {
  const VendorInvoiceFormDialog({
    super.key,
    required this.invoice,
    required this.vendors,
    required this.products,
    required this.api,
  });

  final VendorInvoice? invoice;
  final List<Vendor> vendors;
  final List<Product> products;
  final OfflineApi api;

  @override
  State<VendorInvoiceFormDialog> createState() =>
      _VendorInvoiceFormDialogState();
}

class _VendorInvoiceFormDialogState extends State<VendorInvoiceFormDialog> {
  late final List<Product> _products;
  final List<_ViEntry> _entries = [];
  final TextEditingController _batch = TextEditingController();
  final TextEditingController _discount = TextEditingController();

  late String _vendorId;
  String _vendorName = '';
  late String _invoiceDate;

  @override
  void initState() {
    super.initState();
    _products = List.of(widget.products);
    final invoice = widget.invoice;

    if (invoice != null && invoice.items.isNotEmpty) {
      for (final item in invoice.items) {
        _ViEntry? existing;
        for (final entry in _entries) {
          if (entry.productId == item.productId) {
            existing = entry;
            break;
          }
        }
        if (existing != null) {
          existing.quantity += item.quantity;
          existing.addExpanded(item);
        } else {
          _entries.add(
            _ViEntry(
              productId: item.productId,
              productName: item.productName,
              quantity: item.quantity,
              unitPrice:
                  item.purchasePrice != 0 ? item.purchasePrice : item.unitPrice,
              sellingPrice: item.sellingPrice,
              unitType: item.unitType,
              expandedItems: [item],
            ),
          );
        }
      }
    } else {
      _entries.add(_blankEntry());
    }

    _vendorId = invoice?.vendorId ?? '';
    _vendorName = invoice?.vendorName ?? '';
    _batch.text = invoice?.batch ?? '';
    _invoiceDate = (invoice?.invoiceDate.isNotEmpty ?? false)
        ? invoice!.invoiceDate
        : _today();
    _discount.text = _plain(invoice?.discount ?? 0);
  }

  @override
  void dispose() {
    _batch.dispose();
    _discount.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  _ViEntry _blankEntry() => _ViEntry();

  static String _plain(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _today() => DateTime.now().toIso8601String().split('T').first;

  String _vendorNameFor(String id) {
    for (final v in widget.vendors) {
      if (v.id == id) return v.name;
    }
    return '';
  }

  Product? _product(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  num _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  num get _subtotal => _entries.fold<num>(
        0,
        (sum, e) => sum + e.expandedItems.fold<num>(0, (s, i) => s + i.subtotal),
      );

  num get _total {
    final value = _subtotal - _parse(_discount);
    return value < 0 ? 0 : value;
  }

  /// Serial numbers already consumed by the other entries for this product.
  Set<String> _usedSNsByOthers(String productId, int excludeIndex) {
    final used = <String>{};
    for (var i = 0; i < _entries.length; i++) {
      if (i == excludeIndex) continue;
      final entry = _entries[i];
      if (entry.productId != productId) continue;
      for (final item in entry.expandedItems) {
        used.addAll(parseSerialNumbers(item.serialNumber));
      }
    }
    return used;
  }

  List<String> _availableSNs(String productId, int excludeIndex) {
    final product = _product(productId);
    if (product == null) return const [];
    final used = _usedSNsByOthers(productId, excludeIndex);
    return parseSerialNumbers(product.serialNumber)
        .where((sn) => !used.contains(sn))
        .toList();
  }

  List<String> _availableModels(String productId, int excludeIndex) {
    final product = _product(productId);
    if (product == null) return const [];
    final used = <String>{};
    for (var i = 0; i < _entries.length; i++) {
      if (i == excludeIndex) continue;
      final entry = _entries[i];
      if (entry.productId != productId) continue;
      for (final item in entry.expandedItems) {
        used.addAll(parseModels(item.model));
      }
    }
    return parseModels(product.model)
        .where((m) => !used.contains(m))
        .toList();
  }

  void _onProductChanged(int index, String productId) {
    final product = _product(productId);
    if (product == null) return;
    final entry = _entries[index];
    final available = _availableSNs(productId, index);
    final models = _availableModels(productId, index);
    final unitPrice =
        product.purchasePrice != 0 ? product.purchasePrice : product.price;
    final sellingPrice = product.salePrice;
    final qty = available.isNotEmpty
        ? (entry.quantity < 1
            ? 1
            : entry.quantity.toInt().clamp(1, available.length))
        : (entry.quantity < 1 ? 1 : entry.quantity.toInt());
    final selectedSNs = available.take(qty).toList();
    final selectedModels = models.take(qty).toList();
    final snString = selectedSNs.join(', ');
    final modelString = selectedModels.join(', ');

    setState(() {
      entry
        ..productId = productId
        ..productName = product.name
        ..unitType = product.unitType
        ..unitPrice = unitPrice
        ..sellingPrice = sellingPrice
        ..quantity = qty
        ..expandedItems = [
          VendorInvoiceItem(
            productId: productId,
            productName: product.name,
            quantity: qty,
            unitPrice: unitPrice,
            purchasePrice: unitPrice,
            sellingPrice: sellingPrice,
            unitType: product.unitType,
            subtotal: unitPrice * qty,
            serialNumber: snString,
            model: modelString,
          ),
        ];
      entry.syncQtyController();
      entry.syncPriceControllers();
    });
  }

  void _onQuantityChanged(int index, int rawQty) {
    final entry = _entries[index];
    if (entry.productId.isEmpty) return;
    final available = _availableSNs(entry.productId, index);
    final models = _availableModels(entry.productId, index);
    final qty = available.isNotEmpty
        ? rawQty.clamp(1, available.length)
        : (rawQty < 1 ? 1 : rawQty);
    final selectedSNs = available.take(qty).toList();
    final selectedModels = models.take(qty).toList();
    setState(() {
      entry.quantity = qty;
      entry.replaceSingleItem(
        serialNumber: selectedSNs.join(', '),
        model: selectedModels.join(', '),
      );
      if (qty != rawQty) entry.syncQtyController();
    });
  }

  void _onUnitPriceChanged(int index, num value) {
    setState(() => _entries[index].setUnitPrice(value));
  }

  void _onSellingPriceChanged(int index, num value) {
    setState(() => _entries[index].setSellingPrice(value));
  }

  void _addEntry() => setState(() => _entries.add(_blankEntry()));

  void _removeEntry(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
      if (_entries.isEmpty) _entries.add(_blankEntry());
    });
  }

  Future<void> _openAddSNs(int index) async {
    final entry = _entries[index];
    final product = _product(entry.productId);
    if (product == null) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => _AddSerialNumbersDialog(productName: product.name),
    );
    if (raw == null || raw.trim().isEmpty) return;
    final added = parseSerialNumbers(raw);
    if (added.isEmpty) return;

    final existing = parseSerialNumbers(product.serialNumber);
    final combined = [...existing, ...added].join(', ');
    final body = <String, dynamic>{
      'name': product.name,
      'category': product.category,
      'price': product.price,
      'stock': existing.length + added.length,
      'unitType': product.unitType,
      'taxPercent': product.taxPercent,
      'image': product.image,
      'brandId': product.brandId,
      'brandName': product.brandName,
      'productTypeId': product.productTypeId,
      'productTypeName': product.productTypeName,
      'purchasePrice': product.purchasePrice,
      'salePrice': product.salePrice,
      'discount': product.discount,
      'serialNumber': combined,
      'currentSerialIndex': product.currentSerialIndex,
      'model': product.model,
      'currentModelIndex': product.currentModelIndex,
    };
    try {
      await widget.api.put('/inventory/products/${product.id}', body: body);
      if (!mounted) return;
      setState(() {
        final i = _products.indexWhere((p) => p.id == product.id);
        if (i >= 0) {
          _products[i] = Product.fromJson({...body, 'id': product.id});
        }
      });
      showToast(
        context,
        '${added.length} serial number(s) added to ${product.name}',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  void _submit() {
    final allItems = <Map<String, dynamic>>[];
    for (final entry in _entries) {
      if (entry.productId.isEmpty) continue;
      for (final item in entry.expandedItems) {
        allItems.add(_itemJson(item));
      }
    }
    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product with a valid quantity.'),
        ),
      );
      return;
    }
    final vendorName =
        _vendorName.isNotEmpty ? _vendorName : _vendorNameFor(_vendorId);
    Navigator.of(context).pop(<String, dynamic>{
      'vendorId': _vendorId,
      'vendorName': vendorName,
      'invoiceNumber': widget.invoice?.invoiceNumber ?? '',
      'invoiceDate': _invoiceDate,
      'discount': _parse(_discount),
      'totalAmount': _total,
      'batch': _batch.text.trim(),
      'items': allItems,
    });
  }

  static Map<String, dynamic> _itemJson(VendorInvoiceItem item) => {
        if (item.id.isNotEmpty) 'id': item.id,
        if (item.invoiceId.isNotEmpty) 'invoiceId': item.invoiceId,
        'productId': item.productId,
        'productName': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'purchasePrice': item.purchasePrice,
        'sellingPrice': item.sellingPrice,
        'unitType': item.unitType,
        'subtotal': item.subtotal,
        'serialNumber': item.serialNumber,
        'model': item.model,
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      insetPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.invoice != null ? 'Edit Vendor Invoice' : 'Buy a Product',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 780,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 580),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _metaGrid(context),
                const SizedBox(height: 16),
                _productsSection(context),
                const SizedBox(height: 16),
                _totalsSection(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save',
          gradient: invEmeraldButtonGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _metaGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final vendor = InventorySearchDropdown(
          label: 'Vendor *',
          icon: Icons.store_outlined,
          iconColor: const Color(0xFFF59E0B),
          items: widget.vendors
              .map((v) => InventoryOption(id: v.id, name: v.name))
              .toList(),
          value: _vendorId.isEmpty ? null : _vendorId,
          placeholder: 'Search vendor...',
          onChanged: (id) => setState(() {
            _vendorId = id;
            _vendorName = _vendorNameFor(id);
          }),
        );
        final date = NetField(
          label: 'Buying Date *',
          child: _DateField(
            value: _invoiceDate,
            onChanged: (v) => setState(() => _invoiceDate = v),
          ),
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [vendor, const SizedBox(height: 12), date],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: vendor),
            const SizedBox(width: 12),
            Expanded(child: date),
          ],
        );
      },
    );
  }

  Widget _productsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PRODUCT DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                onPressed: _addEntry,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          NetField(
            label: 'Batch',
            child: TextField(
              controller: _batch,
              decoration: netInputDecoration(context, hint: 'e.g., BATCH-001'),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _entryCard(context, i),
          ],
        ],
      ),
    );
  }

  Widget _entryCard(BuildContext context, int index) {
    final entry = _entries[index];
    final available = entry.productId.isEmpty
        ? const <String>[]
        : _availableSNs(entry.productId, index);
    final product = entry.productId.isEmpty ? null : _product(entry.productId);
    final totalSNs =
        product == null ? 0 : parseSerialNumbers(product.serialNumber).length;
    final maxQty = available.length;
    final sns = entry.expandedItems.isNotEmpty
        ? parseSerialNumbers(entry.expandedItems.first.serialNumber)
        : const <String>[];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: TextStyle(fontSize: 13, color: context.mutedFg),
                    ),
                    if (sns.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sns.length == 1
                              ? 'SN: ${sns[0]}'
                              : '${sns[0]} (1/${sns.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                iconSize: 18,
                color: context.mutedFg,
                onPressed: () => _removeEntry(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: InventorySearchDropdown(
                  label: 'Product *',
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF10B981),
                  items: [
                    for (final p in _products)
                      InventoryOption(id: p.id, name: p.name),
                  ],
                  value: entry.productId.isEmpty ? null : entry.productId,
                  placeholder: 'Search product...',
                  onChanged: (id) => _onProductChanged(index, id),
                ),
              ),
              if (entry.productId.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add more serial numbers',
                  iconSize: 18,
                  onPressed: () => _openAddSNs(index),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final fields = <Widget>[
                NetField(
                  label: 'Unit Type',
                  child: _readonlyBox(
                    context,
                    entry.unitType == 'piece'
                        ? 'Per Piece'
                        : entry.unitType == 'meter'
                            ? 'Per Meter'
                            : (entry.unitType.isEmpty
                                ? '\u2014'
                                : entry.unitType),
                  ),
                ),
                NetField(
                  label: maxQty > 0
                      ? 'Quantity * (max $maxQty)'
                      : 'Quantity *',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: entry.qtyController,
                        keyboardType: TextInputType.number,
                        decoration: netInputDecoration(context),
                        onChanged: (v) =>
                            _onQuantityChanged(index, int.tryParse(v) ?? 1),
                      ),
                      if (entry.productId.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          totalSNs > 0
                              ? '${entry.quantity} of $totalSNs SNs will be consumed'
                              : 'No SNs on this product',
                          style: TextStyle(fontSize: 10, color: context.mutedFg),
                        ),
                      ],
                    ],
                  ),
                ),
                NetField(
                  label: 'Purchase Price *',
                  child: TextField(
                    controller: entry.priceController,
                    keyboardType: TextInputType.number,
                    decoration: netInputDecoration(context),
                    onChanged: (v) =>
                        _onUnitPriceChanged(index, double.tryParse(v) ?? 0),
                  ),
                ),
                NetField(
                  label: 'Selling Price *',
                  child: TextField(
                    controller: entry.sellController,
                    keyboardType: TextInputType.number,
                    decoration: netInputDecoration(context),
                    onChanged: (v) =>
                        _onSellingPriceChanged(index, double.tryParse(v) ?? 0),
                  ),
                ),
              ];
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      fields[i],
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields[2]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[3]),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 13)),
                  Text(
                    'PKR ${_formatMoney(entry.expandedItems.fold<num>(0, (s, i) => s + i.subtotal))}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal', style: TextStyle(color: context.mutedFg)),
            Text('PKR ${_formatMoney(_subtotal)}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.percent, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            const Text('Discount'),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                decoration: netInputDecoration(context, hint: '0.00'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Total Amount: PKR ${_formatMoney(_total)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  static String _formatMoney(num v) => v.toStringAsFixed(2);

  Widget _readonlyBox(BuildContext context, String text) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.subtle,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, color: context.fg),
      ),
    );
  }
}

class _ViEntry {
  _ViEntry({
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.sellingPrice = 0,
    this.unitType = 'piece',
    this.expandedItems = const [],
  })  : qtyController = TextEditingController(text: _plainOf(quantity)),
        priceController = TextEditingController(text: _plainOf(unitPrice)),
        sellController = TextEditingController(text: _plainOf(sellingPrice));

  String productId;
  String productName;
  num quantity;
  num unitPrice;
  num sellingPrice;
  String unitType;
  List<VendorInvoiceItem> expandedItems;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final TextEditingController sellController;

  static String _plainOf(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void syncQtyController() => qtyController.text = _plainOf(quantity);

  void syncPriceControllers() {
    priceController.text = _plainOf(unitPrice);
    sellController.text = _plainOf(sellingPrice);
  }

  void addExpanded(VendorInvoiceItem item) {
    expandedItems = [...expandedItems, item];
  }

  void replaceSingleItem({required String serialNumber, required String model}) {
    expandedItems = [
      VendorInvoiceItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        purchasePrice: unitPrice,
        sellingPrice: sellingPrice,
        unitType: unitType,
        subtotal: unitPrice * quantity,
        serialNumber: serialNumber,
        model: model,
      ),
    ];
  }

  void setUnitPrice(num value) {
    unitPrice = value;
    expandedItems = [
      for (final item in expandedItems)
        VendorInvoiceItem(
          id: item.id,
          invoiceId: item.invoiceId,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: value,
          purchasePrice: value,
          sellingPrice: item.sellingPrice,
          unitType: item.unitType,
          subtotal: value * item.quantity,
          serialNumber: item.serialNumber,
          model: item.model,
        ),
    ];
  }

  void setSellingPrice(num value) {
    sellingPrice = value;
    expandedItems = [
      for (final item in expandedItems)
        VendorInvoiceItem(
          id: item.id,
          invoiceId: item.invoiceId,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          purchasePrice: item.purchasePrice,
          sellingPrice: value,
          unitType: item.unitType,
          subtotal: item.subtotal,
          serialNumber: item.serialNumber,
          model: item.model,
        ),
    ];
  }

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
    sellController.dispose();
  }
}

class _AddSerialNumbersDialog extends StatefulWidget {
  const _AddSerialNumbersDialog({required this.productName});

  final String productName;

  @override
  State<_AddSerialNumbersDialog> createState() =>
      _AddSerialNumbersDialogState();
}

class _AddSerialNumbersDialogState extends State<_AddSerialNumbersDialog> {
  final TextEditingController _raw = TextEditingController();

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = parseSerialNumbers(_raw.text).length;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: const [
          Icon(Icons.add_circle_outline, size: 18),
          SizedBox(width: 8),
          Text('Add Serial Numbers', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add new serial numbers to ${widget.productName}. Separate each one with a comma or space.',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _raw,
              maxLines: 4,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: netInputDecoration(
                context,
                hint: 'e.g., SN-1001 SN-1002 SN-1003',
              ),
            ),
            if (count > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$count serial number(s) will be added',
                style: TextStyle(fontSize: 12, color: context.mutedFg),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: count > 0 ? 'Add $count SN(s)' : 'Add SN(s)',
          gradient: invVioletGradient,
          onPressed: count > 0
              ? () => Navigator.of(context).pop(_raw.text)
              : null,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final initial = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().split('T').first);
        }
      },
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(8),
          color: context.inputFill,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'Select date' : value,
                style: TextStyle(
                  fontSize: 14,
                  color: value.isEmpty ? context.mutedFg : context.fg,
                ),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 16, color: context.mutedFg),
          ],
        ),
      ),
    );
  }
}
