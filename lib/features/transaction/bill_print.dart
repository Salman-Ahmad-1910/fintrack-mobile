import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/api_config.dart';
import '../sales/sales_common.dart';
import 'transaction_models.dart';

/// One grouped bill entry — mirrors the web `BillRow` from
/// `transaction/bill-creator/_components/client-page.tsx`.
class BillRow {
  BillRow({
    required this.id,
    required this.month,
    required this.year,
    required this.amount,
    required this.subscribers,
    required this.connectionType,
    required this.sublocality,
    required this.connections,
  });

  final String id;
  final String month;
  final String year;
  final double amount;
  final int subscribers;
  final String connectionType;
  final String sublocality;
  final List<TxConnection> connections;
}

// ---------------------------------------------------------------------------
// Palette (mirrors the web Tailwind colours used on the print page)
// ---------------------------------------------------------------------------
const PdfColor _ink = PdfColor.fromInt(0xFF111827);
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _emerald = PdfColor.fromInt(0xFF059669);
const PdfColor _footerGray = PdfColor.fromInt(0xFF9CA3AF);
const PdfColor _tfootBg = PdfColor.fromInt(0xFFF9FAFB);

double _px(num v) => v * 0.75;

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

/// Builds the A4 bill PDF that mirrors
/// `transaction/bill-creator/print/page.tsx`.
Future<Uint8List> buildBillPdf({
  required List<BillRow> rows,
  required SalesCompany company,
  required String monthLabel,
  required String yearLabel,
  required String billTypeLabel,
  String? sublocalityLabel,
  DateTime? now,
}) async {
  final logo = await _loadImage(
    company.logo.isNotEmpty ? _companyImage('company_images', company.id) : null,
  );
  final stamp = await _loadImage(
    company.stamp.isNotEmpty
        ? _companyImage('company_stamps', company.id)
        : null,
  );

  final totalAmount = rows.fold<double>(0, (s, r) => s + r.amount);
  final totalSubscribers = rows.fold<int>(0, (s, r) => s + r.subscribers);

  final doc = pw.Document(title: 'Bill');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(15 * PdfPageFormat.mm),
      build: (context) => [
        _header(
          company,
          logo,
          monthLabel: monthLabel,
          yearLabel: yearLabel,
          billTypeLabel: billTypeLabel,
          sublocalityLabel: sublocalityLabel,
          now: now ?? DateTime.now(),
        ),
        pw.SizedBox(height: _px(32)),
        _table(rows, typeBadge: _typeColors),
        pw.SizedBox(height: _px(24)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Total Subscribers: ',
                        style: _s(px: 13, color: _muted),
                      ),
                      pw.TextSpan(
                        text: '$totalSubscribers',
                        style: _s(px: 13, bold: true),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: _px(4)),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Total Amount: ',
                        style: _s(px: 13, color: _muted),
                      ),
                      pw.TextSpan(
                        text: 'PKR ${salesNumber(totalAmount)}',
                        style: _s(px: 20, bold: true, color: _emerald),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: _px(48)),
        _footer(company, stamp),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(
  SalesCompany company,
  pw.MemoryImage? logo, {
  required String monthLabel,
  required String yearLabel,
  required String billTypeLabel,
  String? sublocalityLabel,
  required DateTime now,
}) {
  final name = company.name.isEmpty ? 'Company Name' : company.name;
  final dateLabel = _formatDate(now);
  return pw.Container(
    padding: pw.EdgeInsets.only(bottom: _px(24)),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _ink, width: _px(3))),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.SizedBox(
                  width: _px(60),
                  height: _px(60),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: _px(16)),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: _s(px: 24, bold: true)),
                    if (company.address.isNotEmpty)
                      pw.Text(company.address,
                          style: _s(px: 13, color: _muted, height: 1.5)),
                    if (company.contact1.isNotEmpty)
                      pw.Text('Phone: ${company.contact1}',
                          style: _s(px: 13, color: _muted, height: 1.5)),
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
              'BILL',
              style: _s(
                px: 32,
                bold: true,
                color: _emerald,
                letterSpacing: _px(2),
              ),
            ),
            pw.SizedBox(height: _px(12)),
            _metaLine('Date:', dateLabel),
            _metaLine(
              'Period:',
              '$monthLabel${yearLabel.isEmpty ? '' : ' $yearLabel'}',
            ),
            _metaLine('Type:', billTypeLabel),
            if (sublocalityLabel != null && sublocalityLabel.isNotEmpty)
              _metaLine('Sublocality:', sublocalityLabel),
          ],
        ),
      ],
    ),
  );
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = d.day.toString().padLeft(2, '0');
  return '$day ${months[d.month - 1]} ${d.year}';
}

pw.Widget _metaLine(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.only(bottom: _px(2)),
  child: pw.RichText(
    textAlign: pw.TextAlign.right,
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: '$label ', style: _s(px: 13, color: _muted, height: 1.6)),
        pw.TextSpan(
          text: value,
          style: _s(px: 13, bold: true, height: 1.6),
        ),
      ],
    ),
  ),
);

({PdfColor bg, PdfColor text, PdfColor border}) _typeColors(String type) {
  switch (type) {
    case 'Internet':
      return (
        bg: PdfColor.fromInt(0xFFDBEAFE),
        text: PdfColor.fromInt(0xFF1D4ED8),
        border: PdfColor.fromInt(0xFFBFDBFE),
      );
    case 'Cable':
      return (
        bg: PdfColor.fromInt(0xFFFFEDD5),
        text: PdfColor.fromInt(0xFFC2410C),
        border: PdfColor.fromInt(0xFFFED7AA),
      );
    case 'Both':
      return (
        bg: PdfColor.fromInt(0xFFD1FAE5),
        text: PdfColor.fromInt(0xFF047857),
        border: PdfColor.fromInt(0xFFA7F3D0),
      );
    default:
      return (
        bg: PdfColor.fromInt(0xFFF3F4F6),
        text: PdfColor.fromInt(0xFF374151),
        border: PdfColor.fromInt(0xFFE5E7EB),
      );
  }
}

pw.Widget _table(
  List<BillRow> rows, {
  required ({PdfColor bg, PdfColor text, PdfColor border}) Function(String)
  typeBadge,
}) {
  final totalAmount = rows.fold<double>(0, (s, r) => s + r.amount);
  final totalSubscribers = rows.fold<int>(0, (s, r) => s + r.subscribers);

  pw.Widget head(String text, pw.TextAlign align) => pw.Padding(
    padding: pw.EdgeInsets.all(_px(10)),
    child: pw.Text(
      text,
      textAlign: align,
      style: _s(
        px: 10,
        bold: true,
        color: PdfColors.white,
        letterSpacing: _px(0.5),
      ),
    ),
  );

  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: _px(1)),
    columnWidths: const {
      0: pw.FlexColumnWidth(0.5),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(1.5),
      4: pw.FlexColumnWidth(1.1),
      5: pw.FlexColumnWidth(1.1),
      6: pw.FlexColumnWidth(1.5),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _emerald),
        children: [
          head('#', pw.TextAlign.center),
          head('Month', pw.TextAlign.left),
          head('Year', pw.TextAlign.left),
          head('Amount (PKR)', pw.TextAlign.right),
          head('Subscribers', pw.TextAlign.center),
          head('Type', pw.TextAlign.center),
          head('Sublocality', pw.TextAlign.left),
        ],
      ),
      for (var i = 0; i < rows.length; i++)
        _bodyRow(rows[i], i, typeBadge),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _tfootBg),
        children: [
          _footCell('TOTAL', pw.TextAlign.left),
          _footCell('', pw.TextAlign.left),
          _footCell('', pw.TextAlign.left),
          _footCell('PKR ${salesNumber(totalAmount)}', pw.TextAlign.right),
          _footCell('$totalSubscribers', pw.TextAlign.center),
          _footCell('', pw.TextAlign.left),
          _footCell('', pw.TextAlign.left),
        ],
      ),
    ],
  );
}

pw.TableRow _bodyRow(
  BillRow row,
  int idx,
  ({PdfColor bg, PdfColor text, PdfColor border}) Function(String) typeBadge,
) {
  final c = typeBadge(row.connectionType);
  return pw.TableRow(
    children: [
      _cell('${idx + 1}', pw.TextAlign.center, _muted, true),
      _cell(row.month, pw.TextAlign.left, _ink, true),
      _cell(row.year, pw.TextAlign.left, _ink, false),
      _cell(salesNumber(row.amount), pw.TextAlign.right, _ink, true),
      _cell('${row.subscribers}', pw.TextAlign.center, _ink, true),
      pw.Padding(
        padding: pw.EdgeInsets.all(_px(8)),
        child: pw.Center(
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: _px(10),
              vertical: _px(2),
            ),
            decoration: pw.BoxDecoration(
              color: c.bg,
              borderRadius: pw.BorderRadius.circular(_px(10)),
              border: pw.Border.all(color: c.border, width: _px(1)),
            ),
            child: pw.Text(
              row.connectionType,
              style: _s(px: 11, bold: true, color: c.text, height: 1.2),
            ),
          ),
        ),
      ),
      _cell(row.sublocality, pw.TextAlign.left, _ink, false),
    ],
  );
}

pw.Widget _cell(String text, pw.TextAlign align, PdfColor color, bool bold) =>
    pw.Padding(
      padding: pw.EdgeInsets.all(_px(12)),
      child: pw.Text(
        text,
        textAlign: align,
        style: _s(px: 13, bold: bold, color: color, height: 1.2),
      ),
    );

pw.Widget _footCell(String text, pw.TextAlign align) =>
    pw.Padding(
      padding: pw.EdgeInsets.all(_px(12)),
      child: pw.Text(
        text,
        textAlign: align,
        style: _s(px: text == 'TOTAL' ? 13 : 16, bold: true),
      ),
    );

pw.Widget _footer(SalesCompany company, pw.MemoryImage? stamp) {
  final name = company.name.isEmpty ? 'Company Name' : company.name;
  return pw.Container(
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
                  pw.Container(
                      width: _px(200), height: _px(1), color: PdfColors.black),
                pw.SizedBox(height: _px(4)),
                pw.Text('Company Stamp', style: _s(px: 11, color: _footerGray)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                    width: _px(200), height: _px(1), color: PdfColors.black),
                pw.SizedBox(height: _px(4)),
                pw.Text('Authorized Signature',
                    style: _s(px: 11, color: _footerGray)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: _px(24)),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(name, style: _s(px: 18, bold: true)),
              if (company.contact1.isNotEmpty)
                pw.Text('Phone: ${company.contact1}',
                    style: _s(px: 13, color: _muted)),
              pw.SizedBox(height: _px(4)),
              pw.Text(
                'This is a computer-generated bill and does not require a signature',
                style: _s(px: 11, color: _footerGray),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ===========================================================================
// Preview screen
// ===========================================================================

/// In-app A4 preview + print, mirroring
/// `transaction/bill-creator/print/page.tsx`.
class BillPrintPreviewScreen extends StatelessWidget {
  const BillPrintPreviewScreen({
    super.key,
    required this.rows,
    required this.company,
    required this.monthLabel,
    required this.yearLabel,
    required this.billTypeLabel,
    this.sublocalityLabel,
  });

  final List<BillRow> rows;
  final SalesCompany company;
  final String monthLabel;
  final String yearLabel;
  final String billTypeLabel;
  final String? sublocalityLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Creator - Print Preview')),
      body: PdfPreview(
        build: (format) => buildBillPdf(
          rows: rows,
          company: company,
          monthLabel: monthLabel,
          yearLabel: yearLabel,
          billTypeLabel: billTypeLabel,
          sublocalityLabel: sublocalityLabel,
        ),
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        dynamicLayout: false,
      ),
    );
  }
}
