import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Flutter counterpart of the web `purchase-form.tsx`. Returns the payload map
/// to POST/PUT, or `null` when cancelled.
class PurchaseFormDialog extends StatefulWidget {
  const PurchaseFormDialog({
    super.key,
    required this.purchase,
    required this.vendors,
    required this.products,
    required this.purchases,
    required this.vendorInvoices,
  });

  final Purchase? purchase;
  final List<Vendor> vendors;
  final List<Product> products;
  final List<Purchase> purchases;
  final List<VendorInvoice> vendorInvoices;

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  late final TextEditingController _billId;
  final TextEditingController _batch = TextEditingController();
  final TextEditingController _discount = TextEditingController();
  final TextEditingController _salesTax = TextEditingController();
  final TextEditingController _wthTax = TextEditingController();

  late String _vendorId;
  String _vendorName = '';
  late String _purchaseDate;
  String _status = 'unpaid';
  final List<_ItemDraft> _items = [];
  final List<_ItemDraft> _removed = [];

  @override
  void initState() {
    super.initState();
    final purchase = widget.purchase;
    _vendorId = purchase?.vendorId ?? '';
    _billId = TextEditingController(text: purchase?.billId ?? '');
    _batch.text = purchase?.batch ?? '';
    _purchaseDate = purchase?.purchaseDate.isNotEmpty == true
        ? purchase!.purchaseDate
        : _today();
    _discount.text = _plain(purchase?.discount ?? 0);
    _salesTax.text = _plain(purchase?.salesTax ?? 0);
    _wthTax.text = _plain(purchase?.wthTax ?? 0);
    _status = purchase?.status ?? 'unpaid';
    for (final item in purchase?.items ?? const <PurchaseItem>[]) {
      _items.add(
        _ItemDraft(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantityEntered > 0 ? item.quantityEntered : item.quantity,
          purchasePrice: item.purchasePrice,
          sellingPrice: item.sellingPrice,
          unitType: item.unitType,
          focNormal: item.focNormal,
          serialNumber: item.serialNumber,
          model: item.model,
          saleTax: item.saleTax,
          wthTax: item.wthTax,
          disc: item.disc,
          expiryDate: item.expiryDate,
        ),
      );
    }
  }

  @override
  void dispose() {
    _billId.dispose();
    _batch.dispose();
    _discount.dispose();
    _salesTax.dispose();
    _wthTax.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final item in _removed) {
      item.dispose();
    }
    super.dispose();
  }

  static String _plain(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _today() =>
      DateTime.now().toIso8601String().split('T').first;

  String _vendorNameFor(String id) {
    for (final v in widget.vendors) {
      if (v.id == id) return v.name;
    }
    return '';
  }

  num _parse(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  num get _itemsSubtotal =>
      _items.fold<num>(0, (sum, item) => sum + item.subtotal);

  num get _total =>
      _itemsSubtotal - _parse(_discount) + _parse(_salesTax) + _parse(_wthTax);

  Set<String> get _usedSNsByOtherPurchases {
    final used = <String>{};
    for (final purchase in widget.purchases) {
      if (widget.purchase != null && purchase.id == widget.purchase!.id) {
        continue;
      }
      for (final item in purchase.items) {
        used.addAll(parseSerialNumbers(item.serialNumber));
      }
    }
    return used;
  }

  List<_VendorProduct> _vendorProducts() {
    if (_vendorId.isEmpty) return const [];
    final used = _usedSNsByOtherPurchases;
    final map = <String, _VendorProduct>{};
    for (final vi in widget.vendorInvoices) {
      if (vi.vendorId != _vendorId) continue;
      for (final item in vi.items) {
        final itemSNs = parseSerialNumbers(item.serialNumber);
        final itemModels = parseModels(item.model);
        final Product? product = _findProduct(item.productId);
        final isNoSN =
            (product?.noSerialNumber ?? false) || itemSNs.isEmpty;

        final unconsumedSNs = <String>[];
        final unconsumedModels = <String>[];
        for (var i = 0; i < itemSNs.length; i++) {
          if (!used.contains(itemSNs[i])) {
            unconsumedSNs.add(itemSNs[i]);
            unconsumedModels.add(i < itemModels.length ? itemModels[i] : '');
          }
        }

        final existing = map[item.productId];
        if (existing != null) {
          if (!isNoSN) {
            existing.allSNs.addAll(unconsumedSNs);
            existing.allModels.addAll(unconsumedModels);
            existing.allVendorSNs.addAll(itemSNs);
            existing.allVendorModels.addAll(itemModels);
          }
        } else {
          final unitPrice = item.purchasePrice != 0
              ? item.purchasePrice
              : (item.unitPrice != 0 ? item.unitPrice : 0);
          map[item.productId] = _VendorProduct(
            productId: item.productId,
            productName: item.productName,
            unitPrice: unitPrice,
            sellingPrice: item.sellingPrice != 0 ? item.sellingPrice : unitPrice,
            unitType: item.unitType.isNotEmpty
                ? item.unitType
                : (product?.unitType ?? 'piece'),
            allSNs: isNoSN ? <String>[] : List.of(unconsumedSNs),
            allModels: isNoSN ? <String>[] : List.of(unconsumedModels),
            allVendorSNs: isNoSN ? <String>[] : List.of(itemSNs),
            allVendorModels: isNoSN ? <String>[] : List.of(itemModels),
            noSerial: isNoSN,
            invoiceNumber: vi.invoiceNumber,
            batch: vi.batch,
          );
        }
      }
    }
    return map.values.toList();
  }

  Product? _findProduct(String id) {
    for (final p in widget.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _modelForSn(String productId, String sn) {
    for (final vp in _vendorProducts()) {
      if (vp.productId != productId) continue;
      final i = vp.allSNs.indexOf(sn);
      if (i >= 0 && i < vp.allModels.length) return vp.allModels[i];
      final j = vp.allVendorSNs.indexOf(sn);
      if (j >= 0 && j < vp.allVendorModels.length) return vp.allVendorModels[j];
    }
    return '';
  }

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
                colors: [Color(0xFF8B5CF6), Color(0xFF9333EA)],
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
              widget.purchase != null
                  ? 'Edit Purchase: ${widget.purchase!.purchaseNumber}'
                  : 'Add New Purchase',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
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
          label: widget.purchase != null ? 'Update' : 'Add Purchase',
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
        final fields = <Widget>[
          InventorySearchDropdown(
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
          ),
          NetField(
            label: 'Bill ID',
            child: TextField(
              controller: _billId,
              decoration: netInputDecoration(context, hint: 'e.g., BILL-001'),
            ),
          ),
          NetField(
            label: 'Batch',
            child: TextField(
              controller: _batch,
              decoration: netInputDecoration(context, hint: 'e.g., BATCH-001'),
            ),
          ),
          NetField(
            label: 'Date *',
            child: _DateField(
              value: _purchaseDate,
              onChanged: (v) => setState(() => _purchaseDate = v),
            ),
          ),
        ];
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
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
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: fields[2]),
                const SizedBox(width: 12),
                Expanded(child: fields[3]),
              ],
            ),
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
          const Text('Products',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (_vendorId.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Select a vendor first to add products.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.mutedFg),
              ),
            )
          else if (_vendorProducts().isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No vendor invoices found for this vendor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.mutedFg),
              ),
            )
          else
            InventorySearchDropdown(
              label: 'Product',
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF10B981),
              items: _vendorProducts()
                  .map((vp) => InventoryOption(id: vp.productId, name: vp.productName))
                  .toList(),
              value: null,
              placeholder: 'Select a product to add...',
              onChanged: _addItem,
            ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _itemCard(context, i),
            ],
          ],
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, int index) {
    final item = _items[index];
    final sns = parseSerialNumbers(item.serialNumber);
    final models = parseModels(item.model);
    final vp = _vendorProducts()
        .where((p) => p.productId == item.productId)
        .toList();
    final totalSNs = vp.isEmpty ? 0 : vp.first.allSNs.length;
    final isNoSN = vp.isEmpty || vp.first.allSNs.isEmpty;
    final available = _getAvailableSNs(item.productId, index);
    final maxQty = isNoSN ? 99999 : (available.isEmpty ? 1 : available.length);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (sns.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _chip(
                        context,
                        sns.length == 1
                            ? 'SN: ${sns[0]}'
                            : '${sns[0]} (1/${sns.length})',
                        const Color(0xFFD1FAE5),
                        const Color(0xFF047857),
                      ),
                    ],
                    if (models.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _chip(
                        context,
                        models.length == 1
                            ? 'Model: ${models[0]}'
                            : 'Model: ${models[0]} (1/${models.length})',
                        const Color(0xFFEDE9FE),
                        const Color(0xFF6D28D9),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _removed.add(_items.removeAt(index));
                }),
                child: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 460;
              final selling = NetField(
                label: 'Selling Price (from vendor invoice)',
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(
                      text: _plain(item.sellingPrice)),
                  decoration: netInputDecoration(context),
                ),
              );
              final quantity = NetField(
                label: isNoSN
                    ? 'Quantity *'
                    : 'Quantity * (max $maxQty)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: item.qtyController,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                      onChanged: (v) => _updateQuantity(
                          index, int.tryParse(v.trim()) ?? 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalSNs > 0
                          ? '${_plain(item.quantity)} of $totalSNs SNs assigned'
                          : 'No SNs on this product',
                      style: TextStyle(fontSize: 10, color: context.mutedFg),
                    ),
                  ],
                ),
              );
              if (!wide) {
                return Column(
                  children: [selling, const SizedBox(height: 10), quantity],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: selling),
                  const SizedBox(width: 12),
                  Expanded(child: quantity),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final foc = NetField(
                label: 'FOC/Normal',
                child: _statusDropdown(
                  context,
                  value: item.focNormal.isEmpty ? 'normal' : item.focNormal,
                  options: const {'normal': 'Normal', 'foc': 'FOC'},
                  onChanged: (v) => setState(() => item.focNormal = v),
                ),
              );
              final expiry = NetField(
                label: 'Expiry Date',
                child: _DateField(
                  value: item.expiryDate,
                  allowEmpty: true,
                  onChanged: (v) => setState(() => item.expiryDate = v),
                ),
              );
              final total = NetField(
                label: 'Subtotal',
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'PKR ${_plain(item.subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              );
              if (!wide) {
                return Column(
                  children: [
                    foc,
                    const SizedBox(height: 10),
                    expiry,
                    const SizedBox(height: 10),
                    total,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: foc),
                  const SizedBox(width: 12),
                  Expanded(child: expiry),
                  const SizedBox(width: 12),
                  Expanded(child: total),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _totalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final fields = <Widget>[
              NetField(
                label: 'Status',
                child: _statusDropdown(
                  context,
                  value: _status,
                  options: const {
                    'unpaid': 'Unpaid',
                    'paid': 'Paid',
                    'partial': 'Partial',
                  },
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              NetField(
                label: 'Discount',
                child: TextField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: netInputDecoration(context),
                ),
              ),
              NetField(
                label: 'Sales Tax',
                child: TextField(
                  controller: _salesTax,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: netInputDecoration(context),
                ),
              ),
              NetField(
                label: 'Wth Tax',
                child: TextField(
                  controller: _wthTax,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: netInputDecoration(context),
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
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: fields[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total Amount: PKR ${_plain(_total)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _statusDropdown(
    BuildContext context, {
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
        color: context.inputFill,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(fontSize: 14, color: context.fg),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: fg,
        ),
      ),
    );
  }

  // --- product helpers ------------------------------------------------------

  List<String> _getAvailableSNs(String productId, int excludeIndex) {
    final kept = (excludeIndex >= 0 &&
            excludeIndex < _items.length &&
            _items[excludeIndex].productId == productId)
        ? parseSerialNumbers(_items[excludeIndex].serialNumber)
        : <String>[];
    final vps =
        _vendorProducts().where((p) => p.productId == productId).toList();
    if (vps.isEmpty) return kept;
    final vp = vps.first;
    final usedByOthers = <String>{};
    for (var i = 0; i < _items.length; i++) {
      if (i == excludeIndex) continue;
      final it = _items[i];
      if (it.productId == productId && it.serialNumber.isNotEmpty) {
        usedByOthers.addAll(parseSerialNumbers(it.serialNumber));
      }
    }
    var available =
        vp.allSNs.where((sn) => !usedByOthers.contains(sn)).toList();
    if (available.isEmpty && !vp.noSerial) {
      available = vp.allVendorSNs
          .where((sn) => !usedByOthers.contains(sn))
          .toList();
    }
    final have = available.toSet();
    for (final sn in kept) {
      if (!have.contains(sn)) available.add(sn);
    }
    return available;
  }

  void _addItem(String productId) {
    final vps =
        _vendorProducts().where((p) => p.productId == productId).toList();
    if (vps.isEmpty) return;
    final vp = vps.first;
    final isNoSN = vp.noSerial;

    final existingIndex =
        _items.indexWhere((it) => it.productId == productId);
    if (existingIndex >= 0) {
      setState(() {
        final item = _items[existingIndex];
        final qty = item.quantity < 1 ? 1 : item.quantity;
        if (isNoSN) {
          item.quantity = qty + 1;
          item.syncQtyController();
        } else {
          final currentSNs = parseSerialNumbers(item.serialNumber);
          final haveSNs = currentSNs.toSet();
          final available = _getAvailableSNs(productId, existingIndex)
              .where((sn) => !haveSNs.contains(sn))
              .toList();
          if (available.isNotEmpty) {
            final nextSN = available.first;
            final nextModel = _modelForSn(productId, nextSN);
            item.quantity = currentSNs.length + 1;
            item.serialNumber = [...currentSNs, nextSN].join(', ');
            final existingModels = parseModels(item.model);
            item.model = [
              ...existingModels,
              if (nextModel.isNotEmpty) nextModel
            ].join(', ');
            item.syncQtyController();
          }
        }
      });
      return;
    }

    final available = _getAvailableSNs(productId, _items.length);
    final qty = isNoSN ? 1 : (available.isEmpty ? 1 : 1);
    final snString = isNoSN ? '' : available.take(qty).join(', ');
    final firstSN = available.isEmpty ? '' : available.first;
    final modelString = (!isNoSN && firstSN.isNotEmpty)
        ? _modelForSn(productId, firstSN)
        : '';

    setState(() {
      _items.add(
        _ItemDraft(
          productId: productId,
          productName: vp.productName,
          quantity: qty,
          purchasePrice: vp.unitPrice,
          sellingPrice: vp.sellingPrice,
          unitType: vp.unitType,
          serialNumber: snString,
          model: modelString,
        ),
      );
    });
    if (vp.invoiceNumber.isNotEmpty) _billId.text = vp.invoiceNumber;
    if (vp.batch.isNotEmpty) _batch.text = vp.batch;
  }

  void _updateQuantity(int index, int qty) {
    setState(() {
      final item = _items[index];
      final vps =
          _vendorProducts().where((p) => p.productId == item.productId).toList();
      final vp = vps.isEmpty ? null : vps.first;
      final isNoSN = vp == null || vp.noSerial;
      final available = _getAvailableSNs(item.productId, index);
      final maxQty =
          isNoSN ? 99999 : (available.isEmpty ? 1 : available.length);
      final clamped = qty < 1 ? 1 : (isNoSN ? qty : qty.clamp(1, maxQty));
      item.quantity = clamped;
      if (isNoSN) {
        item.serialNumber = '';
        item.model = '';
      } else {
        final selected = available.take(clamped).toList();
        item.serialNumber = selected.join(', ');
        item.model = selected
            .map((sn) => _modelForSn(item.productId, sn))
            .where((m) => m.isNotEmpty)
            .join(', ');
      }
    });
  }

  void _submit() {
    if (_vendorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor is required')),
      );
      return;
    }
    if (_purchaseDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date is required')),
      );
      return;
    }
    final vendorName = _vendorName.isNotEmpty ? _vendorName : _vendorNameFor(_vendorId);
    final payload = <String, dynamic>{
      'vendorId': _vendorId,
      'vendorName': vendorName,
      'billId': _billId.text.trim(),
      'batch': _batch.text.trim(),
      'purchaseDate': _purchaseDate,
      'status': _status,
      'discount': _parse(_discount),
      'salesTax': _parse(_salesTax),
      'wthTax': _parse(_wthTax),
      'totalAmount': _total,
      'items': _items.map((item) => item.toJson()).toList(),
    };
    if (widget.purchase != null) {
      payload['id'] = widget.purchase!.id;
      payload['purchaseNumber'] = widget.purchase!.purchaseNumber;
      payload['remainingAmount'] = widget.purchase!.remainingAmount;
    } else {
      payload['purchaseNumber'] = '';
      payload['remainingAmount'] = 0;
    }
    Navigator.of(context).pop(payload);
  }
}

class _ItemDraft {
  _ItemDraft({
    this.id = '',
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.unitType,
    this.focNormal = 'normal',
    this.serialNumber = '',
    this.model = '',
    this.saleTax = 0,
    this.wthTax = 0,
    this.disc = 0,
    this.expiryDate = '',
  }) : qtyController = TextEditingController(text: _plainOf(quantity));

  final String id;
  final String productId;
  final String productName;
  num quantity;
  final num purchasePrice;
  final num sellingPrice;
  final String unitType;
  String focNormal;
  String serialNumber;
  String model;
  final num saleTax;
  final num wthTax;
  final num disc;
  String expiryDate;
  final TextEditingController qtyController;

  static String _plainOf(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  num get subtotal => quantity * purchasePrice;

  void syncQtyController() => qtyController.text = _plainOf(quantity);

  void dispose() => qtyController.dispose();

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'unitType': unitType,
        'focNormal': focNormal,
        'serialNumber': serialNumber,
        'model': model,
        'subtotal': subtotal,
        'saleTax': saleTax,
        'wthTax': wthTax,
        'disc': disc,
        'expiryDate': expiryDate.isEmpty ? null : expiryDate,
      };
}

class _VendorProduct {
  _VendorProduct({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.sellingPrice,
    required this.unitType,
    required this.allSNs,
    required this.allModels,
    required this.allVendorSNs,
    required this.allVendorModels,
    required this.noSerial,
    required this.invoiceNumber,
    required this.batch,
  });

  final String productId;
  final String productName;
  final num unitPrice;
  final num sellingPrice;
  final String unitType;
  final List<String> allSNs;
  final List<String> allModels;
  final List<String> allVendorSNs;
  final List<String> allVendorModels;
  final bool noSerial;
  final String invoiceNumber;
  final String batch;
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onChanged,
    this.allowEmpty = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        DateTime initial = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final iso = picked.toIso8601String().split('T').first;
          onChanged(iso);
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
            Icon(Icons.calendar_today_outlined, size: 16, color: context.mutedFg),
          ],
        ),
      ),
    );
  }
}
