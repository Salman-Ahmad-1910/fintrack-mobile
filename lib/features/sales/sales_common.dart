import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/session.dart';
import '../admin/admin_utils.dart';
import 'sales_models.dart';

/// Gradient pairs used across the Sales section — the Flutter counterparts of
/// the web `bg-gradient-to-r/br from-* to-*` utilities on each screen.
const List<Color> salesEmeraldGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> salesAmberGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> salesBlueGradient = [Color(0xFF3B82F6), Color(0xFF2563EB)];
const List<Color> salesVioletGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> salesRoseGradient = [Color(0xFFF43F5E), Color(0xFFE11D48)];
const List<Color> salesIndigoGradient = [Color(0xFF6366F1), Color(0xFF4F46E5)];
const List<Color> salesSkyGradient = [Color(0xFF0EA5E9), Color(0xFF0284C7)];

const Color salesHoldColor = Color(0xFFD97706);
const Color salesReturnedColor = Color(0xFFEA580C);
const Color salesReplacedColor = Color(0xFF7C3AED);
const Color salesGoodSaleColor = Color(0xFF059669);
const Color salesInstallmentColor = Color(0xFF2563EB);

final NumberFormat _money = NumberFormat('#,##0.00');
final NumberFormat _plain = NumberFormat.decimalPattern();

/// Web `Intl.NumberFormat('en-US', {minimumFractionDigits:2}).format(n)`.
String salesMoney(num? value) => _money.format(value ?? 0);

/// Web `Intl.NumberFormat('en-US').format(n)` (no decimals).
String salesNumber(num? value) => _plain.format(value ?? 0);

/// `Number(value).toFixed(2)`.
String salesFixed2(num value) => value.toStringAsFixed(2);

/// `toLocaleDateString()` — short date matching the web tables.
String salesShortDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return 'N/A';
  return DateFormat.yMd().format(d);
}

/// `new Date(value).toLocaleString()` used by the receipts.
String salesDateTime(String raw) {
  final d = DateTime.tryParse(raw);
  final value = d ?? DateTime.now();
  return DateFormat('M/d/yyyy, h:mm:ss a').format(value);
}

String salesToday() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Web `search.ts` `smartMatch`: ranked, priority-ordered value groups. Returns
/// true when any group matches; earlier groups are only skipped once a later
/// group is allowed to be checked.
bool salesSmartMatch(String query, List<List<String?>> groups) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (var i = 0; i < groups.length; i++) {
    if (i > 0 && q.isEmpty) break;
    for (final value in groups[i]) {
      if (value == null) continue;
      final s = value.toLowerCase();
      if (s.startsWith(q) || s.contains(q)) return true;
    }
  }
  return false;
}

/// Web `prefixMatch` — true when any value starts with the query.
bool salesPrefixMatch(String query, Iterable<String?> values) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final value in values) {
    if (value == null) continue;
    if (value.toLowerCase().startsWith(q)) return true;
  }
  return false;
}

/// Web `smartMatchScore` — ranked match (lower is better, -1 = no match).
/// Earlier groups always outrank later ones; within a group a prefix match
/// (0) beats a substring match (1).
int salesSmartMatchScore(String query, List<List<String?>> groups) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  for (var i = 0; i < groups.length; i++) {
    var substringMatch = -1;
    for (final value in groups[i]) {
      if (value == null) continue;
      final s = value.toLowerCase();
      if (s.startsWith(q)) return i * 2;
      if (substringMatch < 0 && s.contains(q)) substringMatch = 1;
    }
    if (substringMatch >= 0) return i * 2 + substringMatch;
  }
  return -1;
}

/// Web `smartSearch` — keeps the matching items and sorts them so the best
/// ranked matches come first (stable on ties).
List<T> salesSmartSearch<T>(
  String query,
  List<T> items,
  List<List<String?>> Function(T item) getGroups,
) {
  final scored = <({T item, int score, int index})>[];
  for (var i = 0; i < items.length; i++) {
    final score = salesSmartMatchScore(query, getGroups(items[i]));
    if (score >= 0) scored.add((item: items[i], score: score, index: i));
  }
  scored.sort((a, b) {
    final c = a.score.compareTo(b.score);
    return c != 0 ? c : a.index.compareTo(b.index);
  });
  return [for (final e in scored) e.item];
}

/// Colour + label for a sale status badge.
Color salesStatusColor(String status) {
  switch (status) {
    case 'hold':
      return salesHoldColor;
    case 'returned':
      return salesReturnedColor;
    case 'replaced':
      return salesReplacedColor;
    default:
      return salesGoodSaleColor;
  }
}

String salesStatusLabel(String status) {
  switch (status) {
    case 'hold':
      return 'Hold';
    case 'returned':
      return 'Returned';
    case 'replaced':
      return 'Replaced';
    case 'completed':
      return 'Completed';
    default:
      return status;
  }
}

/// The signed-in company's receipt details (`/companies`).
class SalesCompany {
  SalesCompany({
    required this.id,
    required this.name,
    required this.address,
    required this.contact1,
    required this.logo,
    required this.stamp,
    required this.posDiscountPercent,
    required this.posDiscountUnlimited,
  });

  final String id;
  final String name;
  final String address;
  final String contact1;
  final String logo;
  final String stamp;
  final double posDiscountPercent;
  final bool posDiscountUnlimited;

  factory SalesCompany.fromJson(Map<String, dynamic> j) => SalesCompany(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    address: (j['address'] ?? '').toString(),
    contact1: (j['contact1'] ?? '').toString(),
    logo: (j['logo'] ?? '').toString(),
    stamp: (j['stamp'] ?? '').toString(),
    posDiscountPercent:
        double.tryParse((j['posDiscountPercent'] ?? 0).toString()) ?? 0,
    posDiscountUnlimited: j['posDiscountUnlimited'] == true,
  );

  static final empty = SalesCompany(
    id: '',
    name: '',
    address: '',
    contact1: '',
    logo: '',
    stamp: '',
    posDiscountPercent: 0,
    posDiscountUnlimited: false,
  );
}

/// Loads the companies list and returns the currently selected one (falling
/// back to the first). Mirrors the web `useCompany()` context.
Future<SalesCompany> fetchSalesCompany(ApiClient api) async {
  final json = await api.get('/companies');
  final list = ApiClient.listData(json)
      .whereType<Map<String, dynamic>>()
      .toList();
  if (list.isEmpty) return SalesCompany.empty;
  Map<String, dynamic>? match;
  for (final c in list) {
    if (Session.companyId != null && c['id'].toString() == Session.companyId) {
      match = c;
      break;
    }
  }
  return SalesCompany.fromJson(match ?? list.first);
}

/// Resolves a backend-stored image path to a full URL (`backendImageUrl`).
String? salesBackendImageUrl(String path) {
  if (path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = ApiConfig.base;
  return '$base${path.startsWith('/') ? '' : '/'}$path';
}

// ---------------------------------------------------------------------------
// CSV export (the Flutter client writes CSV instead of the web's XLSX).
// ---------------------------------------------------------------------------

String salesCsvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String salesCsvLine(List<String> cells) => cells.map(salesCsvCell).join(',');

/// Saves [rows] to a CSV file the user picks a location for.
Future<bool> salesWriteCsv(
  BuildContext context,
  String fileName,
  List<List<String>> rows,
) async {
  final content = rows.map(salesCsvLine).join('\r\n');
  final path = await FilePickerSave.save(context, fileName, content);
  return path;
}

// ---------------------------------------------------------------------------
// HTML report / receipt helpers (write an .html file and open it in the
// default browser, mirroring the web's "open in a new tab" behaviour).
// ---------------------------------------------------------------------------

String salesEscapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Writes [html] to a temp file and opens it in the system browser.
Future<void> salesOpenHtml(
  BuildContext context,
  String fileName,
  String html,
) async {
  try {
    // Android blocks `file://` URIs to other apps, so on phones the document
    // is rendered to PDF and handed to the system print / "Save as PDF" sheet.
    if (Platform.isAndroid || Platform.isIOS) {
      final name = fileName.replaceAll(RegExp(r'\.html?$'), '');
      await Printing.layoutPdf(
        name: name,
        onLayout: (format) => Printing.convertHtml(format: format, html: html),
      );
      return;
    }
    final dir = await Directory.systemTemp.createTemp('fintrack_sales');
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(html, flush: true);
    if (Platform.isWindows) {
      await Process.start('cmd', [
        '/c',
        'start',
        '',
        file.path,
      ], runInShell: true);
    } else {
      await launchUrl(Uri.file(file.path));
    }
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Could not open the document', error: true);
    }
  }
}

/// Indirection so tests (and platforms without a save dialog) can stub the
/// file picker out.
class FilePickerSave {
  FilePickerSave._();

  static Future<bool> Function(
    BuildContext context,
    String fileName,
    String content,
  )?
  override;

  static Future<bool> save(
    BuildContext context,
    String fileName,
    String content,
  ) async {
    if (override != null) return override!(context, fileName, content);
    final path = await _defaultSave(context, fileName, content);
    return path;
  }

  static Future<bool> _defaultSave(
    BuildContext context,
    String fileName,
    String content,
  ) async {
    // file_picker requires the bytes on Android/iOS (it writes the file
    // itself through the system "save as" UI and throws without them).
    final bytes = utf8.encode(content);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      bytes: bytes,
    );
    if (path == null) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsString(content);
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Sale receipt (A4 + thermal), mirroring `sale-receipt.tsx`.
// ---------------------------------------------------------------------------

class ReceiptInstallmentInfo {
  ReceiptInstallmentInfo({
    required this.planName,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.installmentAmount,
    required this.totalAmount,
    required this.remainingInstallments,
    required this.status,
  });

  final String planName;
  final int totalInstallments;
  final int paidInstallments;
  final double installmentAmount;
  final double totalAmount;
  final int remainingInstallments;
  final String status;
}

class SaleReceiptData {
  SaleReceiptData({
    required this.id,
    required this.invoiceNumber,
    required this.subscriberName,
    required this.totalAmount,
    required this.taxAmount,
    required this.discount,
    required this.paymentMethod,
    required this.date,
    required this.items,
    this.isInstallment = false,
    this.installmentInfo,
  });

  final String id;
  final int invoiceNumber;
  final String subscriberName;
  final double totalAmount;
  final double taxAmount;
  final double discount;
  final String paymentMethod;
  final String date;
  final List<SalesItem> items;
  final bool isInstallment;
  final ReceiptInstallmentInfo? installmentInfo;
}

String _fmtPKR2(num n) => salesMoney(n);

String _companyImageUrl(String kind, String id) {
  return '${ApiConfig.base}/uploads/$kind/$id';
}

/// Builds the printable receipt HTML. [size] is `'a4'` or `'thermal'`.
String buildSaleReceiptHtml(
  SaleReceiptData sale,
  SalesCompany company,
  String size,
) {
  final companyName = company.name.isEmpty ? 'Your Company' : company.name;
  final logoUrl = company.logo.isNotEmpty
      ? _companyImageUrl('company_images', company.id)
      : null;
  final stampUrl = company.stamp.isNotEmpty
      ? _companyImageUrl('company_stamps', company.id)
      : null;
  return size == 'thermal'
      ? _buildThermalReceipt(
          sale,
          companyName,
          company.address,
          company.contact1,
          logoUrl,
        )
      : _buildA4Receipt(
          sale,
          companyName,
          company.address,
          company.contact1,
          logoUrl,
          stampUrl,
        );
}

/// Writes the receipt and opens it (A4/thermal) in the browser.
Future<void> printSaleReceipt(
  BuildContext context,
  SaleReceiptData sale,
  SalesCompany company,
  String size,
) async {
  final html = buildSaleReceiptHtml(sale, company, size);
  final label = sale.isInstallment
      ? 'Installment Invoice #${sale.invoiceNumber}'
      : 'Sale Receipt #${sale.invoiceNumber}';
  await salesOpenHtml(
    context,
    'receipt_${sale.invoiceNumber}_$size.html',
    html,
  );
  if (context.mounted) showToast(context, '$label opened');
}

String _signatures(String? stampUrl) {
  final stamp = stampUrl != null
      ? '<img src="${salesEscapeHtml(stampUrl)}" alt="Company Stamp" onerror="this.style.display=\'none\'" />'
      : '<div class="line"></div>';
  return '''
    <div class="sigs">
      <div class="sig">$stamp<div class="lbl">Company Stamp</div></div>
      <div class="sig"><div class="line"></div><div class="lbl">Authorized Signature</div></div>
    </div>''';
}

String _header(
  String companyName,
  String address,
  String phone,
  String? logoUrl,
  String title,
  String meta,
) {
  final logo = logoUrl != null
      ? '<img src="${salesEscapeHtml(logoUrl)}" alt="Logo" />'
      : '';
  return '''
  <header>
    <div class="brand">
      $logo
      <div>
        <div class="name">${salesEscapeHtml(companyName)}</div>
        ${address.isNotEmpty ? '<div class="meta">${salesEscapeHtml(address)}</div>' : ''}
        ${phone.isNotEmpty ? '<div class="meta">Phone: ${salesEscapeHtml(phone)}</div>' : ''}
      </div>
    </div>
    <div class="doc">
      <div class="title">$title</div>
      <div class="rid">$meta</div>
    </div>
  </header>''';
}

const String _a4Style = '''
  @page { size: A4; margin: 15mm; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:'Segoe UI',system-ui,-apple-system,sans-serif; color:#111827; background:#fff; padding:0; }
  .container { max-width:800px; margin:0 auto; padding:32px; }
  header { display:flex; justify-content:space-between; align-items:flex-start; border-bottom:3px solid #111827; padding-bottom:24px; margin-bottom:32px; }
  .brand { display:flex; gap:16px; align-items:flex-start; }
  .brand img { width:60px; height:60px; object-fit:contain; }
  .brand .name { font-size:24px; font-weight:700; color:#111827; }
  .brand .meta { font-size:13px; color:#6b7280; margin-top:4px; line-height:1.5; }
  .doc { text-align:right; }
  .doc .title { font-size:36px; font-weight:800; letter-spacing:2px; color:#059669; }
  .doc .rid { font-size:13px; color:#6b7280; margin-top:8px; line-height:1.8; }
  .doc .rid span { color:#111827; font-weight:600; }
  .status-pill { display:inline-block; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:700; text-transform:uppercase; }
  .status-paid { background:#dcfce7; color:#166534; }
  .status-pending { background:#fef9c3; color:#854d0e; }
  .amounts-box { border:2px solid #059669; border-radius:10px; overflow:hidden; margin-bottom:32px; }
  .amounts-box .box-header { background:#059669; color:#fff; padding:10px 16px; font-size:14px; font-weight:700; text-transform:uppercase; letter-spacing:1px; }
  .amounts-box .box-row { display:flex; justify-content:space-between; padding:10px 16px; font-size:13px; border-bottom:1px solid #e5e7eb; }
  .amounts-box .box-row:last-child { border-bottom:none; }
  .amounts-box .box-row .label { color:#6b7280; }
  .amounts-box .box-row .value { font-weight:600; }
  .amounts-box .box-row.info .value { font-weight:700; color:#111827; }
  .amounts-box .box-row.total { background:#f0fdf4; font-weight:700; font-size:15px; }
  .amounts-box .box-row.total .value { color:#059669; }
  .amounts-box .box-row.paid .value { color:#16a34a; }
  .amounts-box .box-row.remaining .value { color:#d97706; }
  .amounts-box .box-row.per-inst .value { color:#1d4ed8; }
  .amounts-box .divider { border-top:2px solid #059669; margin:0; }
  table { width:100%; border-collapse:collapse; margin-bottom:16px; }
  thead tr { background:#059669; color:#fff; }
  thead th { padding:10px; font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; border:1px solid #d1d5db; }
  thead th.text-right { text-align:right; }
  thead th.text-center { text-align:center; }
  tbody td { padding:10px; font-size:13px; border:1px solid #d1d5db; }
  tbody tr:hover { background:rgba(236,253,245,0.5); }
  .summary { display:flex; justify-content:flex-end; margin-bottom:32px; }
  .summary table { width:260px; margin-bottom:0; }
  .summary td { padding:3px 0; font-size:13px; color:#6b7280; }
  .summary td:last-child { text-align:right; }
  footer { margin-top:48px; border-top:1px solid #d1d5db; padding-top:24px; }
  .sigs { display:flex; justify-content:space-between; align-items:flex-end; margin-bottom:24px; }
  .sig { text-align:center; }
  .sig img { max-height:80px; max-width:180px; object-fit:contain; margin-bottom:4px; }
  .sig .line { border-bottom:1px solid #000; width:200px; margin-bottom:4px; }
  .sig .lbl { font-size:11px; color:#9ca3af; }
  .foot-text { text-align:center; color:#6b7280; margin-top:24px; }
  .foot-text .co { font-size:18px; font-weight:700; color:#111827; }
  .foot-text .sub { font-size:13px; margin-top:4px; }
  .foot-text .thanks { font-size:12px; color:#9ca3af; margin-top:8px; }
  @media print { body { background:#fff; } .container { padding:0; } .no-print { display:none; } }
''';

String _buildA4Receipt(
  SaleReceiptData sale,
  String companyName,
  String address,
  String phone,
  String? logoUrl,
  String? stampUrl,
) {
  final totalSaleTax = sale.items.fold<double>(0, (s, i) => s + i.saleTax);
  final totalWthTax = sale.items.fold<double>(0, (s, i) => s + i.wthTax);
  final subtotal = sale.items.fold<double>(
    0,
    (s, i) => s + i.price * i.quantity,
  );
  final discount = sale.discount < 0 ? 0.0 : sale.discount;
  final total = subtotal + totalSaleTax + totalWthTax - discount;
  final inst = sale.installmentInfo;
  final isInst = sale.isInstallment && inst != null;
  final productNames = sale.items
      .map((i) => salesEscapeHtml(i.productName))
      .join(', ');

  if (isInst) {
    final i = inst;
    final status = i.status == 'completed' ? 'COMPLETED' : 'ACTIVE';
    final statusClass = i.status == 'completed'
        ? 'status-paid'
        : 'status-pending';
    final paidAmount = i.installmentAmount * i.paidInstallments;
    final remainingAmount = i.installmentAmount * i.remainingInstallments;
    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Installment Invoice #${sale.invoiceNumber}</title>
<style>$_a4Style</style></head>
<body>
<div class="container">
  ${_header(companyName, address, phone, logoUrl, 'INSTALLMENT INVOICE', 'Sale #: <span>${sale.invoiceNumber}</span><br/>Date: <span>${salesEscapeHtml(salesDateTime(sale.date))}</span><br/>Plan: <span>${salesEscapeHtml(i.planName)}</span><br/>Status: <span class="status-pill $statusClass">$status</span>')}
  <div class="amounts-box">
    <div class="box-header">Invoice Details</div>
    <div class="box-row info"><span class="label">Customer Name</span><span class="value">${salesEscapeHtml(sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName)}</span></div>
    <div class="box-row info"><span class="label">Payment Method</span><span class="value">${salesEscapeHtml(sale.paymentMethod.toUpperCase())}</span></div>
    <div class="box-row info"><span class="label">Products</span><span class="value" style="max-width:450px;text-align:right">${productNames.isEmpty ? '---' : productNames}</span></div>
    <div class="box-row info"><span class="label">Total Items</span><span class="value">${sale.items.fold<int>(0, (s, it) => s + it.quantity)}</span></div>
    ${discount > 0 ? '<div class="box-row info"><span class="label">Discount</span><span class="value">- PKR ${_fmtPKR2(discount)}</span></div>' : ''}
    <div class="divider"></div>
    <div class="box-row per-inst"><span class="label">Amount per Installment</span><span class="value">PKR ${_fmtPKR2(i.installmentAmount)}</span></div>
    <div class="box-row paid"><span class="label">Paid Installments</span><span class="value">${i.paidInstallments} / ${i.totalInstallments}</span></div>
    <div class="box-row remaining"><span class="label">Remaining Installments</span><span class="value">${i.remainingInstallments} / ${i.totalInstallments}</span></div>
    <div class="box-row paid"><span class="label">Paid Amount</span><span class="value">PKR ${_fmtPKR2(paidAmount)}</span></div>
    <div class="box-row remaining"><span class="label">Remaining Amount</span><span class="value">PKR ${_fmtPKR2(remainingAmount)}</span></div>
    <div class="box-row total"><span class="label">Per Installment Balance</span><span class="value">PKR ${_fmtPKR2(i.installmentAmount)}</span></div>
  </div>
  <footer>
    ${_signatures(stampUrl)}
    <div class="foot-text">
      <div class="co">${salesEscapeHtml(companyName)}</div>
      ${phone.isNotEmpty ? '<div class="sub">Phone: ${salesEscapeHtml(phone)}</div>' : ''}
      <div class="thanks">Thank you for your business!</div>
    </div>
  </footer>
</div>
${_printButton()}
</body></html>''';
  }

  final itemRows = sale.items.map((item) {
    final amount = item.price * item.quantity + item.saleTax + item.wthTax;
    return '''
      <tr>
        <td class="border border-gray-300 p-3">${salesEscapeHtml(item.productName)}</td>
        <td class="border border-gray-300 p-3 text-xs font-medium">${salesEscapeHtml(item.model)}</td>
        <td class="border border-gray-300 p-3 text-xs font-mono">${salesEscapeHtml(item.serialNumber)}</td>
        <td class="border border-gray-300 p-3 text-right">${_fmtPKR2(item.price)}</td>
        <td class="border border-gray-300 p-3 text-center font-semibold">${item.quantity}</td>
        <td class="border border-gray-300 p-3 text-right">${_fmtPKR2(item.price)}</td>
        <td class="border border-gray-300 p-3 text-right">${_fmtPKR2(item.saleTax)}</td>
        <td class="border border-gray-300 p-3 text-right">${_fmtPKR2(item.wthTax)}</td>
        <td class="border border-gray-300 p-3 text-right font-semibold">${_fmtPKR2(amount)}</td>
      </tr>''';
  }).join();

  final statusClass = sale.paymentMethod == 'cash' ? 'paid' : 'pending';
  final statusLabel =
      (sale.paymentMethod == 'cash' ? 'PAID' : sale.paymentMethod)
          .toUpperCase();

  return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Sale Receipt #${sale.invoiceNumber}</title>
<style>$_a4Style</style></head>
<body>
<div class="container">
  ${_header(companyName, address, phone, logoUrl, 'INVOICE', 'Sale #: <span>${sale.invoiceNumber}</span><br/>Date: <span>${salesEscapeHtml(salesDateTime(sale.date))}</span><br/>Status: <span class="status-pill status-$statusClass">${salesEscapeHtml(statusLabel)}</span>')}
  <table>
    <thead>
      <tr>
        <th>Product</th><th>Model</th><th>SN / MAC</th>
        <th class="text-right">Price</th><th class="text-center">Quantity</th>
        <th class="text-right">Unit Price</th><th class="text-right">Sale Tax</th>
        <th class="text-right">WTH</th><th class="text-right">Amount</th>
      </tr>
    </thead>
    <tbody>${itemRows.isEmpty ? '<tr><td colspan="9" style="text-align:center;color:#9ca3af">No items</td></tr>' : itemRows}</tbody>
  </table>
  <div class="summary">
    <table>
      <tbody>
        <tr><td>Subtotal</td><td style="text-align:right">PKR ${_fmtPKR2(subtotal)}</td></tr>
        <tr><td>Total Sale Tax</td><td style="text-align:right">PKR ${_fmtPKR2(totalSaleTax)}</td></tr>
        <tr><td>Total WTH</td><td style="text-align:right">PKR ${_fmtPKR2(totalWthTax)}</td></tr>
        ${discount > 0 ? '<tr><td>Discount</td><td style="text-align:right">- PKR ${_fmtPKR2(discount)}</td></tr>' : ''}
        <tr><td style="border-top:2px solid #111827;font-weight:700;text-transform:uppercase">Total</td><td style="border-top:2px solid #111827;font-weight:700;font-size:16px;text-align:right">PKR ${_fmtPKR2(total)}</td></tr>
      </tbody>
    </table>
  </div>
  <footer>
    ${_signatures(stampUrl)}
    <div class="foot-text">
      <div class="co">${salesEscapeHtml(companyName)}</div>
      ${phone.isNotEmpty ? '<div class="sub">Phone: ${salesEscapeHtml(phone)}</div>' : ''}
      <div class="thanks">Thank you for your business!</div>
    </div>
  </footer>
</div>
${_printButton()}
</body></html>''';
}

const String _thermalStyle = '''
  @page { size: 80mm auto; margin: 3mm; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: 'Courier New', monospace; color:#000; background:#fff; }
  .receipt { width:74mm; margin:0 auto; padding:4px 2px; font-size:12px; }
  .center { text-align:center; }
  .logo { text-align:center; margin-bottom:4px; }
  .logo img { max-width:40mm; max-height:15mm; object-fit:contain; }
  .name { font-size:16px; font-weight:700; }
  .muted { font-size:10px; color:#444; }
  .sep { border-top:1px dashed #000; margin:6px 0; }
  .row { display:flex; justify-content:space-between; margin:2px 0; font-size:11px; }
  .line { margin:3px 0; }
  .line-top { display:flex; justify-content:space-between; }
  .line-bot { font-size:10px; color:#444; }
  .amounts { margin-top:6px; padding-top:6px; border-top:2px solid #000; }
  .amounts .row { margin:3px 0; font-size:12px; }
  .amounts .row.total { border-top:1px dashed #000; margin-top:4px; padding-top:4px; font-weight:700; font-size:14px; }
  .grand { border-top:1px dashed #000; margin-top:4px; padding-top:4px; font-weight:700; font-size:15px; }
  .no-print { text-align:center; margin-top:10px; }
  .no-print button { padding:8px 16px; font-size:13px; cursor:pointer; }
  @media print { .no-print { display:none; } }
''';

String _thermalHeader(
  String companyName,
  String address,
  String phone,
  String? logoUrl,
) {
  return '''
  <div class="center">
    ${logoUrl != null ? '<div class="logo"><img src="${salesEscapeHtml(logoUrl)}" alt="Logo" onerror="this.style.display=\'none\'" /></div>' : ''}
    <div class="name">${salesEscapeHtml(companyName)}</div>
    ${address.isNotEmpty ? '<div class="muted">${salesEscapeHtml(address)}</div>' : ''}
    ${phone.isNotEmpty ? '<div class="muted">Tel: ${salesEscapeHtml(phone)}</div>' : ''}
  </div>''';
}

String _buildThermalReceipt(
  SaleReceiptData sale,
  String companyName,
  String address,
  String phone,
  String? logoUrl,
) {
  final subtotal =
      sale.totalAmount -
      sale.taxAmount +
      (sale.discount < 0 ? 0 : sale.discount);
  final discount = sale.discount < 0 ? 0.0 : sale.discount;
  final totalItems = sale.items.fold<int>(0, (s, i) => s + i.quantity);
  final inst = sale.installmentInfo;
  final isInst = sale.isInstallment && inst != null;
  final productNames = sale.items
      .map((i) => salesEscapeHtml(i.productName))
      .join(', ');

  if (isInst) {
    final i = inst;
    final paidAmount = i.installmentAmount * i.paidInstallments;
    final remainingAmount = i.installmentAmount * i.remainingInstallments;
    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Installment Receipt #${sale.invoiceNumber}</title>
<style>$_thermalStyle</style></head>
<body>
<div class="receipt">
  ${_thermalHeader(companyName, address, phone, logoUrl)}
  <div class="sep"></div>
  <div class="center muted">INSTALLMENT RECEIPT</div>
  <div class="sep"></div>
  <div class="row"><span class="muted">No:</span><span>${sale.invoiceNumber}</span></div>
  <div class="row"><span class="muted">Date:</span><span>${salesEscapeHtml(salesDateTime(sale.date))}</span></div>
  <div class="row"><span class="muted">Customer:</span><span>${salesEscapeHtml(sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName)}</span></div>
  <div class="row"><span class="muted">Plan:</span><span>${salesEscapeHtml(i.planName)}</span></div>
  <div class="row"><span class="muted">Pay:</span><span style="text-transform:uppercase">${salesEscapeHtml(sale.paymentMethod)}</span></div>
  <div class="row"><span class="muted">Products:</span><span>${productNames.isEmpty ? '---' : productNames}</span></div>
  <div class="row"><span class="muted">Total Items:</span><span>$totalItems</span></div>
  <div class="amounts">
    <div class="row"><span>Per Installment:</span><span>PKR ${_fmtPKR2(i.installmentAmount)}</span></div>
    ${discount > 0 ? '<div class="row"><span>Discount:</span><span>- PKR ${_fmtPKR2(discount)}</span></div>' : ''}
    <div class="row"><span>Total Installments:</span><span>${i.totalInstallments}</span></div>
    <div class="row"><span>Paid:</span><span>${i.paidInstallments} / ${i.totalInstallments} (PKR ${_fmtPKR2(paidAmount)})</span></div>
    <div class="row"><span>Remaining:</span><span>${i.remainingInstallments} / ${i.totalInstallments} (PKR ${_fmtPKR2(remainingAmount)})</span></div>
    <div class="row total"><span>TOTAL (PER INSTALLMENT):</span><span>PKR ${_fmtPKR2(i.installmentAmount)}</span></div>
  </div>
  <div class="sep"></div>
  <div class="center muted">Thank you for your purchase!</div>
  <div class="no-print"><button onclick="window.print()">Print</button></div>
</div>
</body></html>''';
  }

  final itemRows = sale.items.map((item) {
    return '''
      <div class="line">
        <div class="line-top"><span>${salesEscapeHtml(item.productName)}</span><span>${_fmtPKR2(item.price * item.quantity)}</span></div>
        <div class="line-bot">
          <span>${item.quantity} x ${_fmtPKR2(item.price)}</span>
          ${item.model.isNotEmpty ? '<div>Model: ${salesEscapeHtml(item.model)}</div>' : ''}
          ${item.serialNumber.isNotEmpty ? '<div>SN/MAC: ${salesEscapeHtml(item.serialNumber)}</div>' : ''}
        </div>
      </div>''';
  }).join();

  return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Receipt #${sale.invoiceNumber}</title>
<style>$_thermalStyle</style></head>
<body>
<div class="receipt">
  ${_thermalHeader(companyName, address, phone, logoUrl)}
  <div class="sep"></div>
  <div class="center muted">SALE RECEIPT</div>
  <div class="sep"></div>
  <div class="row"><span>No:</span><span>${sale.invoiceNumber}</span></div>
  <div class="row"><span>Date:</span><span>${salesEscapeHtml(salesDateTime(sale.date))}</span></div>
  <div class="row"><span>Cust:</span><span>${salesEscapeHtml(sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName)}</span></div>
  <div class="row"><span>Pay:</span><span style="text-transform:uppercase">${salesEscapeHtml(sale.paymentMethod)}</span></div>
  <div class="sep"></div>
  ${itemRows.isEmpty ? '<div class="muted center">No items</div>' : itemRows}
  <div class="sep"></div>
  <div class="row"><span>Total Items</span><span>$totalItems</span></div>
  <div class="row"><span>Subtotal</span><span>PKR ${_fmtPKR2(subtotal)}</span></div>
  <div class="row"><span>Tax</span><span>PKR ${_fmtPKR2(sale.taxAmount)}</span></div>
  ${discount > 0 ? '<div class="row"><span>Discount</span><span>- PKR ${_fmtPKR2(discount)}</span></div>' : ''}
  <div class="row grand"><span>TOTAL</span><span>PKR ${_fmtPKR2(sale.totalAmount)}</span></div>
  <div class="sep"></div>
  <div class="center muted">Thank you for your purchase!</div>
  <div class="no-print"><button onclick="window.print()">Print</button></div>
</div>
</body></html>''';
}

String _printButton() => '''
<div class="no-print" style="text-align:center;margin:16px 0">
  <button onclick="window.print()" style="padding:10px 22px;background:#111827;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:14px">Print Receipt</button>
</div>''';

/// Encodes a map as pretty JSON (used by the POS hold payload, matching the
/// web's `JSON.stringify`).
String salesJsonEncode(Object? value) => jsonEncode(value);

/// Renders filter controls as one or more rows, each of which scrolls
/// horizontally when its contents don't fit — the shared layout used by every
/// page in the Sales section.
class SalesFilterRows extends StatelessWidget {
  const SalesFilterRows({
    super.key,
    required this.rows,
    this.spacing = 12,
    this.rowSpacing = 12,
  });

  /// Each inner list is one horizontally-scrolling row of controls.
  final List<List<Widget>> rows;
  final double spacing;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: rowSpacing),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < rows[r].length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  rows[r][i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
