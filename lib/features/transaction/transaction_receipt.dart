import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/api_config.dart';
import '../sales/sales_bluetooth_printer.dart';
import '../sales/sales_common.dart';
import '../sales/sales_escpos.dart';

// ---------------------------------------------------------------------------
// Accent palette — mirrors the web collection / subscriber print dialogs.
// ---------------------------------------------------------------------------
enum TxAccent { emerald, blue, amber }

PdfColor _accentBright(TxAccent a) {
  switch (a) {
    case TxAccent.emerald:
      return PdfColor.fromInt(0xFF059669);
    case TxAccent.blue:
      return PdfColor.fromInt(0xFF2563EB);
    case TxAccent.amber:
      return PdfColor.fromInt(0xFFD97706);
  }
}

const PdfColor _ink = PdfColor.fromInt(0xFF111827);
const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
const PdfColor _greenGlyph = PdfColor.fromInt(0xFF16A34A);
const PdfColor _greenDeep = PdfColor.fromInt(0xFF166534);
const PdfColor _greenBg = PdfColor.fromInt(0xFFDCFCE7);
const PdfColor _amberText = PdfColor.fromInt(0xFF92400E);
const PdfColor _amberBg = PdfColor.fromInt(0xFFFEF3C7);
const PdfColor _grayFooter = PdfColor.fromInt(0xFF9CA3AF);
const PdfColor _thermalMuted = PdfColor.fromInt(0xFF444444);

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

/// Data needed to render a transaction receipt. Drives three variants:
/// dealer collection (emerald `RECEIPT`), subscriber payment (blue `RECEIPT`)
/// and promise slip (amber `PROMISE SLIP`).
class TxReceiptData {
  TxReceiptData({
    required this.title,
    this.accent = TxAccent.emerald,
    required this.idLabel,
    required this.idValue,
    required this.date,
    this.a4Rows = const [],
    this.thermalRows = const [],
    this.thermalMonth = '',
    required this.amountLabel,
    required this.amount,
    this.statusLabel = '',
    this.statusPositive = true,
    this.thermalShowStatus = true,
    this.infoTitle = '',
    this.infoLines = const [],
    this.thermalTitle = '',
    this.disclaimer =
        'This is a computer-generated receipt and does not require a signature',
    this.thermalFooter = 'Computer generated receipt',
  });

  final String title;
  final TxAccent accent;
  final String idLabel;
  final String idValue;
  final String date;
  final List<(String, String)> a4Rows;
  final List<(String, String)> thermalRows;
  final String thermalMonth;
  final String amountLabel;
  final double amount;
  final String statusLabel;
  final bool statusPositive;
  final bool thermalShowStatus;
  final String infoTitle;
  final List<String> infoLines;
  final String thermalTitle;
  final String disclaimer;
  final String thermalFooter;

  bool get showStatus => statusLabel.isNotEmpty;
}

String _companyName(SalesCompany c) =>
    c.name.isEmpty ? 'Company Name' : c.name;

Future<Uint8List> buildTxReceiptPdf(
  TxReceiptData data,
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

  final doc = pw.Document(title: '${data.title} #${data.idValue}');

  if (size == 'thermal') {
    final height = _measureThermal(data, company, logo);
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
            children: _thermalContent(data, company, logo),
          ),
        ),
      ),
    );
  } else {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (context) => _a4Content(data, company, logo, stamp),
      ),
    );
  }

  return doc.save();
}

// ===========================================================================
// A4
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
  TxReceiptData data,
  SalesCompany company,
  pw.MemoryImage? logo,
  pw.MemoryImage? stamp,
) {
  final name = _companyName(company);
  final accent = _accentBright(data.accent);

  return [
    pw.Container(
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
                data.title,
                style: _s(
                  px: 30,
                  bold: true,
                  color: accent,
                  letterSpacing: _px(2),
                ),
              ),
              pw.SizedBox(height: _px(8)),
              _metaLine(data.idLabel, data.idValue),
              _metaLine('Date:', data.date),
              if (data.showStatus) _statusMetaLine(data),
            ],
          ),
        ],
      ),
    ),
    if (data.infoTitle.isNotEmpty) ...[
      pw.SizedBox(height: _px(24)),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            data.infoTitle.toUpperCase(),
            style: _s(
              px: 11,
              bold: true,
              color: _muted,
              letterSpacing: _px(0.5),
            ),
          ),
          pw.SizedBox(height: _px(4)),
          for (final l in data.infoLines)
            pw.Text(l, style: _s(px: 13, color: _ink, height: 1.6)),
        ],
      ),
    ],
    pw.SizedBox(height: _px(32)),
    pw.Table(
      border: pw.TableBorder.all(color: _line, width: _px(1)),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [
            _headCell('DESCRIPTION', pw.TextAlign.left),
            _headCell('VALUE', pw.TextAlign.right),
          ],
        ),
        for (final r in data.a4Rows)
          pw.TableRow(
            children: [
              _bodyCell(r.$1, pw.TextAlign.left, _muted, false),
              _bodyCell(r.$2, pw.TextAlign.right, _ink, true),
            ],
          ),
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF9FAFB)),
          children: [
            _bodyCell(data.amountLabel, pw.TextAlign.left, _ink, true),
            pw.Padding(
              padding: pw.EdgeInsets.all(_px(12)),
              child: pw.Text(
                'PKR ${salesMoney(data.amount)}',
                textAlign: pw.TextAlign.right,
                style: _s(px: 18, bold: true, color: accent),
              ),
            ),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: _px(48)),
    _a4Footer(name, company.contact1, stamp, data.disclaimer),
  ];
}

pw.Widget _headCell(String text, pw.TextAlign align) => pw.Padding(
  padding: pw.EdgeInsets.all(_px(12)),
  child: pw.Text(
    text,
    textAlign: align,
    style: _s(
      px: 11,
      bold: true,
      color: PdfColors.white,
      letterSpacing: _px(0.5),
    ),
  ),
);

pw.Widget _bodyCell(
  String text,
  pw.TextAlign align,
  PdfColor color,
  bool bold,
) =>
    pw.Padding(
      padding: pw.EdgeInsets.all(_px(12)),
      child: pw.Text(
        text,
        textAlign: align,
        style: _s(px: 13, bold: bold, color: color, height: 1.2),
      ),
    );

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

pw.Widget _statusMetaLine(TxReceiptData data) => pw.Padding(
  padding: pw.EdgeInsets.only(top: _px(2)),
  child: pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text('Status: ', style: _s(px: 13, color: _muted, height: 1.8)),
      pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: _px(8), vertical: _px(2)),
        decoration: pw.BoxDecoration(
          color: data.statusPositive ? _greenBg : _amberBg,
          borderRadius: pw.BorderRadius.circular(_px(4)),
        ),
        child: pw.Text(
          data.statusLabel.toUpperCase(),
          style: _s(
            px: 11,
            bold: true,
            color: data.statusPositive ? _greenDeep : _amberText,
            height: 1.2,
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _a4Footer(
  String companyName,
  String phone,
  pw.MemoryImage? stamp,
  String disclaimer,
) {
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
                pw.Text('Company Stamp', style: _s(px: 11, color: _grayFooter)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                    width: _px(200), height: _px(1), color: PdfColors.black),
                pw.SizedBox(height: _px(4)),
                pw.Text('Authorized Signature',
                    style: _s(px: 11, color: _grayFooter)),
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
              pw.SizedBox(height: _px(4)),
              pw.Text(disclaimer, style: _s(px: 11, color: _grayFooter)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ===========================================================================
// Thermal (80mm)
// ===========================================================================

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

pw.TextStyle _mono({
  double px = 12,
  bool bold = false,
  PdfColor color = PdfColors.black,
}) => pw.TextStyle(
  fontSize: _px(px),
  color: color,
  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
);

double _measureThermal(
  TxReceiptData data,
  SalesCompany company,
  pw.MemoryImage? logo,
) {
  const usableWidth = 74 * PdfPageFormat.mm;
  try {
    final measurer = pw.Document();
    final context = pw.Context(document: measurer.document);
    final column = pw.Theme(
      data: pw.ThemeData.base(),
      child: pw.DefaultTextStyle(
        style: _monoBaseStyle(),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: _thermalContent(data, company, logo),
        ),
      ),
    );
    column.layout(
      context,
      const pw.BoxConstraints(minWidth: usableWidth, maxWidth: usableWidth),
    );
    final contentHeight = column.box?.height ?? 0;
    if (contentHeight <= 0) return 200 * PdfPageFormat.mm;
    return contentHeight + (9 * PdfPageFormat.mm);
  } catch (_) {
    return 200 * PdfPageFormat.mm;
  }
}

List<pw.Widget> _thermalContent(
  TxReceiptData data,
  SalesCompany company,
  pw.MemoryImage? logo,
) {
  final name = _companyName(company);
  final accent = _accentBright(data.accent);
  return [
    pw.Center(
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
          pw.Text(name,
              textAlign: pw.TextAlign.center, style: _mono(px: 15, bold: true)),
          if (company.address.isNotEmpty)
            pw.Text(company.address,
                textAlign: pw.TextAlign.center,
                style: _mono(px: 10, color: _thermalMuted)),
          if (company.contact1.isNotEmpty)
            pw.Text(company.contact1,
                textAlign: pw.TextAlign.center,
                style: _mono(px: 10, color: _thermalMuted)),
        ],
      ),
    ),
    if (data.thermalTitle.isNotEmpty) ...[
      _dashed(),
      pw.Center(
        child: pw.Text(
          data.thermalTitle,
          style: _mono(px: 13, bold: true, color: accent),
        ),
      ),
    ],
    _dashed(),
    _tRow(data.idLabel, data.idValue),
    _tRow('Date:', data.date),
    if (data.thermalMonth.isNotEmpty) _tRow('Month:', data.thermalMonth),
    _dashed(),
    for (final r in data.thermalRows) _tRow(r.$1, r.$2),
    _dashed(),
    _tRow('Amount:', 'PKR ${salesMoney(data.amount)}'),
    if (data.thermalShowStatus && data.showStatus) ...[
      pw.SizedBox(height: _px(8)),
      pw.Center(
        child: pw.Container(
          padding:
              pw.EdgeInsets.symmetric(horizontal: _px(12), vertical: _px(4)),
          decoration: pw.BoxDecoration(
            color: data.statusPositive ? _greenBg : _amberBg,
            borderRadius: pw.BorderRadius.circular(_px(4)),
          ),
          child: pw.Text(
            data.statusLabel.toUpperCase(),
            style: _mono(
              px: 11,
              bold: true,
              color: data.statusPositive ? _greenGlyph : _amberText,
            ),
          ),
        ),
      ),
    ],
    _dashed(),
    pw.Center(
      child: pw.Column(
        children: [
          pw.Text(name,
              textAlign: pw.TextAlign.center,
              style: _mono(px: 11, bold: true)),
          pw.Text(data.thermalFooter,
              textAlign: pw.TextAlign.center,
              style: _mono(px: 10, color: _thermalMuted)),
        ],
      ),
    ),
    pw.SizedBox(height: _px(12)),
  ];
}

pw.Widget _tRow(String label, String value) => pw.Padding(
  padding: pw.EdgeInsets.symmetric(vertical: _px(3)),
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

pw.Widget _dashed() => pw.Container(
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

// ===========================================================================
// ESC/POS
// ===========================================================================

List<int> buildTxEscPos(TxReceiptData data, SalesCompany company) {
  final p = SalesEscPos();
  final name = _companyName(company);

  p.alignCenter();
  p.setBold(true);
  p.setSize(0x33);
  p.line(name.toUpperCase());
  p.setSize(0x00);
  p.setBold(false);
  if (company.address.isNotEmpty) p.line(company.address);
  if (company.contact1.isNotEmpty) p.line(company.contact1);
  p.feed();

  p.separator('=');
  if (data.thermalTitle.isNotEmpty) {
    p.setBold(true);
    p.line(data.thermalTitle);
    p.setBold(false);
    p.separator('=');
  }
  p.alignLeft();
  p.line(_twoCol(data.idLabel, data.idValue));
  p.line(_twoCol('Date:', data.date));
  if (data.thermalMonth.isNotEmpty) {
    p.line(_twoCol('Month:', data.thermalMonth));
  }
  p.separator();
  for (final r in data.thermalRows) {
    p.line(_twoCol(r.$1, r.$2));
  }
  p.separator();
  p.line(_twoCol('Amount:', 'PKR ${salesMoney(data.amount)}'));
  if (data.thermalShowStatus && data.showStatus) {
    p.feed();
    p.alignCenter();
    p.setBold(true);
    p.line(data.statusLabel.toUpperCase());
    p.setBold(false);
  }
  p.feed();
  p.alignCenter();
  p.line(name);
  p.line(data.thermalFooter);
  p.feed(2);
  p.cut();
  return p.bytes();
}

String _twoCol(String left, String right, [int width = SalesEscPos.width]) {
  if (left.length + right.length >= width) {
    return '$left\n${right.padLeft(width)}';
  }
  final pad = width - left.length - right.length;
  return '$left${' ' * pad}$right';
}

// ===========================================================================
// Preview screen
// ===========================================================================

/// In-app receipt preview + print for transaction receipts/slips. A4 prints via
/// the system dialog; the 80mm thermal view also supports Bluetooth.
class TxReceiptPreviewScreen extends StatefulWidget {
  const TxReceiptPreviewScreen({
    super.key,
    required this.title,
    required this.data,
    required this.company,
    this.initialSize = 'a4',
  });

  final String title;
  final TxReceiptData data;
  final SalesCompany company;
  final String initialSize;

  @override
  State<TxReceiptPreviewScreen> createState() => _TxReceiptPreviewScreenState();
}

class _TxReceiptPreviewScreenState extends State<TxReceiptPreviewScreen> {
  late String _size = widget.initialSize == 'thermal' ? 'thermal' : 'a4';

  bool get _isThermal => _size == 'thermal';

  Future<Uint8List> _buildPdf(PdfPageFormat format) =>
      buildTxReceiptPdf(widget.data, widget.company, size: _size);

  Future<void> _bluetoothPrint() async {
    final bytes = buildTxEscPos(widget.data, widget.company);
    await SalesBluetoothPrinter.printBytes(
      context,
      bytes: bytes,
      label: widget.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: SegmentedButton<String>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: 'a4',
                    label: Text('A4'),
                    icon: Icon(Icons.article_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'thermal',
                    label: Text('80mm'),
                    icon: Icon(Icons.receipt_long_outlined, size: 16),
                  ),
                ],
                selected: {_size},
                onSelectionChanged: (s) => setState(() => _size = s.first),
              ),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: _buildPdf,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: !_isThermal,
        dynamicLayout: false,
        actions: _isThermal
            ? [
                IconButton(
                  tooltip: 'Print via Bluetooth',
                  onPressed: _bluetoothPrint,
                  icon: const Icon(Icons.bluetooth_searching),
                ),
              ]
            : const [],
      ),
    );
  }
}