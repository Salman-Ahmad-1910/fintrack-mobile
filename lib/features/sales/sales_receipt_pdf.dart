import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/api_config.dart';
import 'sales_common.dart';
import 'sales_models.dart';

// ---------------------------------------------------------------------------
// Palette — identical hex values to the web `sale-receipt.tsx`.
// ---------------------------------------------------------------------------
const PdfColor _emerald = PdfColor.fromInt(0xFF059669); // #059669
const PdfColor _ink = PdfColor.fromInt(0xFF111827); // #111827
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280); // #6b7280
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB); // #d1d5db
const PdfColor _gray200 = PdfColor.fromInt(0xFFE5E7EB); // #e5e7eb
const PdfColor _gray400 = PdfColor.fromInt(0xFF9CA3AF); // #9ca3af
const PdfColor _green600 = PdfColor.fromInt(0xFF16A34A); // #16a34a
const PdfColor _green800 = PdfColor.fromInt(0xFF166534); // #166534
const PdfColor _greenBg = PdfColor.fromInt(0xFFDCFCE7); // #dcfce7
const PdfColor _yellowBg = PdfColor.fromInt(0xFFFEF9C3); // #fef9c3
const PdfColor _yellow800 = PdfColor.fromInt(0xFF854D0E); // #854d0e
const PdfColor _orange600 = PdfColor.fromInt(0xFFD97706); // #d97706
const PdfColor _blue700 = PdfColor.fromInt(0xFF1D4ED8); // #1d4ed8
const PdfColor _greenBgRow = PdfColor.fromInt(0xFFF0FDF4); // #f0fdf4
const PdfColor _thermalMuted = PdfColor.fromInt(0xFF444444); // #444 (thermal .muted)

/// CSS pixels → PDF points (1px = 0.75pt at 96dpi).
double _px(num v) => v * 0.75;

String _companyImage(String folder, String id) =>
    '${ApiConfig.base}/uploads/$folder/$id';

Future<pw.MemoryImage?> _loadImage(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300 || res.bodyBytes.isEmpty) {
      return null;
    }
    return pw.MemoryImage(res.bodyBytes);
  } catch (_) {
    return null;
  }
}

/// Builds the printable PDF (A4 or 80mm thermal) for a sale receipt,
/// mirroring the web `sale-receipt.tsx` output exactly.
Future<Uint8List> buildSalesReceiptPdf(
  SaleReceiptData sale,
  SalesCompany company, {
  String size = 'a4',
}) async {
  final logo = await _loadImage(
    company.logo.isNotEmpty ? _companyImage('company_images', company.id) : null,
  );
  final stamp = await _loadImage(
    company.stamp.isNotEmpty
        ? _companyImage('company_stamps', company.id)
        : null,
  );

  final title = sale.isInstallment
      ? 'Installment Invoice #${sale.invoiceNumber}'
      : 'Sale Receipt #${sale.invoiceNumber}';
  final doc = pw.Document(title: title);

  if (size == 'thermal') {
    final height = _measureThermalHeight(sale, company, logo);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          height,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (context) => pw.DefaultTextStyle(
          style: _monoBaseStyle(),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: _thermalContent(sale, company, logo),
          ),
        ),
      ),
    );
  } else {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (context) => _a4Content(sale, company, logo, stamp),
      ),
    );
  }

  return doc.save();
}

// ===========================================================================
// A4 layout
// ===========================================================================

pw.TextStyle _s({
  double px = 13,
  bool bold = false,
  PdfColor color = _ink,
  double? height,
  double? letterSpacing,
}) => pw.TextStyle(
  fontSize: _px(px),
  color: color,
  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  height: height,
  letterSpacing: letterSpacing,
);

List<pw.Widget> _a4Content(
  SaleReceiptData sale,
  SalesCompany company,
  pw.MemoryImage? logo,
  pw.MemoryImage? stamp,
) {
  final companyName = company.name.isEmpty ? 'Your Company' : company.name;
  final isInst = sale.isInstallment && sale.installmentInfo != null;

  if (isInst) {
    final i = sale.installmentInfo!;
    final discount = sale.discount < 0 ? 0.0 : sale.discount;
    final paidAmount = i.installmentAmount * i.paidInstallments;
    final remainingAmount = i.installmentAmount * i.remainingInstallments;
    final productNames = sale.items.map((it) => it.productName).join(', ');
    final totalItems = sale.items.fold<int>(0, (s, it) => s + it.quantity);
    final completed = i.status == 'completed';

    return [
      _a4Header(
        companyName: companyName,
        address: company.address,
        phone: company.contact1,
        logo: logo,
        title: 'INSTALLMENT INVOICE',
        meta: [
          _metaLine('Sale #:', '${sale.invoiceNumber}'),
          _metaLine('Date:', salesDateTime(sale.date)),
          _metaLine('Plan:', i.planName),
          _metaStatusLine(
            'Status:',
            completed ? 'COMPLETED' : 'ACTIVE',
            completed,
          ),
        ],
      ),
      pw.SizedBox(height: _px(32)),
      _a4AmountsBox([
        _BoxRow('Customer Name', sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName),
        _BoxRow('Payment Method', sale.paymentMethod.toUpperCase()),
        _BoxRow('Products', productNames.isEmpty ? '---' : productNames),
        _BoxRow('Total Items', '$totalItems'),
        if (discount > 0) _BoxRow('Discount', '- PKR ${salesMoney(discount)}'),
        const _BoxRow.divider(),
        _BoxRow('Amount per Installment', 'PKR ${salesMoney(i.installmentAmount)}', valueColor: _blue700),
        _BoxRow('Paid Installments', '${i.paidInstallments} / ${i.totalInstallments}', valueColor: _green600),
        _BoxRow('Remaining Installments', '${i.remainingInstallments} / ${i.totalInstallments}', valueColor: _orange600),
        _BoxRow('Paid Amount', 'PKR ${salesMoney(paidAmount)}', valueColor: _green600),
        _BoxRow('Remaining Amount', 'PKR ${salesMoney(remainingAmount)}', valueColor: _orange600),
        _BoxRow('Per Installment Balance', 'PKR ${salesMoney(i.installmentAmount)}', valueColor: _emerald, isTotal: true),
      ]),
      pw.SizedBox(height: _px(32)),
      _a4Footer(companyName, company.contact1, stamp),
    ];
  }

  final items = sale.items;
  final totalSaleTax = items.fold<double>(0, (s, i) => s + i.saleTax);
  final totalWthTax = items.fold<double>(0, (s, i) => s + i.wthTax);
  final subtotal = items.fold<double>(0, (s, i) => s + i.price * i.quantity);
  final discount = sale.discount < 0 ? 0.0 : sale.discount;
  final total = subtotal + totalSaleTax + totalWthTax - discount;
  final statusPaid = sale.paymentMethod == 'cash';

  final rows = <List<String>>[
    for (final item in items)
      [
        item.productName,
        item.model,
        item.serialNumber,
        salesMoney(item.price),
        '${item.quantity}',
        salesMoney(item.price),
        salesMoney(item.saleTax),
        salesMoney(item.wthTax),
        salesMoney(item.price * item.quantity + item.saleTax + item.wthTax),
      ],
  ];

  final alignments = <int, pw.AlignmentGeometry>{
    0: pw.Alignment.centerLeft,
    1: pw.Alignment.centerLeft,
    2: pw.Alignment.centerLeft,
    3: pw.Alignment.centerRight,
    4: pw.Alignment.center,
    5: pw.Alignment.centerRight,
    6: pw.Alignment.centerRight,
    7: pw.Alignment.centerRight,
    8: pw.Alignment.centerRight,
  };

  return [
    _a4Header(
      companyName: companyName,
      address: company.address,
      phone: company.contact1,
      logo: logo,
      title: 'INVOICE',
      meta: [
        _metaLine('Sale #:', '${sale.invoiceNumber}'),
        _metaLine('Date:', salesDateTime(sale.date)),
        _metaStatusLine(
          'Status:',
          statusPaid ? 'PAID' : sale.paymentMethod.toUpperCase(),
          statusPaid,
        ),
      ],
    ),
    pw.SizedBox(height: _px(32)),
    if (rows.isEmpty)
      pw.Center(
        child: pw.Padding(
          padding: pw.EdgeInsets.all(_px(10)),
          child: pw.Text('No items', style: _s(color: _gray400)),
        ),
      )
    else
      pw.TableHelper.fromTextArray(
        headers: const [
          'PRODUCT',
          'MODEL',
          'SN / MAC',
          'PRICE',
          'QUANTITY',
          'UNIT PRICE',
          'SALE TAX',
          'WTH',
          'AMOUNT',
        ],
        data: rows,
        headerStyle: _s(px: 11, bold: true, color: PdfColors.white, height: 1.2, letterSpacing: _px(0.5)),
        headerDecoration: const pw.BoxDecoration(color: _emerald),
        headerAlignments: alignments,
        cellStyle: _s(px: 13, height: 1.2),
        cellAlignments: alignments,
        cellPadding: pw.EdgeInsets.all(_px(10)),
        border: pw.TableBorder.all(color: _line, width: _px(1)),
      ),
    pw.SizedBox(height: _px(16)),
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: _px(260),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _summaryRow('Subtotal', 'PKR ${salesMoney(subtotal)}'),
            _summaryRow('Total Sale Tax', 'PKR ${salesMoney(totalSaleTax)}'),
            _summaryRow('Total WTH', 'PKR ${salesMoney(totalWthTax)}'),
            if (discount > 0)
              _summaryRow('Discount', '- PKR ${salesMoney(discount)}'),
            _summaryTotal('TOTAL', 'PKR ${salesMoney(total)}'),
          ],
        ),
      ),
    ),
    pw.SizedBox(height: _px(48)),
    _a4Footer(companyName, company.contact1, stamp),
  ];
}

pw.Widget _a4Header({
  required String companyName,
  required String address,
  required String phone,
  required pw.MemoryImage? logo,
  required String title,
  required List<pw.Widget> meta,
}) {
  return pw.Container(
    padding: pw.EdgeInsets.only(bottom: _px(24)),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: _ink, width: _px(3)),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.SizedBox(width: _px(60), height: _px(60), child: pw.Image(logo, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: _px(16)),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName, style: _s(px: 24, bold: true)),
                    if (address.isNotEmpty)
                      pw.Text(address, style: _s(px: 13, color: _muted, height: 1.5)),
                    if (phone.isNotEmpty)
                      pw.Text('Phone: $phone', style: _s(px: 13, color: _muted, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: _px(16)),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title,
              style: _s(px: 36, bold: true, color: _emerald, letterSpacing: _px(2)),
            ),
            pw.SizedBox(height: _px(8)),
            for (final m in meta) m,
          ],
        ),
      ],
    ),
  );
}

pw.Widget _metaLine(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.only(top: _px(2)),
  child: pw.RichText(
    textAlign: pw.TextAlign.right,
    text: pw.TextSpan(
      style: _s(px: 13, color: _muted, height: 1.8),
      children: [
        pw.TextSpan(text: '$label '),
        pw.TextSpan(
          text: value,
          style: _s(px: 13, bold: true, color: _ink, height: 1.8),
        ),
      ],
    ),
  ),
);

pw.Widget _metaStatusLine(String label, String text, bool positive) => pw.Padding(
  padding: pw.EdgeInsets.only(top: _px(2)),
  child: pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text('$label ', style: _s(px: 13, color: _muted, height: 1.8)),
      pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: _px(8), vertical: _px(2)),
        decoration: pw.BoxDecoration(
          color: positive ? _greenBg : _yellowBg,
          borderRadius: pw.BorderRadius.circular(_px(4)),
        ),
        child: pw.Text(
          text.toUpperCase(),
          style: _s(px: 11, bold: true, color: positive ? _green800 : _yellow800, height: 1.2),
        ),
      ),
    ],
  ),
);

pw.Widget _summaryRow(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(vertical: _px(3)),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: _s(px: 13, color: _muted, height: 1.2)),
      pw.Text(value, style: _s(px: 13, color: _muted, height: 1.2)),
    ],
  ),
);

pw.Widget _summaryTotal(String label, String value) => pw.Container(
  padding: pw.EdgeInsets.only(top: _px(6)),
  decoration: pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: _ink, width: _px(2))),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(label.toUpperCase(), style: _s(px: 13, bold: true, color: _ink, height: 1.2)),
      pw.Text(value, style: _s(px: 16, bold: true, color: _ink, height: 1.2)),
    ],
  ),
);

/// A row inside the installment `amounts-box`.
class _BoxRow {
  _BoxRow(this.label, this.value, {this.valueColor = _ink, this.isTotal = false})
    : divider = false;
  const _BoxRow.divider()
    : label = '',
      value = '',
      valueColor = _emerald,
      isTotal = false,
      divider = true;

  final String label;
  final String value;
  final PdfColor valueColor;
  final bool isTotal;
  final bool divider;
}

pw.Widget _a4AmountsBox(List<_BoxRow> rows) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _emerald, width: _px(2)),
      borderRadius: pw.BorderRadius.circular(_px(10)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _emerald,
          padding: pw.EdgeInsets.symmetric(horizontal: _px(16), vertical: _px(10)),
          child: pw.Text(
            'INVOICE DETAILS',
            style: _s(px: 14, bold: true, color: PdfColors.white, letterSpacing: _px(1)),
          ),
        ),
        for (final row in rows)
          if (row.divider)
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _emerald, width: _px(2))),
              ),
            )
          else
            pw.Container(
              decoration: pw.BoxDecoration(
                color: row.isTotal ? _greenBgRow : null,
                border: pw.Border(
                  bottom: pw.BorderSide(color: _gray200, width: _px(1)),
                ),
              ),
              padding: pw.EdgeInsets.symmetric(horizontal: _px(16), vertical: _px(10)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    row.label,
                    style: _s(px: row.isTotal ? 15 : 13, bold: row.isTotal, color: row.isTotal ? _ink : _muted, height: 1.2),
                  ),
                  pw.SizedBox(width: _px(12)),
                  pw.Flexible(
                    child: pw.Text(
                      row.value,
                      textAlign: pw.TextAlign.right,
                      style: _s(px: row.isTotal ? 15 : 13, bold: true, color: row.valueColor, height: 1.2),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

pw.Widget _a4Footer(String companyName, String phone, pw.MemoryImage? stamp) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: pw.EdgeInsets.only(top: _px(24)),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: _px(1))),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (stamp != null)
                      pw.SizedBox(
                        width: _px(180),
                        height: _px(80),
                        child: pw.Image(stamp, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Container(width: _px(200), height: _px(1), color: PdfColors.black),
                    pw.SizedBox(height: _px(4)),
                    pw.Text('Company Stamp', style: _s(px: 11, color: _gray400)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: _px(200), height: _px(1), color: PdfColors.black),
                    pw.SizedBox(height: _px(4)),
                    pw.Text('Authorized Signature', style: _s(px: 11, color: _gray400)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: _px(24)),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(companyName, style: _s(px: 18, bold: true)),
                  if (phone.isNotEmpty)
                    pw.Text('Phone: $phone', style: _s(px: 13, color: _muted)),
                  pw.SizedBox(height: _px(8)),
                  pw.Text('Thank you for your business!', style: _s(px: 12, color: _gray400)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ===========================================================================
// Thermal (80mm) layout — Courier/monospace, matching the web.
// ===========================================================================

/// Base monospace style. `inherit: false` makes this fully replace the theme
/// default so `fontWeight: bold` resolves to Courier-Bold (not Helvetica-Bold).
pw.TextStyle _monoBaseStyle() => pw.TextStyle(
  inherit: false,
  color: PdfColors.black,
  fontNormal: pw.Font.courier(),
  fontBold: pw.Font.courierBold(),
  fontItalic: pw.Font.courierOblique(),
  fontBoldItalic: pw.Font.courierBoldOblique(),
  fontFallback: const [],
  fontSize: _px(12),
  fontWeight: pw.FontWeight.normal,
  fontStyle: pw.FontStyle.normal,
  letterSpacing: 0,
  wordSpacing: 1,
  lineSpacing: 0,
  height: 1.2,
  decoration: pw.TextDecoration.none,
  decorationColor: null,
  decorationStyle: pw.TextDecorationStyle.solid,
  decorationThickness: 1,
  renderingMode: PdfTextRenderingMode.fill,
);

pw.TextStyle _mono({double px = 12, bool bold = false, PdfColor color = PdfColors.black}) =>
    pw.TextStyle(
      fontSize: _px(px),
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

/// Measures the natural height so the page (and thermal roll) grows with the
/// number of items instead of using a fixed size.
double _measureThermalHeight(
  SaleReceiptData sale,
  SalesCompany company,
  pw.MemoryImage? logo,
) {
  const usableWidth = 74 * PdfPageFormat.mm; // 80mm - 3mm margins each side
  try {
    final measurer = pw.Document();
    final context = pw.Context(document: measurer.document);
    final column = pw.Theme(
      data: pw.ThemeData.base(),
      child: pw.DefaultTextStyle(
        style: _monoBaseStyle(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: _thermalContent(sale, company, logo),
        ),
      ),
    );
    column.layout(
      context,
      const pw.BoxConstraints(minWidth: usableWidth, maxWidth: usableWidth),
    );
    final contentHeight = column.box?.height ?? 0;
    if (contentHeight <= 0) return 200 * PdfPageFormat.mm;
    // Account for the top/bottom page margins (3mm each) plus a small tail.
    return contentHeight + (6 * PdfPageFormat.mm) + (3 * PdfPageFormat.mm);
  } catch (_) {
    return 200 * PdfPageFormat.mm;
  }
}

List<pw.Widget> _thermalContent(
  SaleReceiptData sale,
  SalesCompany company,
  pw.MemoryImage? logo,
) {
  final companyName = company.name.isEmpty ? 'Your Company' : company.name;
  final isInst = sale.isInstallment && sale.installmentInfo != null;

  final content = <pw.Widget>[
    _thermalHeader(companyName, company.address, company.contact1, logo),
    _dashed(),
    pw.Center(
      child: pw.Text(
        isInst ? 'INSTALLMENT RECEIPT' : 'SALE RECEIPT',
        style: _mono(px: 10, color: _thermalMuted),
      ),
    ),
    _dashed(),
  ];

  if (isInst) {
    final i = sale.installmentInfo!;
    final discount = sale.discount < 0 ? 0.0 : sale.discount;
    final paidAmount = i.installmentAmount * i.paidInstallments;
    final remainingAmount = i.installmentAmount * i.remainingInstallments;
    final productNames = sale.items.map((it) => it.productName).join(', ');
    final totalItems = sale.items.fold<int>(0, (s, it) => s + it.quantity);

    content.addAll([
      _tRow('No:', '${sale.invoiceNumber}'),
      _tRow('Date:', salesDateTime(sale.date)),
      _tRow('Customer:', sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName),
      _tRow('Plan:', i.planName),
      _tRow('Pay Method:', sale.paymentMethod.toUpperCase()),
      _tRow('Products:', productNames.isEmpty ? '---' : productNames),
      _tRow('Total Items:', '$totalItems'),
      // amounts block: border-top:2px solid #000
      pw.Container(
        margin: pw.EdgeInsets.only(top: _px(6)),
        padding: pw.EdgeInsets.only(top: _px(6)),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: _px(2))),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _tAmountRow('Per Installment:', 'PKR ${salesMoney(i.installmentAmount)}'),
            if (discount > 0) _tAmountRow('Discount:', '- PKR ${salesMoney(discount)}'),
            _tAmountRow('Total Installments:', '${i.totalInstallments}'),
            _tAmountRow('Paid:', '${i.paidInstallments} / ${i.totalInstallments} (PKR ${salesMoney(paidAmount)})'),
            _tAmountRow('Remaining:', '${i.remainingInstallments} / ${i.totalInstallments} (PKR ${salesMoney(remainingAmount)})'),
            _tAmountTotal('TOTAL (PER INSTALLMENT):', 'PKR ${salesMoney(i.installmentAmount)}'),
          ],
        ),
      ),
    ]);
  } else {
    final subtotal = sale.totalAmount - sale.taxAmount + (sale.discount < 0 ? 0 : sale.discount);
    final discount = sale.discount < 0 ? 0.0 : sale.discount;
    final totalItems = sale.items.fold<int>(0, (s, i) => s + i.quantity);

    content.addAll([
      _tPlainRow('No:', '${sale.invoiceNumber}'),
      _tPlainRow('Date:', salesDateTime(sale.date)),
      _tPlainRow('Cust:', sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName),
      _tPlainRow('Pay:', sale.paymentMethod.toUpperCase()),
      _dashed(),
      if (sale.items.isEmpty)
        pw.Center(child: pw.Text('No items', style: _mono(px: 10, color: _thermalMuted)))
      else
        for (final item in sale.items) _thermalItem(item),
      _dashed(),
      _tPlainRow('Total Items', '$totalItems'),
      _tPlainRow('Subtotal', 'PKR ${salesMoney(subtotal)}'),
      _tPlainRow('Tax', 'PKR ${salesMoney(sale.taxAmount)}'),
      if (discount > 0) _tPlainRow('Discount', '- PKR ${salesMoney(discount)}'),
      _tGrandRow('TOTAL', 'PKR ${salesMoney(sale.totalAmount)}'),
      pw.SizedBox(height: _px(8)),
      pw.Center(
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(
            errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
          ),
          data: jsonEncode({
            'id': sale.id,
            'total': sale.totalAmount,
            'date': sale.date,
          }),
          width: _px(120),
          height: _px(120),
          drawText: false,
        ),
      ),
      pw.SizedBox(height: _px(4)),
      pw.Center(child: pw.Text('Scan to verify', style: _mono(px: 10, color: _thermalMuted))),
    ]);
  }

  content.addAll([
    _dashed(),
    pw.Center(
      child: pw.Text(
        'Thank you for your purchase!',
        style: _mono(px: 10, color: _thermalMuted),
      ),
    ),
    pw.SizedBox(height: _px(12)),
  ]);

  return content;
}

pw.Widget _thermalHeader(
  String companyName,
  String address,
  String phone,
  pw.MemoryImage? logo,
) {
  return pw.Center(
    child: pw.Column(
      children: [
        if (logo != null) ...[
          pw.SizedBox(
            width: 40 * PdfPageFormat.mm,
            height: 15 * PdfPageFormat.mm,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: _px(4)),
        ],
        pw.Text(
          companyName,
          textAlign: pw.TextAlign.center,
          style: _mono(px: 16, bold: true),
        ),
        if (address.isNotEmpty)
          pw.Text(
            address,
            textAlign: pw.TextAlign.center,
            style: _mono(px: 10, color: _thermalMuted),
          ),
        if (phone.isNotEmpty)
          pw.Text(
            'Tel: $phone',
            textAlign: pw.TextAlign.center,
            style: _mono(px: 10, color: _thermalMuted),
          ),
      ],
    ),
  );
}

/// Regular thermal item line: name + amount, then `qty x price`, Model, SN/MAC.
pw.Widget _thermalItem(SalesItem item) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: _px(3)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(item.productName, style: _mono(px: 12)),
            ),
            pw.SizedBox(width: _px(4)),
            pw.Text(salesMoney(item.price * item.quantity), style: _mono(px: 12)),
          ],
        ),
        pw.Text('${item.quantity} x ${salesMoney(item.price)}', style: _mono(px: 10, color: _thermalMuted)),
        if (item.model.isNotEmpty)
          pw.Text('Model: ${item.model}', style: _mono(px: 10, color: _thermalMuted)),
        if (item.serialNumber.isNotEmpty)
          pw.Text('SN/MAC: ${item.serialNumber}', style: _mono(px: 10, color: _thermalMuted)),
      ],
    ),
  );
}

/// Installment `.row` (`.lbl` muted, `.val` bold), margin 2px.
pw.Widget _tRow(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(vertical: _px(2)),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: _mono(px: 11, color: _thermalMuted)),
      pw.SizedBox(width: _px(4)),
      pw.Flexible(
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.right,
          style: _mono(px: 11, bold: true),
        ),
      ),
    ],
  ),
);

/// Regular `.row` (both plain), margin 2px.
pw.Widget _tPlainRow(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(vertical: _px(2)),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: _mono(px: 12)),
      pw.SizedBox(width: _px(4)),
      pw.Flexible(
        child: pw.Text(value, textAlign: pw.TextAlign.right, style: _mono(px: 12)),
      ),
    ],
  ),
);

/// Installment `.amounts .row` (margin 3px, 12px).
pw.Widget _tAmountRow(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(vertical: _px(3)),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: _mono(px: 12, color: _thermalMuted)),
      pw.SizedBox(width: _px(4)),
      pw.Flexible(
        child: pw.Text(value, textAlign: pw.TextAlign.right, style: _mono(px: 12, bold: true)),
      ),
    ],
  ),
);

/// Installment `.amounts .row.total` (dashed top, bold 14px).
pw.Widget _tAmountTotal(String label, String value) => pw.Container(
  margin: pw.EdgeInsets.only(top: _px(4)),
  padding: pw.EdgeInsets.only(top: _px(4)),
  decoration: pw.BoxDecoration(
    border: pw.Border(
      top: pw.BorderSide(color: PdfColors.black, width: _px(1), style: pw.BorderStyle.dashed),
    ),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Flexible(child: pw.Text(label, style: _mono(px: 14, bold: true))),
      pw.SizedBox(width: _px(4)),
      pw.Text(value, style: _mono(px: 14, bold: true)),
    ],
  ),
);

/// Regular `.grand` (dashed top, bold 15px).
pw.Widget _tGrandRow(String label, String value) => pw.Container(
  margin: pw.EdgeInsets.only(top: _px(4)),
  padding: pw.EdgeInsets.only(top: _px(4)),
  decoration: pw.BoxDecoration(
    border: pw.Border(
      top: pw.BorderSide(color: PdfColors.black, width: _px(1), style: pw.BorderStyle.dashed),
    ),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: _mono(px: 15, bold: true)),
      pw.Text(value, style: _mono(px: 15, bold: true)),
    ],
  ),
);

pw.Widget _dashed() {
  return pw.Container(
    margin: pw.EdgeInsets.symmetric(vertical: _px(6)),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(
          color: PdfColors.black,
          width: _px(1),
          style: pw.BorderStyle.dashed,
        ),
      ),
    ),
  );
}
