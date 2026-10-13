import 'sales_common.dart';

/// Minimal ESC/POS encoder for 80mm thermal printers, mirroring the thermal
/// receipt layout built by [buildSaleReceiptHtml] (`_buildThermalReceipt`).
class SalesEscPos {
  SalesEscPos() {
    _buffer.addAll([_esc, 0x40]);
  }

  static const int _esc = 0x1B;
  static const int _gs = 0x1D;
  static const int _lf = 0x0A;

  /// Character columns on a standard 80mm (Font A) roll.
  static const int width = 48;

  final List<int> _buffer = [];

  void _cmd(List<int> bytes) => _buffer.addAll(bytes);

  void alignLeft() => _cmd([_esc, 0x61, 0x00]);
  void alignCenter() => _cmd([_esc, 0x61, 0x01]);
  void alignRight() => _cmd([_esc, 0x61, 0x02]);

  void setBold(bool enabled) => _cmd([_esc, 0x45, enabled ? 0x01 : 0x00]);

  /// 0 = normal, 0x11 = double height, 0x22 = double width,
  /// 0x33 = double width + height.
  void setSize(int n) => _cmd([_gs, 0x21, n]);

  void text(String value) {
    for (final rune in value.runes) {
      _buffer.add(rune <= 0xFF ? rune : 0x3F);
    }
  }

  void line([String value = '']) {
    text(value);
    _buffer.add(_lf);
  }

  void separator([String char = '-']) => line(char * width);

  void feed([int lines = 1]) {
    for (var i = 0; i < lines; i++) {
      _buffer.add(_lf);
    }
  }

  void cut() => _cmd([_gs, 0x56, 0x00]);

  List<int> bytes() => List<int>.from(_buffer);
}

/// Builds the ESC/POS byte stream for a sale (or installment) receipt.
List<int> buildSalesEscPos(SaleReceiptData sale, SalesCompany company) {
  final p = SalesEscPos();
  final name = company.name.isEmpty ? 'Your Company' : company.name;
  final isInst = sale.isInstallment && sale.installmentInfo != null;

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
  p.line(isInst ? 'INSTALLMENT RECEIPT' : 'SALE RECEIPT');
  p.setBold(false);
  p.separator('=');

  p.alignLeft();
  p.line(_twoCol('No:', '${sale.invoiceNumber}'));
  p.line(_twoCol('Date:', salesDateTime(sale.date)));
  p.line(
    _twoCol(
      'Cust:',
      sale.subscriberName.isEmpty ? 'Walk-in' : sale.subscriberName,
    ),
  );
  p.line(_twoCol('Pay:', sale.paymentMethod.toUpperCase()));

  if (isInst) {
    final i = sale.installmentInfo!;
    final paidAmount = i.installmentAmount * i.paidInstallments;
    final remainingAmount = i.installmentAmount * i.remainingInstallments;
    final discount = sale.discount < 0 ? 0.0 : sale.discount;
    final productNames = sale.items.map((it) => it.productName).join(', ');
    final totalItems = sale.items.fold<int>(0, (s, it) => s + it.quantity);

    p.line(_twoCol('Plan:', i.planName));
    p.line(_twoCol('Products:', productNames.isEmpty ? '---' : productNames));
    p.line(_twoCol('Total Items:', '$totalItems'));
    p.separator();
    p.line(
      _twoCol('Per Installment:', 'PKR ${salesMoney(i.installmentAmount)}'),
    );
    if (discount > 0) {
      p.line(_twoCol('Discount:', '- PKR ${salesMoney(discount)}'));
    }
    p.line(_twoCol('Total Installments:', '${i.totalInstallments}'));
    p.line(
      _twoCol(
        'Paid:',
        '${i.paidInstallments} / ${i.totalInstallments} '
            '(PKR ${salesMoney(paidAmount)})',
      ),
    );
    p.line(
      _twoCol(
        'Remaining:',
        '${i.remainingInstallments} / ${i.totalInstallments} '
            '(PKR ${salesMoney(remainingAmount)})',
      ),
    );
    p.setBold(true);
    p.line(
      _twoCol('TOTAL (INSTALLMENT):', 'PKR ${salesMoney(i.installmentAmount)}'),
    );
    p.setBold(false);
    p.separator();
    p.alignCenter();
    p.line('Thank you for your purchase!');
    p.feed(2);
    p.cut();
    return p.bytes();
  }

  final subtotal =
      sale.totalAmount -
      sale.taxAmount +
      (sale.discount < 0 ? 0 : sale.discount);
  final discount = sale.discount < 0 ? 0.0 : sale.discount;
  final totalItems = sale.items.fold<int>(0, (s, i) => s + i.quantity);

  p.separator();
  if (sale.items.isEmpty) {
    p.alignCenter();
    p.line('No items');
    p.alignLeft();
  } else {
    for (final item in sale.items) {
      p.line(
        _twoCol(
          item.productName,
          salesMoney(item.price * item.quantity),
        ),
      );
      p.line('  ${item.quantity} x ${salesMoney(item.price)}');
      if (item.model.isNotEmpty) p.line('  Model: ${item.model}');
      if (item.serialNumber.isNotEmpty) p.line('  SN/MAC: ${item.serialNumber}');
    }
  }
  p.separator();
  p.line(_twoCol('Total Items', '$totalItems'));
  p.line(_twoCol('Subtotal', 'PKR ${salesMoney(subtotal)}'));
  p.line(_twoCol('Tax', 'PKR ${salesMoney(sale.taxAmount)}'));
  if (discount > 0) {
    p.line(_twoCol('Discount', '- PKR ${salesMoney(discount)}'));
  }
  p.setBold(true);
  p.setSize(0x11);
  p.line(_twoCol('TOTAL', 'PKR ${salesMoney(sale.totalAmount)}'));
  p.setSize(0x00);
  p.setBold(false);
  p.separator();
  p.alignCenter();
  p.line('Thank you for your purchase!');
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
