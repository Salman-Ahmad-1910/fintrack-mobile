import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// One aggregated history row (mirrors the web `QuantityHistoryRow`).
class PurchaseQtyHistoryRow {
  const PurchaseQtyHistoryRow({
    required this.key,
    required this.dateTime,
    required this.productName,
    required this.quantityBefore,
    required this.quantityAdded,
    required this.unitPrice,
    required this.serials,
    required this.models,
  });

  final String key;
  final String dateTime;
  final String productName;
  final num quantityBefore;
  final num quantityAdded;
  final num unitPrice;
  final String serials;
  final String models;
}

/// Aggregates every item's history into sorted rows.
List<PurchaseQtyHistoryRow> purchaseHistoryRows(Purchase purchase) {
  final rows = <PurchaseQtyHistoryRow>[];
  for (final item in purchase.items) {
    for (final h in item.history) {
      rows.add(
        PurchaseQtyHistoryRow(
          key: '${item.id}-${h.id}',
          dateTime: h.createdAt,
          productName: item.productName,
          quantityBefore: h.quantityBefore,
          quantityAdded: h.quantityAdded,
          unitPrice: h.unitPrice,
          serials: h.serialNumbersAdded,
          models: h.modelsAdded,
        ),
      );
    }
  }
  rows.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return rows;
}

/// Flutter counterpart of the web `QuantityHistoryTable`.
class PurchaseQuantityHistoryTable extends StatelessWidget {
  const PurchaseQuantityHistoryTable({super.key, required this.rows});

  final List<PurchaseQtyHistoryRow> rows;

  static final NumberFormat _money = NumberFormat('#,##0');
  static const List<double> _widths = [28, 150, 150, 80, 80, 100, 160, 140];
  static const List<String> _labels = [
    '#',
    'Date & Time',
    'Product',
    'Qty Added',
    'Qty Before',
    'Unit Price',
    'Serials Added',
    'Models Added',
  ];

  String _fmtDateTime(String raw) {
    if (raw.isEmpty) return '\u2014';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return DateFormat('MMM d, yyyy, hh:mm a').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No quantity entries found.',
          style: TextStyle(fontSize: 12, color: context.mutedFg),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: context.line.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 14, color: context.mutedFg),
                const SizedBox(width: 6),
                Text(
                  'ADDED QUANTITY ENTRIES (${rows.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.mutedFg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _headerRow(context),
            for (var i = 0; i < rows.length; i++) _dataRow(context, rows[i], i),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    return Row(
      children: [
        for (final label in _labels)
          SizedBox(
            width: _widths[_labels.indexOf(label)],
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.mutedFg,
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(
    String text,
    int column, {
    bool mono = false,
    bool right = false,
    Color? color,
  }) {
    return SizedBox(
      width: _widths[column],
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontFamily: mono ? 'monospace' : null,
          color: color,
        ),
      ),
    );
  }

  Widget _dataRow(BuildContext context, PurchaseQtyHistoryRow r, int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          _cell(
            '${i + 1}',
            0,
            mono: true,
            color: context.mutedFg,
          ),
          _cell(_fmtDateTime(r.dateTime), 1,
              color: context.fg),
          _cell(r.productName, 2),
          _cell(
            '+${r.quantityAdded}',
            3,
            right: true,
            color: context.isDark
                ? const Color(0xFF34D399)
                : const Color(0xFF047857),
          ),
          _cell('${r.quantityBefore}', 4, right: true),
          _cell('PKR ${_money.format(r.unitPrice)}', 5, right: true),
          _cell(r.serials.isEmpty ? '\u2014' : r.serials, 6, mono: true),
          _cell(
            r.models.isEmpty ? '\u2014' : r.models,
            7,
            color: context.isDark
                ? const Color(0xFF7DD3FC)
                : const Color(0xFF0369A1),
          ),
        ],
      ),
    );
  }
}

/// Flutter counterpart of the web `add-quantity-dialog.tsx`. Returns the
/// payload map `{productId, quantity, serialNumber, model}` or `null`.
class AddQuantityDialog extends StatefulWidget {
  const AddQuantityDialog({super.key, required this.purchase});

  final Purchase purchase;

  @override
  State<AddQuantityDialog> createState() => _AddQuantityDialogState();
}

class _AddQuantityDialogState extends State<AddQuantityDialog> {
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  String _productId = '';

  @override
  void initState() {
    super.initState();
    _productId = widget.purchase.items.isNotEmpty
        ? widget.purchase.items.first.productId
        : '';
  }

  @override
  void dispose() {
    _serial.dispose();
    _model.dispose();
    _quantity.dispose();
    super.dispose();
  }

  PurchaseItem? get _selectedItem {
    for (final item in widget.purchase.items) {
      if (item.productId == _productId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.purchase.items;
    final selected = _selectedItem;
    final snCount = parseSerialNumbers(_serial.text).length;
    final modelCount = parseModels(_model.text).length;
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    final canSave = _productId.isNotEmpty && qty >= 1 && items.isNotEmpty;

    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: invEmeraldButtonGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_box_outlined,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text('Add Quantity', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: SingleChildScrollView(
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'This purchase has no items to add quantity to.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: context.mutedFg),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add more quantity, serial (SN) / model numbers to '
                        '${widget.purchase.purchaseNumber}. Stock and POS will '
                        'update automatically.',
                        style: TextStyle(fontSize: 13, color: context.mutedFg),
                      ),
                      const SizedBox(height: 14),
                      NetField(
                        label: 'Product / Model',
                        child: _productDropdown(items),
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 12),
                        _existingInfo(context, selected),
                      ],
                      const SizedBox(height: 12),
                      NetField(
                        label: 'Additional Quantity',
                        child: TextField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: netInputDecoration(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adds this many units to the purchase. Independent of '
                        'SN / model numbers below.',
                        style: TextStyle(fontSize: 11, color: context.mutedFg),
                      ),
                      const SizedBox(height: 12),
                      NetField(
                        label: 'Serial Numbers',
                        child: TextField(
                          controller: _serial,
                          minLines: 3,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: netInputDecoration(
                            context,
                            hint: 'e.g., SN-1001, SN-1002, SN-1003',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optional. Separate with comma, space, or dash. Each SN '
                        'is recorded as-is.',
                        style: TextStyle(fontSize: 11, color: context.mutedFg),
                      ),
                      if (snCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$snCount serial number(s) will be recorded',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      NetField(
                        label: 'Model Numbers',
                        child: TextField(
                          controller: _model,
                          minLines: 3,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: netInputDecoration(
                            context,
                            hint: 'e.g., Model-X, Model-Y',
                          ),
                        ),
                      ),
                      if (modelCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$modelCount model number(s) will be recorded',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
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
          label: 'Add ${qty > 0 ? qty : ''} Quantity',
          gradient: invEmeraldButtonGradient,
          onPressed: canSave ? _submit : null,
        ),
      ],
    );
  }

  Widget _productDropdown(List<PurchaseItem> items) {
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
          value: _productId.isEmpty ? null : _productId,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(fontSize: 14, color: context.fg),
          hint: Text('Select a product',
              style: TextStyle(color: context.mutedFg, fontSize: 14)),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item.productId,
                child: Text(item.productName),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _productId = v);
          },
        ),
      ),
    );
  }

  Widget _existingInfo(BuildContext context, PurchaseItem item) {
    final sns = parseSerialNumbers(item.serialNumber);
    final models = parseModels(item.model);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.subtle.withValues(alpha: 0.4),
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Existing: ${sns.length} SN, ${models.length} model',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    Navigator.of(context).pop(<String, dynamic>{
      'productId': _productId,
      'quantity': qty < 1 ? 1 : qty,
      'serialNumber': _serial.text.trim(),
      'model': _model.text.trim(),
    });
  }
}
