/// Data models for the Sales section. Field names + shapes mirror the Go
/// backend (`models.Sale`, `models.SaleItem`, `models.SalePromiseInfo`,
/// `models.InstallmentPlan`, `models.PurchasedProduct`) so the Flutter client
/// and the Next.js client read and write the exact same records on the shared
/// database.
library;

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String _s(dynamic v) => v == null ? '' : v.toString();

bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return v?.toString().toLowerCase() == 'true';
}

/// A line item on a sale (`models.SaleItem`).
class SalesItem {
  SalesItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.originalPrice,
    required this.taxPercent,
    required this.saleTax,
    required this.wthTax,
    required this.serialNumber,
    required this.model,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double originalPrice;
  final double taxPercent;
  final double saleTax;
  final double wthTax;
  final String serialNumber;
  final String model;

  factory SalesItem.fromJson(Map<String, dynamic> j) => SalesItem(
    id: _s(j['id']),
    saleId: _s(j['saleId']),
    productId: _s(j['productId']),
    productName: _s(j['productName']),
    quantity: _i(j['quantity']),
    price: _d(j['price']),
    originalPrice: _d(j['originalPrice']),
    taxPercent: _d(j['taxPercent']),
    saleTax: _d(j['saleTax']),
    wthTax: _d(j['wthTax']),
    serialNumber: _s(j['serialNumber']),
    model: _s(j['model']),
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'price': price,
    'originalPrice': originalPrice,
    'taxPercent': taxPercent,
    'saleTax': saleTax,
    'wthTax': wthTax,
    'serialNumber': serialNumber,
    'model': model,
  };
}

/// The unpaid part of a promise-to-pay sale (`models.SalePromiseInfo`).
class SalePromiseInfo {
  SalePromiseInfo({
    required this.promiseId,
    required this.pendingAmount,
    required this.paidAmount,
    required this.collectedAmount,
    required this.remainingAmount,
    required this.promiseDate,
    required this.status,
    required this.description,
  });

  final String promiseId;
  final double pendingAmount;
  final double paidAmount;
  final double collectedAmount;
  final double remainingAmount;
  final String promiseDate;
  final String status;
  final String description;

  factory SalePromiseInfo.fromJson(Map<String, dynamic> j) => SalePromiseInfo(
    promiseId: _s(j['promiseId']),
    pendingAmount: _d(j['pendingAmount']),
    paidAmount: _d(j['paidAmount']),
    collectedAmount: _d(j['collectedAmount']),
    remainingAmount: _d(j['remainingAmount']),
    promiseDate: _s(j['promiseDate']),
    status: _s(j['status']),
    description: _s(j['description']),
  );
}

/// A POS sale / hold bill together with its line items (`models.Sale`).
class SalesEntry {
  SalesEntry({
    required this.id,
    required this.subscriberId,
    required this.subscriberName,
    required this.totalAmount,
    required this.taxAmount,
    required this.discount,
    required this.paymentMethod,
    required this.status,
    required this.date,
    required this.isInstallment,
    required this.replacedFrom,
    required this.items,
    required this.saleType,
    required this.paidAmount,
    required this.paymentStatus,
    required this.promisePayment,
    required this.promiseInfo,
  });

  final String id;
  final String subscriberId;
  final String subscriberName;
  final double totalAmount;
  final double taxAmount;
  final double discount;
  final String paymentMethod;
  final String status;
  final String date;
  final bool isInstallment;

  /// Raw JSON snapshot the backend stores when a sale is replaced.
  final String replacedFrom;
  final List<SalesItem> items;

  /// `pos` (default) or `fiber_jointing`.
  final String saleType;
  final double paidAmount;
  final String paymentStatus;
  final bool promisePayment;
  final SalePromiseInfo? promiseInfo;

  factory SalesEntry.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final rawPromise = j['promiseInfo'];
    return SalesEntry(
      id: _s(j['id']),
      subscriberId: _s(j['subscriberId']),
      subscriberName: _s(j['subscriberName']),
      totalAmount: _d(j['totalAmount']),
      taxAmount: _d(j['taxAmount']),
      discount: _d(j['discount']),
      paymentMethod: _s(j['paymentMethod']),
      status: _s(j['status']),
      date: _s(j['date']),
      isInstallment: _b(j['isInstallment']),
      replacedFrom: _s(j['replacedFrom']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((e) => SalesItem.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
      saleType: _s(j['saleType']).isEmpty ? 'pos' : _s(j['saleType']),
      paidAmount: _d(j['paidAmount']),
      paymentStatus: _s(j['paymentStatus']),
      promisePayment: _b(j['promisePayment']),
      promiseInfo: rawPromise is Map
          ? SalePromiseInfo.fromJson(rawPromise.cast<String, dynamic>())
          : null,
    );
  }

  String get customerLabel =>
      subscriberName.isEmpty ? 'Walk-in' : subscriberName;

  bool get isHold => status == 'hold';
  bool get isReturned => status == 'returned';
  bool get isReplaced => status == 'replaced';
  bool get isFiber => saleType == 'fiber_jointing';

  bool get isOpenPromise =>
      promiseInfo != null && promiseInfo!.remainingAmount > 0;

  int get totalQty => items.fold(0, (sum, i) => sum + i.quantity);

  /// Subtotal of the line items (price * qty), before tax.
  double get itemsSubtotal =>
      items.fold(0.0, (sum, i) => sum + i.price * i.quantity);

  /// A line is a "good sale" when its selling price exceeds the product's
  /// original list price captured at sale time.
  bool get isGoodSale =>
      items.any((i) => i.originalPrice > 0 && i.price > i.originalPrice);

  double get displayAmount =>
      totalAmount != 0 ? totalAmount : itemsSubtotal + taxAmount;

  /// For installment sales: the percentage the plan added over the items'
  /// subtotal, rounded the same way the web column does.
  int get increasePercent {
    if (!isInstallment || itemsSubtotal <= 0) return 0;
    return (((displayAmount - taxAmount) / itemsSubtotal - 1) * 100).round();
  }

  List<String> get uniqueSerials {
    final seen = <String>{};
    for (final item in items) {
      for (final sn in parseSalesTokens(item.serialNumber, [
        RegExp(r'[\s,\-]+'),
      ])) {
        seen.add(sn);
      }
    }
    return seen.toList();
  }

  List<String> get uniqueModels {
    final seen = <String>{};
    for (final item in items) {
      for (final m in parseSalesTokens(item.model, [RegExp(r'[\s,\n\r\t]+')])) {
        seen.add(m);
      }
    }
    return seen.toList();
  }
}

/// An installment plan (`models.InstallmentPlan`, table `installment_plans`).
class SalesPlan {
  SalesPlan({
    required this.id,
    required this.name,
    required this.installments,
    required this.percentageIncrease,
    this.status = '',
  });

  final String id;
  final String name;
  final int installments;
  final double percentageIncrease;
  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  factory SalesPlan.fromJson(Map<String, dynamic> j) => SalesPlan(
    id: _s(j['id']),
    name: _s(j['name']),
    installments: _i(j['installments']),
    percentageIncrease: _d(j['percentageIncrease']),
    status: _s(j['status']),
  );
}

/// A single row of the POS stock list. Mirrors the `/inventory/purchased-products`
/// result: one entry per purchase batch line, flattened to a sellable product.
class PosProduct {
  PosProduct({
    required this.purchaseItemId,
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.unitType,
    required this.taxPercent,
    required this.purchasePrice,
    required this.serialNumber,
    required this.productSerialNumber,
    required this.currentSerialIndex,
    required this.model,
    required this.productModel,
    required this.currentModelIndex,
    required this.billId,
    required this.purchaseNumber,
    required this.vendorName,
    required this.purchaseDate,
    required this.batch,
    required this.image,
  });

  final String purchaseItemId;
  final String id;
  final String name;
  final double price;
  final int stock;
  final String unitType;
  final double taxPercent;
  final double purchasePrice;
  final String serialNumber;
  final String productSerialNumber;
  final int currentSerialIndex;
  final String model;
  final String productModel;
  final int currentModelIndex;
  final String billId;
  final String purchaseNumber;
  final String vendorName;
  final String purchaseDate;
  final String batch;
  final String image;

  factory PosProduct.fromJson(Map<String, dynamic> j) => PosProduct(
    purchaseItemId: _s(j['purchaseItemId']),
    id: _s(j['id']),
    name: _s(j['name']),
    price: _d(j['price']),
    stock: _i(j['stock']),
    unitType: _s(j['unitType']),
    taxPercent: _d(j['taxPercent']),
    purchasePrice: _d(j['purchasePrice']),
    serialNumber: _s(j['serialNumber']),
    productSerialNumber: _s(j['productSerialNumber']),
    currentSerialIndex: _i(j['currentSerialIndex']),
    model: _s(j['model']),
    productModel: _s(j['productModel']),
    currentModelIndex: _i(j['currentModelIndex']),
    billId: _s(j['billId']),
    purchaseNumber: _s(j['purchaseNumber']),
    vendorName: _s(j['vendorName']),
    purchaseDate: _s(j['purchaseDate']),
    batch: _s(j['batch']),
    image: _s(j['image']),
  );

  /// Serial numbers still in stock for this batch line (from `currentSerialIndex`
  /// onward). Mirrors the web `getAvailableSerialNumbers`.
  List<String> get availableSerialNumbers {
    final all = parseSalesTokens(serialNumber, [RegExp(r'[\s,\-]+')]);
    if (all.isEmpty) return const [];
    final start = currentSerialIndex.clamp(0, all.length);
    return all.sublist(start);
  }

  /// Models still in stock for this batch line (from `currentModelIndex` onward).
  List<String> get availableModels {
    final all = parseSalesTokens(model, [RegExp(r'[\s,\n\r\t]+')]);
    if (all.isEmpty) return const [];
    final start = currentModelIndex.clamp(0, all.length);
    return all.sublist(start);
  }

  bool get hasSerials => availableSerialNumbers.isNotEmpty;
}

/// An installment ledger row (`models.SubscriberInstallment`).
class SubscriberInstallment {
  SubscriberInstallment({
    required this.id,
    required this.saleId,
    required this.subscriberId,
    required this.subscriberName,
    required this.installmentPlanId,
    required this.planName,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.installmentAmount,
    required this.totalAmount,
    required this.nextInstallment,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String saleId;
  final String subscriberId;
  final String subscriberName;
  final String installmentPlanId;
  final String planName;
  final int totalInstallments;
  final int paidInstallments;
  final double installmentAmount;
  final double totalAmount;
  final int nextInstallment;
  final String status;
  final String createdAt;

  factory SubscriberInstallment.fromJson(Map<String, dynamic> j) =>
      SubscriberInstallment(
        id: _s(j['id']),
        saleId: _s(j['saleId']),
        subscriberId: _s(j['subscriberId']),
        subscriberName: _s(j['subscriberName']),
        installmentPlanId: _s(j['installmentPlanId']),
        planName: _s(j['planName']),
        totalInstallments: _i(j['totalInstallments']),
        paidInstallments: _i(j['paidInstallments']),
        installmentAmount: _d(j['installmentAmount']),
        totalAmount: _d(j['totalAmount']),
        nextInstallment: _i(j['nextInstallment']),
        status: _s(j['status']),
        createdAt: _s(j['createdAt']),
      );

  bool get isCompleted => status == 'completed';
  int get remaining => (totalInstallments - paidInstallments).clamp(0, 1 << 30);
  int get percent => totalInstallments <= 0
      ? 0
      : ((paidInstallments / totalInstallments) * 100).round();
}

/// A `{id, name}` option used by the POS/subscriber dropdowns.
class SalesOption {
  SalesOption({required this.id, required this.name, this.secondary = ''});

  final String id;
  final String name;
  final String secondary;

  factory SalesOption.fromJson(Map<String, dynamic> j) => SalesOption(
    id: _s(j['id']),
    name: _s(j['name']),
    secondary: _s(j['internetId'] ?? j['cnic'] ?? j['phone'] ?? ''),
  );
}

/// Splits a packed serial/model string using the same regexes as the web
/// `serial-entries.tsx` helper.
List<String> parseSalesTokens(String raw, List<RegExp> separators) {
  if (raw.trim().isEmpty) return const [];
  var parts = <String>[raw];
  for (final sep in separators) {
    parts = [for (final p in parts) ...p.split(sep)];
  }
  return [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
}
