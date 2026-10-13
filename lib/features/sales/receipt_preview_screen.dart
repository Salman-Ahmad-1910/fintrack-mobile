import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'sales_bluetooth_printer.dart';
import 'sales_common.dart';
import 'sales_escpos.dart';
import 'sales_receipt_pdf.dart';

/// In-app receipt preview + print. A4 prints through the phone's system
/// dialog; the 80mm thermal view can also be sent to a paired Bluetooth
/// thermal printer.
class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.sale,
    required this.company,
    this.initialSize = 'a4',
  });

  final SaleReceiptData sale;
  final SalesCompany company;
  final String initialSize;

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  late String _size = widget.initialSize == 'thermal' ? 'thermal' : 'a4';

  bool get _isThermal => _size == 'thermal';

  String get _label {
    return widget.sale.isInstallment
        ? 'Installment Invoice #${widget.sale.invoiceNumber}'
        : 'Sale Receipt #${widget.sale.invoiceNumber}';
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) {
    return buildSalesReceiptPdf(widget.sale, widget.company, size: _size);
  }

  Future<void> _bluetoothPrint() async {
    final bytes = buildSalesEscPos(widget.sale, widget.company);
    await SalesBluetoothPrinter.printBytes(context, bytes: bytes, label: _label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: SegmentedButton<String>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
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
                onSelectionChanged: (s) =>
                    setState(() => _size = s.first),
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