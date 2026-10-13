/// Inventory data models — Flutter counterparts of the `Brand`, `UnitType`,
/// `ProductType`, `Product` and `Vendor` types in the web client's
/// `lib/types.ts`.
library;

double _toDouble(Object? v) => double.tryParse(v?.toString() ?? '') ?? 0;
int _toInt(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;
String _toStr(Object? v) => v?.toString() ?? '';

/// `inventory/brands`.
class Brand {
  Brand({required this.id, required this.name, this.status, this.category});

  final String id;
  final String name;
  final String? status;
  final String? category;

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    status: j['status'] == null ? null : _toStr(j['status']),
    category: j['category'] == null ? null : _toStr(j['category']),
  );
}

/// `inventory/unit-types`.
class UnitType {
  UnitType({required this.id, required this.name, this.status, this.category});

  final String id;
  final String name;
  final String? status;
  final String? category;

  factory UnitType.fromJson(Map<String, dynamic> j) => UnitType(
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    status: j['status'] == null ? null : _toStr(j['status']),
    category: j['category'] == null ? null : _toStr(j['category']),
  );
}

/// `inventory/product-types`.
class ProductType {
  ProductType({
    required this.id,
    required this.name,
    this.productCount = 0,
    this.category,
  });

  final String id;
  final String name;
  final int productCount;
  final String? category;

  factory ProductType.fromJson(Map<String, dynamic> j) => ProductType(
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    productCount: _toInt(j['productCount']),
    category: j['category'] == null ? null : _toStr(j['category']),
  );
}

/// `inventory/products`.
class Product {
  Product({
    required this.id,
    this.productId = '',
    required this.name,
    this.category = '',
    this.price = 0,
    this.stock = 0,
    this.unitType = 'piece',
    this.taxPercent = 0,
    this.image = '',
    this.brandId = '',
    this.brandName = '',
    this.productTypeId = '',
    this.productTypeName = '',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.discount = 0,
    this.serialNumber = '',
    this.currentSerialIndex = 0,
    this.noSerialNumber = false,
    this.model = '',
    this.noModel = false,
    this.currentModelIndex = 0,
  });

  final String id;
  final String productId;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String unitType;
  final double taxPercent;
  final String image;
  final String brandId;
  final String brandName;
  final String productTypeId;
  final String productTypeName;
  final double purchasePrice;
  final double salePrice;
  final double discount;
  final String serialNumber;
  final int currentSerialIndex;
  final bool noSerialNumber;
  final String model;
  final bool noModel;
  final int currentModelIndex;

  /// Web `product.productTypeName || product.category || '-'`.
  String get typeLabel =>
      productTypeName.isNotEmpty ? productTypeName : (category.isEmpty ? '-' : category);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: _toStr(j['id']),
    productId: _toStr(j['productId']),
    name: _toStr(j['name']),
    category: _toStr(j['category']),
    price: _toDouble(j['price']),
    stock: _toInt(j['stock']),
    unitType: j['unitType'] == null ? 'piece' : _toStr(j['unitType']),
    taxPercent: _toDouble(j['taxPercent']),
    image: _toStr(j['image']),
    brandId: _toStr(j['brandId']),
    brandName: _toStr(j['brandName']),
    productTypeId: _toStr(j['productTypeId']),
    productTypeName: _toStr(j['productTypeName']),
    purchasePrice: _toDouble(j['purchasePrice']),
    salePrice: _toDouble(j['salePrice']),
    discount: _toDouble(j['discount']),
    serialNumber: _toStr(j['serialNumber'] ?? j['productSerialNumber']),
    currentSerialIndex: _toInt(j['currentSerialIndex']),
    noSerialNumber: j['noSerialNumber'] == true,
    model: _toStr(j['model'] ?? j['productModel']),
    noModel: j['noModel'] == true,
    currentModelIndex: _toInt(j['currentModelIndex']),
  );
}

/// `inventory/vendors`.
class Vendor {
  Vendor({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    contactPerson: _toStr(j['contactPerson']),
    phone: _toStr(j['phone']),
    email: _toStr(j['email']),
    address: _toStr(j['address']),
  );
}

/// One line of a vendor invoice (`VendorInvoiceItem` in web `lib/types.ts`).
class VendorInvoiceItem {
  VendorInvoiceItem({
    this.id = '',
    this.invoiceId = '',
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.unitType = '',
    required this.subtotal,
    this.serialNumber = '',
    this.model = '',
  });

  final String id;
  final String invoiceId;
  final String productId;
  final String productName;
  final num quantity;
  final num unitPrice;
  final num purchasePrice;
  final num sellingPrice;
  final String unitType;
  final num subtotal;
  final String serialNumber;
  final String model;

  factory VendorInvoiceItem.fromJson(Map<String, dynamic> j) => VendorInvoiceItem(
    id: _toStr(j['id']),
    invoiceId: _toStr(j['invoiceId']),
    productId: _toStr(j['productId']),
    productName: _toStr(j['productName']),
    quantity: _toDouble(j['quantity']),
    unitPrice: _toDouble(j['unitPrice']),
    purchasePrice: _toDouble(j['purchasePrice'] ?? j['unitPrice']),
    sellingPrice: _toDouble(j['sellingPrice']),
    unitType: _toStr(j['unitType']),
    subtotal: _toDouble(j['subtotal']),
    serialNumber: _toStr(j['serialNumber']),
    model: _toStr(j['model']),
  );
}

/// `inventory/vendor-invoices` (`VendorInvoice` in web `lib/types.ts`).
class VendorInvoice {
  VendorInvoice({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.discount = 0,
    this.totalAmount = 0,
    this.batch = '',
    this.items = const [],
    this.createdAt = '',
    this.companyId = '',
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String invoiceNumber;
  final String invoiceDate;
  final num discount;
  final num totalAmount;
  final String batch;
  final List<VendorInvoiceItem> items;
  final String createdAt;
  final String companyId;

  factory VendorInvoice.fromJson(Map<String, dynamic> j) => VendorInvoice(
    id: _toStr(j['id']),
    vendorId: _toStr(j['vendorId']),
    vendorName: _toStr(j['vendorName']),
    invoiceNumber: _toStr(j['invoiceNumber']),
    invoiceDate: _toStr(j['invoiceDate']),
    discount: _toDouble(j['discount']),
    totalAmount: _toDouble(j['totalAmount']),
    batch: _toStr(j['batch']),
    items: (j['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(VendorInvoiceItem.fromJson)
            .toList() ??
        const [],
    createdAt: _toStr(j['createdAt']),
    companyId: _toStr(j['companyId']),
  );
}

/// One entry in a purchase item's quantity history (`PurchaseQuantityHistory`).
class PurchaseQuantityHistory {
  PurchaseQuantityHistory({
    required this.id,
    this.purchaseId = '',
    this.purchaseItemId = '',
    this.productId = '',
    this.quantityBefore = 0,
    this.quantityAdded = 0,
    this.serialNumbersAdded = '',
    this.modelsAdded = '',
    this.unitPrice = 0,
    this.createdAt = '',
  });

  final String id;
  final String purchaseId;
  final String purchaseItemId;
  final String productId;
  final num quantityBefore;
  final num quantityAdded;
  final String serialNumbersAdded;
  final String modelsAdded;
  final num unitPrice;
  final String createdAt;

  factory PurchaseQuantityHistory.fromJson(Map<String, dynamic> j) =>
      PurchaseQuantityHistory(
        id: _toStr(j['id']),
        purchaseId: _toStr(j['purchaseId']),
        purchaseItemId: _toStr(j['purchaseItemId']),
        productId: _toStr(j['productId']),
        quantityBefore: _toDouble(j['quantityBefore']),
        quantityAdded: _toDouble(j['quantityAdded']),
        serialNumbersAdded: _toStr(j['serialNumbersAdded']),
        modelsAdded: _toStr(j['modelsAdded']),
        unitPrice: _toDouble(j['unitPrice']),
        createdAt: _toStr(j['createdAt']),
      );
}

/// One line of a purchase (`PurchaseItem` in web `lib/types.ts`).
class PurchaseItem {
  PurchaseItem({
    this.id = '',
    this.purchaseId = '',
    required this.productId,
    required this.productName,
    required this.quantity,
    this.quantityEntered = 0,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.unitType = '',
    this.focNormal = 'normal',
    this.subtotal = 0,
    this.saleTax = 0,
    this.wthTax = 0,
    this.disc = 0,
    this.expiryDate = '',
    this.serialNumber = '',
    this.model = '',
    this.history = const [],
  });

  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final num quantity;
  final num quantityEntered;
  final num purchasePrice;
  final num sellingPrice;
  final String unitType;
  final String focNormal;
  final num subtotal;
  final num saleTax;
  final num wthTax;
  final num disc;
  final String expiryDate;
  final String serialNumber;
  final String model;
  final List<PurchaseQuantityHistory> history;

  /// Web columns "Quantity" prefers `quantityEntered` when set.
  num get effectiveQuantity =>
      quantityEntered > 0 ? quantityEntered : quantity;

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
    id: _toStr(j['id']),
    purchaseId: _toStr(j['purchaseId']),
    productId: _toStr(j['productId']),
    productName: _toStr(j['productName']),
    quantity: _toDouble(j['quantity']),
    quantityEntered: _toDouble(j['quantityEntered']),
    purchasePrice: _toDouble(j['purchasePrice']),
    sellingPrice: _toDouble(j['sellingPrice']),
    unitType: _toStr(j['unitType']),
    focNormal: j['focNormal'] == null ? 'normal' : _toStr(j['focNormal']),
    subtotal: _toDouble(j['subtotal']),
    saleTax: _toDouble(j['saleTax']),
    wthTax: _toDouble(j['wthTax']),
    disc: _toDouble(j['disc']),
    expiryDate: _toStr(j['expiryDate']),
    serialNumber: _toStr(j['serialNumber']),
    model: _toStr(j['model']),
    history: (j['history'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseQuantityHistory.fromJson)
            .toList() ??
        const [],
  );
}

/// `inventory/purchases` (`Purchase` in web `lib/types.ts`).
class Purchase {
  Purchase({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.purchaseNumber = '',
    this.purchaseDate = '',
    this.billId = '',
    this.batch = '',
    this.totalAmount = 0,
    this.remainingAmount = 0,
    this.discount = 0,
    this.salesTax = 0,
    this.wthTax = 0,
    this.status = 'unpaid',
    this.items = const [],
    this.createdAt = '',
    this.companyId = '',
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String purchaseNumber;
  final String purchaseDate;
  final String billId;
  final String batch;
  final num totalAmount;
  final num remainingAmount;
  final num discount;
  final num salesTax;
  final num wthTax;
  final String status;
  final List<PurchaseItem> items;
  final String createdAt;
  final String companyId;

  String get displayBillId => billId.isNotEmpty ? billId : purchaseNumber;

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
    id: _toStr(j['id']),
    vendorId: _toStr(j['vendorId']),
    vendorName: _toStr(j['vendorName']),
    purchaseNumber: _toStr(j['purchaseNumber']),
    purchaseDate: _toStr(j['purchaseDate']),
    billId: _toStr(j['billId']),
    batch: _toStr(j['batch']),
    totalAmount: _toDouble(j['totalAmount']),
    remainingAmount: _toDouble(j['remainingAmount']),
    discount: _toDouble(j['discount']),
    salesTax: _toDouble(j['salesTax']),
    wthTax: _toDouble(j['wthTax']),
    status: j['status'] == null ? 'unpaid' : _toStr(j['status']),
    items: (j['items'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchaseItem.fromJson)
            .toList() ??
        const [],
    createdAt: _toStr(j['createdAt']),
    companyId: _toStr(j['companyId']),
  );
}

/// Row shown by the Inventory Status page (web `PurchasedProduct`).
class PurchasedProduct {
  PurchasedProduct({
    required this.purchaseItemId,
    required this.id,
    required this.name,
    this.price = 0,
    this.stock = 0,
    this.unitType = '',
    this.taxPercent = 0,
    this.purchasePrice = 0,
    this.billId = '',
    this.purchaseNumber = '',
    this.vendorName = '',
    this.purchaseDate = '',
    this.batch = '',
    this.serialNumber = '',
    this.model = '',
    this.productModel = '',
    this.currentModelIndex = 0,
  });

  final String purchaseItemId;
  final String id;
  final String name;
  final num price;
  final num stock;
  final String unitType;
  final num taxPercent;
  final num purchasePrice;
  final String billId;
  final String purchaseNumber;
  final String vendorName;
  final String purchaseDate;
  final String batch;
  final String serialNumber;
  final String model;
  final String productModel;
  final int currentModelIndex;

  String get displayBillId =>
      billId.isNotEmpty ? billId : (purchaseNumber.isNotEmpty ? purchaseNumber : '-');

  factory PurchasedProduct.fromJson(Map<String, dynamic> j) => PurchasedProduct(
    purchaseItemId: _toStr(j['purchaseItemId']),
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    price: _toDouble(j['price']),
    stock: _toDouble(j['stock']),
    unitType: _toStr(j['unitType']),
    taxPercent: _toDouble(j['taxPercent']),
    purchasePrice: _toDouble(j['purchasePrice']),
    billId: _toStr(j['billId']),
    purchaseNumber: _toStr(j['purchaseNumber']),
    vendorName: _toStr(j['vendorName']),
    purchaseDate: _toStr(j['purchaseDate']),
    batch: _toStr(j['batch']),
    serialNumber: _toStr(j['serialNumber']),
    model: _toStr(j['model']),
    productModel: _toStr(j['productModel']),
    currentModelIndex: _toInt(j['currentModelIndex']),
  );
}

/// One purchase line of a stock product (web `PurchasedProductLine`).
class PurchasedProductLine {
  PurchasedProductLine({
    this.purchaseItemId = '',
    this.id = '',
    this.name = '',
    this.quantity = 0,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.unitType = '',
    this.serialNumber = '',
    this.model = '',
    this.billId = '',
    this.purchaseNumber = '',
    this.vendorName = '',
    this.purchaseDate = '',
    this.batch = '',
    this.createdAt = '',
  });

  final String purchaseItemId;
  final String id;
  final String name;
  final num quantity;
  final num purchasePrice;
  final num sellingPrice;
  final String unitType;
  final String serialNumber;
  final String model;
  final String billId;
  final String purchaseNumber;
  final String vendorName;
  final String purchaseDate;
  final String batch;
  final String createdAt;

  factory PurchasedProductLine.fromJson(Map<String, dynamic> j) =>
      PurchasedProductLine(
        purchaseItemId: _toStr(j['purchaseItemId']),
        id: _toStr(j['id']),
        name: _toStr(j['name']),
        quantity: _toDouble(j['quantity']),
        purchasePrice: _toDouble(j['purchasePrice']),
        sellingPrice: _toDouble(j['sellingPrice']),
        unitType: _toStr(j['unitType']),
        serialNumber: _toStr(j['serialNumber']),
        model: _toStr(j['model']),
        billId: _toStr(j['billId']),
        purchaseNumber: _toStr(j['purchaseNumber']),
        vendorName: _toStr(j['vendorName']),
        purchaseDate: _toStr(j['purchaseDate']),
        batch: _toStr(j['batch']),
        createdAt: _toStr(j['createdAt']),
      );
}

/// Row shown by the Stock page (web `StockProduct`).
class StockProduct {
  StockProduct({
    this.purchaseItemId = '',
    required this.id,
    required this.name,
    this.productTypeName = '',
    this.price = 0,
    this.stock = 0,
    this.totalPurchased = 0,
    this.totalSold = 0,
    this.unitType = '',
    this.taxPercent = 0,
    this.purchasePrice = 0,
    this.billId = '',
    this.purchaseNumber = '',
    this.vendorName = '',
    this.purchaseDate = '',
    this.batch = '',
    this.serialNumber = '',
    this.model = '',
    this.image = '',
    this.lines = const [],
  });

  final String purchaseItemId;
  final String id;
  final String name;
  final String productTypeName;
  final num price;
  final num stock;
  final num totalPurchased;
  final num totalSold;
  final String unitType;
  final num taxPercent;
  final num purchasePrice;
  final String billId;
  final String purchaseNumber;
  final String vendorName;
  final String purchaseDate;
  final String batch;
  final String serialNumber;
  final String model;
  final String image;
  final List<PurchasedProductLine> lines;

  factory StockProduct.fromJson(Map<String, dynamic> j) => StockProduct(
    purchaseItemId: _toStr(j['purchaseItemId']),
    id: _toStr(j['id']),
    name: _toStr(j['name']),
    productTypeName: _toStr(j['productTypeName']),
    price: _toDouble(j['price']),
    stock: _toDouble(j['stock']),
    totalPurchased: _toDouble(j['totalPurchased']),
    totalSold: _toDouble(j['totalSold']),
    unitType: _toStr(j['unitType']),
    taxPercent: _toDouble(j['taxPercent']),
    purchasePrice: _toDouble(j['purchasePrice']),
    billId: _toStr(j['billId']),
    purchaseNumber: _toStr(j['purchaseNumber']),
    vendorName: _toStr(j['vendorName']),
    purchaseDate: _toStr(j['purchaseDate']),
    batch: _toStr(j['batch']),
    serialNumber: _toStr(j['serialNumber']),
    model: _toStr(j['model']),
    image: _toStr(j['image']),
    lines: (j['lines'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(PurchasedProductLine.fromJson)
            .toList() ??
        const [],
  );
}
