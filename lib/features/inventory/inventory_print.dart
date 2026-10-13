import 'package:flutter/material.dart';

import '../../core/offline_api.dart';
import '../../theme/app_theme.dart';
import '../sales/sales_bluetooth_printer.dart';
import '../sales/sales_common.dart';
import '../sales/sales_escpos.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Builds the printable HTML for a vendor invoice, mirroring the web
/// `/inventory/vendor-invoices/print` page (A4 + thermal).
String buildVendorInvoiceHtml(
  VendorInvoice invoice,
  SalesCompany company,
  String size,
) {
  final companyName = company.name.isEmpty ? 'Your Company' : company.name;
  final rows = invoice.items.map((item) {
    final price = item.purchasePrice != 0 ? item.purchasePrice : item.unitPrice;
    return '''
      <tr>
        <td>${salesEscapeHtml(item.productName)}</td>
        <td class="mono">${salesEscapeHtml(item.serialNumber)}</td>
        <td class="mono">${salesEscapeHtml(item.model)}</td>
        <td class="num">${item.quantity}</td>
        <td class="num">${salesMoney(price)}</td>
        <td class="num">${salesMoney(item.subtotal)}</td>
      </tr>''';
  }).join();

  if (size == 'thermal') {
    return _thermalShell(
      title: 'Vendor Invoice ${invoice.invoiceNumber}',
      companyName: companyName,
      company: company,
      heading: 'VENDOR INVOICE',
      metaLines: [
        _tRow('No:', invoice.invoiceNumber),
        _tRow('Date:', invoice.invoiceDate),
        _tRow('Vendor:', invoice.vendorName.isEmpty ? '-' : invoice.vendorName),
        if (invoice.batch.isNotEmpty) _tRow('Batch:', invoice.batch),
      ],
      itemRows: invoice.items.map((item) {
        final price =
            item.purchasePrice != 0 ? item.purchasePrice : item.unitPrice;
        final sns = parseSerialNumbers(item.serialNumber);
        return '''
        <div class="line">
          <div class="line-top"><span>${salesEscapeHtml(item.productName)}</span><span>${salesMoney(item.subtotal)}</span></div>
          <div class="line-bot"><span>${item.quantity} x ${salesMoney(price)}</span></div>
          ${sns.isNotEmpty ? '<div class="line-bot">SN: ${salesEscapeHtml(sns.join(', '))}</div>' : ''}
        </div>''';
      }).join(),
      totals: [
        _tRow('Subtotal', 'PKR ${salesMoney(invoice.totalAmount + invoice.discount)}'),
        if (invoice.discount > 0)
          _tRow('Discount', '- PKR ${salesMoney(invoice.discount)}'),
        _tRowTotal('TOTAL', 'PKR ${salesMoney(invoice.totalAmount)}'),
      ],
    );
  }

  return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Vendor Invoice ${salesEscapeHtml(invoice.invoiceNumber)}</title>
<style>${_docStyle(company)}</style></head>
<body><div class="container">
  ${_header(companyName, company, 'VENDOR INVOICE',
      'Invoice #: <span>${salesEscapeHtml(invoice.invoiceNumber)}</span><br/>Date: <span>${salesEscapeHtml(invoice.invoiceDate)}</span>'
      '${invoice.batch.isNotEmpty ? '<br/>Batch: <span>${salesEscapeHtml(invoice.batch)}</span>' : ''}'
      '<br/>Vendor: <span>${salesEscapeHtml(invoice.vendorName)}</span>')}
  <table><thead><tr>
    <th>Product</th><th>SN / MAC</th><th>Model</th>
    <th class="num">Qty</th><th class="num">Purchase Price</th><th class="num">Total</th>
  </tr></thead><tbody>${rows.isEmpty ? '<tr><td colspan="6" class="center muted">No items</td></tr>' : rows}</tbody></table>
  <div class="summary"><table><tbody>
    <tr><td>Subtotal</td><td class="num">PKR ${salesMoney(invoice.totalAmount + invoice.discount)}</td></tr>
    ${invoice.discount > 0 ? '<tr><td>Discount</td><td class="num">- PKR ${salesMoney(invoice.discount)}</td></tr>' : ''}
    <tr class="grand"><td>TOTAL</td><td class="num">PKR ${salesMoney(invoice.totalAmount)}</td></tr>
  </tbody></table></div>
  <footer><div class="co">${salesEscapeHtml(companyName)}</div>
    ${company.contact1.isNotEmpty ? '<div class="sub">Phone: ${salesEscapeHtml(company.contact1)}</div>' : ''}
    <div class="thanks">Thank you for your business!</div></footer>
</div>${_printButton()}</body></html>''';
}

/// Builds the printable HTML for a purchase, mirroring the web
/// `/inventory/purchases/print` page (A4 + thermal).
String buildPurchaseHtml(
  Purchase purchase,
  SalesCompany company,
  String size,
) {
  final companyName = company.name.isEmpty ? 'Your Company' : company.name;
  final totalQty = purchase.items.fold<num>(0, (s, i) => s + i.effectiveQuantity);
  final rows = purchase.items.map((item) {
    return '''
      <tr>
        <td>${salesEscapeHtml(item.productName)}</td>
        <td class="mono">${salesEscapeHtml(item.serialNumber)}</td>
        <td class="mono">${salesEscapeHtml(item.model)}</td>
        <td class="num">${item.effectiveQuantity}</td>
        <td class="num">${salesMoney(item.purchasePrice)}</td>
        <td class="num">${salesMoney(item.subtotal)}</td>
      </tr>''';
  }).join();

  if (size == 'thermal') {
    return _thermalShell(
      title: 'Purchase ${purchase.displayBillId}',
      companyName: companyName,
      company: company,
      heading: 'PURCHASE',
      metaLines: [
        _tRow('Bill #:', purchase.displayBillId),
        _tRow('Date:', purchase.purchaseDate),
        _tRow('Vendor:', purchase.vendorName.isEmpty ? '-' : purchase.vendorName),
        if (purchase.batch.isNotEmpty) _tRow('Batch:', purchase.batch),
      ],
      itemRows: purchase.items.map((item) {
        final sns = parseSerialNumbers(item.serialNumber);
        return '''
        <div class="line">
          <div class="line-top"><span>${salesEscapeHtml(item.productName)}</span><span>${salesMoney(item.subtotal)}</span></div>
          <div class="line-bot"><span>${item.effectiveQuantity} x ${salesMoney(item.purchasePrice)}</span></div>
          ${sns.isNotEmpty ? '<div class="line-bot">SN: ${salesEscapeHtml(sns.join(', '))}</div>' : ''}
        </div>''';
      }).join(),
      totals: [
        _tRow('Total Items', '$totalQty'),
        _tRow('Subtotal', 'PKR ${salesMoney(purchase.totalAmount - purchase.salesTax - purchase.wthTax + purchase.discount)}'),
        if (purchase.discount > 0)
          _tRow('Discount', '- PKR ${salesMoney(purchase.discount)}'),
        if (purchase.salesTax > 0)
          _tRow('Sales Tax', 'PKR ${salesMoney(purchase.salesTax)}'),
        if (purchase.wthTax > 0)
          _tRow('Wth Tax', 'PKR ${salesMoney(purchase.wthTax)}'),
        _tRowTotal('TOTAL', 'PKR ${salesMoney(purchase.totalAmount)}'),
      ],
    );
  }

  return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Purchase ${salesEscapeHtml(purchase.purchaseNumber)}</title>
<style>${_docStyle(company)}</style></head>
<body><div class="container">
  ${_header(companyName, company, 'PURCHASE',
      'Bill #: <span>${salesEscapeHtml(purchase.displayBillId)}</span><br/>Date: <span>${salesEscapeHtml(purchase.purchaseDate)}</span>'
      '${purchase.batch.isNotEmpty ? '<br/>Batch: <span>${salesEscapeHtml(purchase.batch)}</span>' : ''}'
      '<br/>Vendor: <span>${salesEscapeHtml(purchase.vendorName)}</span>'
      '<br/>Status: <span>${salesEscapeHtml(purchase.status.toUpperCase())}</span>')}
  <table><thead><tr>
    <th>Product</th><th>SN / MAC</th><th>Model</th>
    <th class="num">Qty</th><th class="num">Purchase Price</th><th class="num">Total</th>
  </tr></thead><tbody>${rows.isEmpty ? '<tr><td colspan="6" class="center muted">No items</td></tr>' : rows}</tbody></table>
  <div class="summary"><table><tbody>
    <tr><td>Total Items</td><td class="num">$totalQty</td></tr>
    <tr><td>Subtotal</td><td class="num">PKR ${salesMoney(purchase.totalAmount - purchase.salesTax - purchase.wthTax + purchase.discount)}</td></tr>
    ${purchase.discount > 0 ? '<tr><td>Discount</td><td class="num">- PKR ${salesMoney(purchase.discount)}</td></tr>' : ''}
    ${purchase.salesTax > 0 ? '<tr><td>Sales Tax</td><td class="num">PKR ${salesMoney(purchase.salesTax)}</td></tr>' : ''}
    ${purchase.wthTax > 0 ? '<tr><td>Wth Tax</td><td class="num">PKR ${salesMoney(purchase.wthTax)}</td></tr>' : ''}
    <tr class="grand"><td>TOTAL</td><td class="num">PKR ${salesMoney(purchase.totalAmount)}</td></tr>
  </tbody></table></div>
  <footer><div class="co">${salesEscapeHtml(companyName)}</div>
    ${company.contact1.isNotEmpty ? '<div class="sub">Phone: ${salesEscapeHtml(company.contact1)}</div>' : ''}
    <div class="thanks">Thank you for your business!</div></footer>
</div>${_printButton()}</body></html>''';
}

String _docStyle(SalesCompany company) => '''
  @page { size: A4; margin: 15mm; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:'Segoe UI',system-ui,sans-serif; color:#111827; background:#fff; }
  .container { max-width:800px; margin:0 auto; padding:32px; }
  header { display:flex; justify-content:space-between; align-items:flex-start; border-bottom:3px solid #111827; padding-bottom:24px; margin-bottom:32px; }
  .brand .name { font-size:24px; font-weight:700; }
  .brand .meta { font-size:13px; color:#6b7280; margin-top:4px; line-height:1.5; }
  .doc { text-align:right; }
  .doc .title { font-size:32px; font-weight:800; letter-spacing:2px; color:#ea580c; }
  .doc .rid { font-size:13px; color:#6b7280; margin-top:8px; line-height:1.8; }
  .doc .rid span { color:#111827; font-weight:600; }
  table { width:100%; border-collapse:collapse; }
  thead th { background:#111827; color:#fff; padding:8px; font-size:12px; text-align:left; }
  tbody td { border:1px solid #e5e7eb; padding:8px; font-size:13px; }
  .num { text-align:right; }
  .mono { font-family:monospace; font-size:12px; }
  .center { text-align:center; }
  .muted { color:#9ca3af; }
  .summary { display:flex; justify-content:flex-end; margin-top:16px; }
  .summary table { width:300px; }
  .summary td { padding:3px 0; font-size:13px; color:#6b7280; border:none; }
  .summary tr.grand td { border-top:2px solid #111827; font-weight:700; color:#111827; font-size:16px; }
  footer { margin-top:40px; border-top:1px solid #d1d5db; padding-top:20px; text-align:center; }
  footer .co { font-size:18px; font-weight:700; }
  footer .sub { font-size:13px; color:#6b7280; }
  footer .thanks { font-size:12px; color:#9ca3af; margin-top:6px; }
  .no-print { text-align:center; margin:16px 0; }
  .no-print button { padding:10px 22px; background:#111827; color:#fff; border:none; border-radius:8px; cursor:pointer; }
  @media print { .no-print { display:none; } }
''';

String _header(
  String companyName,
  SalesCompany company,
  String title,
  String meta,
) =>
    '''
  <header>
    <div class="brand">
      <div class="name">${salesEscapeHtml(companyName)}</div>
      ${company.address.isNotEmpty ? '<div class="meta">${salesEscapeHtml(company.address)}</div>' : ''}
      ${company.contact1.isNotEmpty ? '<div class="meta">Phone: ${salesEscapeHtml(company.contact1)}</div>' : ''}
    </div>
    <div class="doc"><div class="title">$title</div><div class="rid">$meta</div></div>
  </header>''';

String _printButton() => '''
<div class="no-print"><button onclick="window.print()">Print</button></div>''';

// --- thermal shells ---------------------------------------------------------

String _thermalShell({
  required String title,
  required String companyName,
  required SalesCompany company,
  required String heading,
  required List<String> metaLines,
  required String itemRows,
  required List<String> totals,
}) {
  return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>${salesEscapeHtml(title)}</title>
<style>
  @page { size: 80mm auto; margin: 3mm; }
  body { margin:0; font-family:'Courier New',monospace; color:#000; }
  .receipt { width:74mm; margin:0 auto; padding:4px 2px; font-size:12px; }
  .center { text-align:center; }
  .name { font-size:16px; font-weight:700; }
  .muted { font-size:10px; color:#444; }
  .sep { border-top:1px dashed #000; margin:6px 0; }
  .row { display:flex; justify-content:space-between; margin:2px 0; font-size:11px; }
  .line-top { display:flex; justify-content:space-between; }
  .line-bot { font-size:10px; color:#444; }
  .grand { border-top:1px dashed #000; margin-top:4px; padding-top:4px; font-weight:700; font-size:14px; }
  .no-print { text-align:center; margin-top:10px; }
  @media print { .no-print { display:none; } }
</style></head>
<body><div class="receipt">
  <div class="center">
    <div class="name">${salesEscapeHtml(companyName)}</div>
    ${company.address.isNotEmpty ? '<div class="muted">${salesEscapeHtml(company.address)}</div>' : ''}
    ${company.contact1.isNotEmpty ? '<div class="muted">Tel: ${salesEscapeHtml(company.contact1)}</div>' : ''}
  </div>
  <div class="sep"></div>
  <div class="center muted">$heading</div>
  <div class="sep"></div>
  ${metaLines.join()}
  <div class="sep"></div>
  ${itemRows.isEmpty ? '<div class="muted center">No items</div>' : itemRows}
  <div class="sep"></div>
  ${totals.join()}
  <div class="sep"></div>
  <div class="center muted">Thank you for your business!</div>
  <div class="no-print"><button onclick="window.print()">Print</button></div>
</div></body></html>''';
}

String _tRow(String label, String value) =>
    '<div class="row"><span class="muted">$label</span><span>${salesEscapeHtml(value)}</span></div>';

String _tRowTotal(String label, String value) =>
    '<div class="row grand"><span>$label</span><span>${salesEscapeHtml(value)}</span></div>';

/// ESC/POS byte stream for a vendor invoice (Bluetooth thermal printing).
List<int> buildVendorInvoiceEscPos(VendorInvoice invoice, SalesCompany company) {
  final p = SalesEscPos();
  final name = company.name.isEmpty ? 'Your Company' : company.name;
  p.alignCenter();
  p.setBold(true);
  p.setSize(0x33);
  p.line(name.toUpperCase());
  p.setSize(0x00);
  p.setBold(false);
  if (company.address.isNotEmpty) p.line(company.address);
  if (company.contact1.isNotEmpty) p.line('Tel: ${company.contact1}');
  p.feed();
  p.separator('=');
  p.setBold(true);
  p.line('VENDOR INVOICE');
  p.setBold(false);
  p.separator('=');
  p.alignLeft();
  p.line(_twoCol('No:', invoice.invoiceNumber));
  p.line(_twoCol('Date:', invoice.invoiceDate));
  p.line(_twoCol('Vendor:', invoice.vendorName));
  if (invoice.batch.isNotEmpty) p.line(_twoCol('Batch:', invoice.batch));
  p.separator();
  for (final item in invoice.items) {
    final price = item.purchasePrice != 0 ? item.purchasePrice : item.unitPrice;
    p.line(_twoCol(item.productName, _moneyEsc(item.subtotal)));
    p.line('  ${item.quantity} x ${_moneyEsc(price)}');
    if (item.serialNumber.isNotEmpty) p.line('  SN: ${item.serialNumber}');
  }
  p.separator();
  p.line(_twoCol('Subtotal', _moneyEsc(invoice.totalAmount + invoice.discount)));
  if (invoice.discount > 0) {
    p.line(_twoCol('Discount', '- ${_moneyEsc(invoice.discount)}'));
  }
  p.setBold(true);
  p.setSize(0x11);
  p.line(_twoCol('TOTAL', _moneyEsc(invoice.totalAmount)));
  p.setSize(0x00);
  p.setBold(false);
  p.separator();
  p.alignCenter();
  p.line('Thank you for your business!');
  p.feed(2);
  p.cut();
  return p.bytes();
}

/// ESC/POS byte stream for a purchase (Bluetooth thermal printing).
List<int> buildPurchaseEscPos(Purchase purchase, SalesCompany company) {
  final p = SalesEscPos();
  final name = company.name.isEmpty ? 'Your Company' : company.name;
  p.alignCenter();
  p.setBold(true);
  p.setSize(0x33);
  p.line(name.toUpperCase());
  p.setSize(0x00);
  p.setBold(false);
  if (company.address.isNotEmpty) p.line(company.address);
  if (company.contact1.isNotEmpty) p.line('Tel: ${company.contact1}');
  p.feed();
  p.separator('=');
  p.setBold(true);
  p.line('PURCHASE');
  p.setBold(false);
  p.separator('=');
  p.alignLeft();
  p.line(_twoCol('Bill #:', purchase.displayBillId));
  p.line(_twoCol('Date:', purchase.purchaseDate));
  p.line(_twoCol('Vendor:', purchase.vendorName));
  if (purchase.batch.isNotEmpty) p.line(_twoCol('Batch:', purchase.batch));
  p.separator();
  for (final item in purchase.items) {
    p.line(_twoCol(item.productName, _moneyEsc(item.subtotal)));
    p.line('  ${item.effectiveQuantity} x ${_moneyEsc(item.purchasePrice)}');
    if (item.serialNumber.isNotEmpty) p.line('  SN: ${item.serialNumber}');
  }
  p.separator();
  p.setBold(true);
  p.setSize(0x11);
  p.line(_twoCol('TOTAL', _moneyEsc(purchase.totalAmount)));
  p.setSize(0x00);
  p.setBold(false);
  p.separator();
  p.alignCenter();
  p.line('Thank you for your business!');
  p.feed(2);
  p.cut();
  return p.bytes();
}

String _moneyEsc(num value) => 'PKR ${salesMoney(value)}';

String _twoCol(String left, String right, [int width = SalesEscPos.width]) {
  if (left.length + right.length >= width) {
    return '$left\n${right.padLeft(width)}';
  }
  return '$left${' ' * (width - left.length - right.length)}$right';
}

/// Print dialog mirroring the web `print-dialog.tsx`: A4 / Thermal browser
/// printing plus an optional Bluetooth thermal printer.
class InventoryPrintDialog extends StatefulWidget {
  const InventoryPrintDialog({
    super.key,
    required this.title,
    required this.buildHtml,
    required this.buildEscPos,
    required this.escposLabel,
  });

  final String title;
  final String Function(String size) buildHtml;
  final List<int> Function() buildEscPos;
  final String escposLabel;

  @override
  State<InventoryPrintDialog> createState() => _InventoryPrintDialogState();
}

class _InventoryPrintDialogState extends State<InventoryPrintDialog> {
  bool _busy = false;

  Future<void> _open(String size) async {
    final html = widget.buildHtml(size);
    await salesOpenHtml(
      context,
      'inventory_${size}_${DateTime.now().millisecondsSinceEpoch}.html',
      html,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _bluetooth() async {
    setState(() => _busy = true);
    try {
      await SalesBluetoothPrinter.printBytes(
        context,
        bytes: widget.buildEscPos(),
        label: widget.escposLabel,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text('Print ${widget.title}', style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your printing method.',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _open('a4'),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('A4 Size'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _open('thermal'),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('Thermal/Mini'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _busy ? null : _bluetooth,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth, size: 18),
              label: Text(_busy ? 'Printing...' : 'Bluetooth Printer'),
            ),
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
      ],
    );
  }
}

/// Convenience wrapper used by the Purchase / Vendor Invoice tables.
Future<void> showVendorInvoicePrintDialog(
  BuildContext context,
  VendorInvoice invoice,
  OfflineApi api,
) async {
  final company = await fetchSalesCompany(api);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => InventoryPrintDialog(
      title: 'Vendor Invoice ${invoice.invoiceNumber}',
      buildHtml: (size) => buildVendorInvoiceHtml(invoice, company, size),
      buildEscPos: () => buildVendorInvoiceEscPos(invoice, company),
      escposLabel: 'Vendor Invoice ${invoice.invoiceNumber}',
    ),
  );
}

Future<void> showPurchasePrintDialog(
  BuildContext context,
  Purchase purchase,
  OfflineApi api,
) async {
  final company = await fetchSalesCompany(api);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => InventoryPrintDialog(
      title: 'Purchase ${purchase.purchaseNumber}',
      buildHtml: (size) => buildPurchaseHtml(purchase, company, size),
      buildEscPos: () => buildPurchaseEscPos(purchase, company),
      escposLabel: 'Purchase ${purchase.purchaseNumber}',
    ),
  );
}
