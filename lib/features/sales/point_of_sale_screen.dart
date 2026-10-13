import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../crm/crm_models.dart';
import '../network/network_common.dart';
import 'sales_common.dart';
import 'sales_models.dart';

/// Flutter counterpart of `client/src/app/(app)/inventory/pos/page.tsx` — the
/// retail counter: search the stock, build a cart with per-line SN / model
/// selection, sell to a subscriber / customer / dealer, take payment (cash,
/// card, bank), hold a bill, record a promise to pay, collect outstanding dues
/// and run installment sales.
class PointOfSaleScreen extends StatefulWidget {
  const PointOfSaleScreen({super.key});

  @override
  State<PointOfSaleScreen> createState() => _PointOfSaleScreenState();
}

const String _kPosPermission = '15338';
const String _kDeletePermission = '15364';
const List<String> _adminRoles = ['admin', 'owner', 'manager'];

class _CartItem {
  _CartItem({
    required this.product,
    required this.quantity,
    required this.price,
    List<String>? selectedSNs,
    List<String>? selectedModels,
  }) : selectedSNs = selectedSNs ?? <String>[],
       selectedModels = selectedModels ?? <String>[],
       priceCtrl = TextEditingController(
         text: price == price.roundToDouble()
             ? price.toStringAsFixed(0)
             : price.toString(),
       );

  final PosProduct product;
  int quantity;
  double price;
  final List<String> selectedSNs;
  final List<String> selectedModels;
  final TextEditingController priceCtrl;

  void dispose() => priceCtrl.dispose();
}

class _OrderResult {
  _OrderResult({
    required this.success,
    required this.title,
    required this.description,
    this.items,
    this.total,
    this.paidNow,
    this.pending,
  });

  final bool success;
  final String title;
  final String description;
  final int? items;
  final double? total;
  final double? paidNow;
  final double? pending;
}

class _PointOfSaleScreenState extends State<PointOfSaleScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<PosProduct> _rawProducts = [];
  List<CrmCustomer> _customers = [];
  List<SalesOption> _dealers = [];
  List<SalesOption> _subscribers = [];
  List<SalesPlan> _plans = [];
  SalesCompany _company = SalesCompany.empty;

  final List<_CartItem> _cart = [];
  String _customerType = '';
  String _customerId = '';
  String? _paymentMethod = 'cash';
  double _discount = 0;

  bool _isInstallment = false;
  String _selectedPlanId = '';
  SubscriberInstallment? _existingInstallment;
  bool _fetchingInstallment = false;
  List<Map<String, dynamic>> _pendingSaleItems = [];

  double _existingPending = 0;
  final TextEditingController _duesAmount = TextEditingController();

  final TextEditingController _search = TextEditingController();
  String _searchTerm = '';

  bool _loading = true;
  bool _processing = false;
  bool _payingDues = false;

  PosProduct? _productToDelete;
  bool _deleting = false;
  PosProduct? _snEntriesProduct;
  _OrderResult? _orderResult;

  static void _handleUnauthorized() {
    Session.clear();
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  String? get _cid => Session.companyId;

  bool _hasPermission(String id) {
    final isAdmin = _adminRoles.contains(Session.role ?? '');
    if (isAdmin || !Session.permissionsConfigured) return true;
    return Session.permissions.contains(id);
  }

  bool _canPage(String key) => _hasPermission('$_kPosPermission:$key');

  bool get _canDelete => _hasPermission(_kDeletePermission);

  bool get _canCollectPayment => _canPage('order-detail');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _duesAmount.dispose();
    for (final item in _cart) {
      item.dispose();
    }
    super.dispose();
  }

  void _clearCart() {
    for (final item in _cart) {
      item.dispose();
    }
    _cart.clear();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('inventory/purchased-products', query: {'companyId': cid}),
        _api.get('crm/customers', query: {'companyId': cid}),
        _api.get('dealers', query: {'companyId': cid}),
        _api.get('admin/connections', query: {'companyId': cid}),
        _api.get('sales/installment-plans', query: {'companyId': cid}),
        fetchSalesCompany(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _rawProducts = ApiClient.listData(results[0] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(PosProduct.fromJson)
            .toList();
        _customers = ApiClient.listData(results[1] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(CrmCustomer.fromJson)
            .toList();
        _dealers = ApiClient.listData(results[2] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SalesOption.fromJson)
            .toList();
        _subscribers = ApiClient.listData(results[3] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(_subscriberOption)
            .toList();
        _plans = ApiClient.listData(results[4] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SalesPlan.fromJson)
            .toList();
        _company = results[5] as SalesCompany;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, e.message, error: true);
    }
  }

  SalesOption _subscriberOption(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString();
    final name = (j['name'] ?? '').toString();
    final phone = (j['phone'] ?? j['cell'] ?? j['mobile'] ?? '').toString();
    return SalesOption(
      id: id,
      name: '${id.length >= 8 ? id.substring(0, 8) : id} | $name',
      secondary: phone,
    );
  }

  // ---------------------------------------------------------------------------
  // Product projection
  // ---------------------------------------------------------------------------

  List<PosProduct> get _posProducts => _groupByName(_rawProducts);

  List<PosProduct> _groupByName(List<PosProduct> input) {
    final byName = <String, PosProduct>{};
    for (final p in input) {
      final key = p.name.trim().toLowerCase();
      final existing = byName[key];
      if (existing == null) {
        byName[key] = p;
        continue;
      }
      byName[key] = PosProduct(
        purchaseItemId: p.purchaseItemId,
        id: p.id,
        name: p.name,
        price: existing.price,
        stock: existing.stock + p.stock,
        unitType: existing.unitType.isEmpty ? p.unitType : existing.unitType,
        taxPercent: existing.taxPercent != 0
            ? existing.taxPercent
            : p.taxPercent,
        purchasePrice: existing.purchasePrice,
        serialNumber: _join(existing.serialNumber, p.serialNumber),
        productSerialNumber: _join(
          existing.productSerialNumber,
          p.productSerialNumber,
        ),
        currentSerialIndex: existing.currentSerialIndex,
        model: _join(existing.model, p.model),
        productModel: _join(existing.productModel, p.productModel),
        currentModelIndex: existing.currentModelIndex,
        billId: existing.billId,
        purchaseNumber: existing.purchaseNumber,
        vendorName: existing.vendorName,
        purchaseDate: existing.purchaseDate,
        batch: existing.batch,
        image: existing.image.isEmpty ? p.image : existing.image,
      );
    }
    return byName.values.toList();
  }

  static String _join(String a, String b) {
    final parts = [a.trim(), b.trim()].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  List<PosProduct> get _filteredProducts => salesSmartSearch(
    _searchTerm,
    _posProducts,
    (p) => [
      [p.name],
      [p.serialNumber],
      [p.vendorName],
      [p.purchaseNumber],
    ],
  );

  static List<String> purchasedSNs(PosProduct p) {
    final raw = p.serialNumber.isNotEmpty
        ? p.serialNumber
        : p.productSerialNumber;
    return parseSalesTokens(raw, [RegExp(r'[\s,\-]+')]);
  }

  static List<String> purchasedModels(PosProduct p) {
    final raw = p.model.isNotEmpty ? p.model : p.productModel;
    return parseSalesTokens(raw, [RegExp(r'[\s,\n\r\t,]+')]);
  }

  // ---------------------------------------------------------------------------
  // Customer selection
  // ---------------------------------------------------------------------------

  List<SalesOption> get _customerOptions => [
    for (final c in _customers)
      SalesOption(id: c.id, name: c.name, secondary: c.phone),
  ];

  List<SalesOption> get _activeOptions {
    switch (_customerType) {
      case 'subscriber':
        return _subscribers;
      case 'customer':
        return _customerOptions;
      case 'dealer':
        return _dealers;
      default:
        return const [];
    }
  }

  String get _selectedName {
    if (_customerId.isEmpty) return '';
    for (final o in _activeOptions) {
      if (o.id == _customerId) {
        final name = o.name;
        if (_customerType == 'subscriber' && name.contains(' | ')) {
          return name.split(' | ').last;
        }
        return name;
      }
    }
    return '';
  }

  String get _selectedInternetId {
    if (_customerType != 'subscriber' || _customerId.isEmpty) return '';
    for (final s in _subscribers) {
      if (s.id == _customerId) return s.secondary;
    }
    return '';
  }

  String get _selectedPhone {
    if (_customerType == 'subscriber') {
      for (final s in _subscribers) {
        if (s.id == _customerId) return s.secondary;
      }
    }
    if (_customerType == 'customer') {
      for (final c in _customers) {
        if (c.id == _customerId) return c.phone;
      }
    }
    if (_customerType == 'dealer') {
      for (final d in _dealers) {
        if (d.id == _customerId) return d.secondary;
      }
    }
    return '';
  }

  void _setCustomerType(String type, bool checked) {
    setState(() {
      if (checked) {
        _customerType = type;
        _customerId = '';
        _existingInstallment = null;
        _pendingSaleItems = [];
        _isInstallment = false;
        _selectedPlanId = '';
        _existingPending = 0;
      } else if (_customerType == type) {
        _customerType = '';
        _customerId = '';
        _existingPending = 0;
      }
    });
  }

  Future<void> _selectCustomer(String id) async {
    setState(() {
      _customerId = id;
      _isInstallment = false;
      _selectedPlanId = '';
      _existingInstallment = null;
      _pendingSaleItems = [];
      _existingPending = 0;
    });
    if (id.isEmpty) return;
    await _fetchInstallment();
    await _fetchPending();
    _populateFromInstallment();
  }

  Future<void> _fetchPending() async {
    final cid = _cid;
    if (cid == null || _customerId.isEmpty) return;
    try {
      final json = await _api.get(
        'pos/promises',
        query: {
          'subscriberId': _customerId,
          'status': 'open',
          'companyId': cid,
        },
      );
      if (!mounted) return;
      var sum = 0.0;
      for (final p in ApiClient.listData(
        json,
      ).whereType<Map<String, dynamic>>()) {
        sum +=
            (p['remainingAmount'] as num?)?.toDouble() ??
            double.tryParse('${p['remainingAmount'] ?? 0}') ??
            0;
      }
      setState(() => _existingPending = sum);
    } catch (_) {
      // ignore — dues lookup is best-effort
    }
  }

  Future<void> _fetchInstallment() async {
    final cid = _cid;
    if (cid == null || _customerId.isEmpty) return;
    setState(() => _fetchingInstallment = true);
    try {
      final json = await _api.get(
        'pos/installment/$_customerId',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      final payload = json['raw'] is Map
          ? json['raw'] as Map
          : (json['data'] is Map ? json['data'] as Map : json);
      final raw = payload['installment'] ?? payload;
      final items = payload['saleItems'];
      setState(() {
        if (raw is Map && raw['id'] != null) {
          final inst = SubscriberInstallment.fromJson(
            raw.cast<String, dynamic>(),
          );
          _existingInstallment = inst;
          _isInstallment = true;
          _selectedPlanId = inst.installmentPlanId;
          _pendingSaleItems = items is List
              ? items
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList()
              : [];
        } else {
          _existingInstallment = null;
          _pendingSaleItems = [];
        }
      });
      _populateFromInstallment();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _existingInstallment = null;
        _pendingSaleItems = [];
      });
    } finally {
      if (mounted) setState(() => _fetchingInstallment = false);
    }
  }

  void _populateFromInstallment() {
    if (_existingInstallment == null ||
        _pendingSaleItems.isEmpty ||
        _posProducts.isEmpty) {
      return;
    }
    if (_cart.isNotEmpty) return;
    final products = _posProducts;
    final items = <_CartItem>[];
    for (final si in _pendingSaleItems) {
      final pid = (si['productId'] ?? '').toString();
      PosProduct? match;
      for (final p in products) {
        if (p.id == pid) {
          match = p;
          break;
        }
      }
      final product =
          match ??
          PosProduct(
            purchaseItemId: pid,
            id: pid,
            name: (si['productName'] ?? '').toString(),
            price: (si['price'] as num?)?.toDouble() ?? 0,
            stock: 0,
            unitType: '',
            taxPercent: (si['taxPercent'] as num?)?.toDouble() ?? 0,
            purchasePrice: 0,
            serialNumber: '',
            productSerialNumber: '',
            currentSerialIndex: 0,
            model: '',
            productModel: '',
            currentModelIndex: 0,
            billId: '',
            purchaseNumber: '',
            vendorName: '',
            purchaseDate: '',
            batch: '',
            image: '',
          );
      items.add(
        _CartItem(
          product: product,
          quantity: (si['quantity'] as num?)?.toInt() ?? 1,
          price: (si['price'] as num?)?.toDouble() ?? product.price,
          selectedSNs: parseSalesTokens((si['serialNumber'] ?? '').toString(), [
            RegExp(r'[\s,\-]+'),
          ]),
          selectedModels: parseSalesTokens((si['model'] ?? '').toString(), [
            RegExp(r'[\s,\n\r\t,]+'),
          ]),
        ),
      );
    }
    setState(() {
      _cart
        ..clear()
        ..addAll(items);
      _pendingSaleItems = [];
    });
  }

  // ---------------------------------------------------------------------------
  // Cart
  // ---------------------------------------------------------------------------

  PosProduct? _productById(String id) {
    for (final p in _posProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _addToCart(String productId) {
    final product = _productById(productId);
    if (product == null) return;
    if (product.stock <= 0) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Out of Stock',
          description: '${product.name} is currently out of stock.',
        ),
      );
      return;
    }
    _CartItem? existing;
    for (final item in _cart) {
      if (item.product.id == productId) {
        existing = item;
        break;
      }
    }
    if (existing != null && existing.quantity >= product.stock) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Stock Limit Reached',
          description: 'You cannot add more of ${product.name}.',
        ),
      );
      return;
    }
    setState(() {
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _cart.add(
          _CartItem(product: product, quantity: 1, price: product.price),
        );
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cart.removeWhere((item) {
        if (item.product.id == productId) {
          item.dispose();
          return true;
        }
        return false;
      });
    });
  }

  void _updateQuantity(String productId, int quantity) {
    final product = _productById(productId);
    if (product == null) return;
    if (quantity <= 0) {
      _removeFromCart(productId);
      return;
    }
    var qty = quantity;
    if (qty > product.stock) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Stock Limit Exceeded',
          description:
              'Only ${product.stock} units of ${product.name} available.',
        ),
      );
      qty = product.stock;
    }
    setState(() {
      for (final item in _cart) {
        if (item.product.id != productId) continue;
        item.quantity = qty;
        if (item.selectedSNs.length > qty) {
          item.selectedSNs.removeRange(qty, item.selectedSNs.length);
        }
        if (item.selectedModels.length > qty) {
          item.selectedModels.removeRange(qty, item.selectedModels.length);
        }
      }
    });
  }

  void _updatePrice(_CartItem item, String raw) {
    final parsed = double.tryParse(raw);
    final normalized = parsed == null
        ? item.product.price
        : (parsed < 0 ? 0.0 : parsed);
    setState(() => item.price = normalized);
  }

  Future<void> _pickTokens(_CartItem item, {required bool sn}) async {
    final options = sn
        ? purchasedSNs(item.product)
        : purchasedModels(item.product);
    if (options.isEmpty) return;
    final selected = sn ? item.selectedSNs : item.selectedModels;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TokenPickerDialog(
        title: sn ? 'Select SN / MAC' : 'Select Model',
        options: options,
        selected: selected,
        max: item.quantity,
        mono: sn,
      ),
    );
    if (result == null) return;
    setState(() {
      if (sn) {
        item.selectedSNs
          ..clear()
          ..addAll(result);
      } else {
        item.selectedModels
          ..clear()
          ..addAll(result);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  double get _subtotal =>
      _cart.fold(0, (sum, item) => sum + item.price * item.quantity);

  double get _tax => _cart.fold(
    0,
    (sum, item) =>
        sum + (item.price * item.quantity) * (item.product.taxPercent / 100),
  );

  SalesPlan? get _selectedPlan {
    for (final p in _plans) {
      if (p.id == _selectedPlanId) return p;
    }
    return null;
  }

  double get _percentageIncrease {
    if (!_isInstallment) return 0;
    final plan = _existingInstallment != null
        ? _plans
              .where((p) => p.id == _existingInstallment!.installmentPlanId)
              .firstOrNull
        : _selectedPlan;
    return plan?.percentageIncrease ?? 0;
  }

  double get _increaseAmount => _subtotal * (_percentageIncrease / 100);

  double get _adjustedSubtotal => _subtotal + _increaseAmount;

  double get _total => _adjustedSubtotal + _tax - _discount;

  double get _maxDiscount {
    final isAdmin = Session.role == 'admin';
    if (isAdmin || _company.posDiscountUnlimited) return _subtotal;
    return (_subtotal * _company.posDiscountPercent / 100).roundToDouble();
  }

  // ---------------------------------------------------------------------------
  // Payment actions
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _expandedItems(_CartItem item) {
    final sns = item.selectedSNs.isNotEmpty
        ? item.selectedSNs
        : purchasedSNs(item.product);
    final models = item.selectedModels;
    if (sns.isEmpty) {
      return [
        {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': item.quantity,
          'price': item.price,
          'originalPrice': item.product.price,
          'taxPercent': item.product.taxPercent,
          'serialNumber': '',
          'model': models.isNotEmpty ? models.first : '',
        },
      ];
    }
    return [
      for (var i = 0; i < sns.length; i++)
        {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': 1,
          'price': item.price,
          'originalPrice': item.product.price,
          'taxPercent': item.product.taxPercent,
          'serialNumber': sns[i],
          'model': i < models.length ? models[i] : '',
        },
    ];
  }

  bool _validateSelectedSNs() {
    for (final item in _cart) {
      final sns = purchasedSNs(item.product);
      if (sns.isEmpty) continue;
      if (item.quantity != item.selectedSNs.length) {
        _showResult(
          _OrderResult(
            success: false,
            title:
                'Select ${item.quantity} SN number${item.quantity > 1 ? 's' : ''}',
            description:
                'Please select ${item.quantity} of ${sns.length} serial number(s) '
                'for ${item.product.name} in the order.',
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _completePayment() async {
    if (_customerId.isEmpty) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Customer not selected',
          description: 'Please select a customer to proceed.',
        ),
      );
      return;
    }
    if (_paymentMethod == null) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Payment method not selected',
          description: 'Please select a payment method.',
        ),
      );
      return;
    }
    if (!_validateSelectedSNs()) return;

    final cid = _cid;
    setState(() => _processing = true);
    try {
      final expanded = [for (final item in _cart) ..._expandedItems(item)];
      if (_isInstallment &&
          _selectedPlanId.isNotEmpty &&
          _existingInstallment == null) {
        await _api.post(
          'pos/installment-sales?companyId=$cid',
          body: {
            'subscriberId': _customerId,
            'subscriberName': _selectedName.isEmpty ? 'Unknown' : _selectedName,
            'installmentPlanId': _selectedPlanId,
            'subtotal': _subtotal,
            'taxAmount': _tax,
            'discount': _discount,
            'paymentMethod': _paymentMethod,
            'date': DateTime.now().toIso8601String(),
            'companyId': cid,
            'items': expanded,
          },
        );
      } else if (_isInstallment && _existingInstallment != null) {
        await _payNextInstallment();
        return;
      } else {
        await _api.post(
          'pos/sales?companyId=$cid',
          body: {
            'subscriberId': _customerId,
            'subscriberName': _selectedName.isEmpty ? 'Unknown' : _selectedName,
            'totalAmount': _total,
            'taxAmount': _tax,
            'discount': _discount,
            'paymentMethod': _paymentMethod,
            'date': DateTime.now().toIso8601String(),
            'companyId': cid,
            'items': expanded,
          },
        );
      }

      _showResult(
        _OrderResult(
          success: true,
          title: _isInstallment
              ? 'Installment Sale Created!'
              : 'Sale Completed!',
          description: _isInstallment
              ? 'First installment has been paid.'
              : 'The transaction has been recorded successfully.',
          items: _cart.length,
          total: _total,
        ),
      );
      _resetOrder();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      _showResult(
        _OrderResult(
          success: false,
          title: 'Payment Failed',
          description: e.message.isEmpty ? 'Failed to process sale' : e.message,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _holdBill() async {
    if (_customerId.isEmpty) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Customer not selected',
          description: 'Please select a customer to hold a bill.',
        ),
      );
      return;
    }
    if (!_validateSelectedSNs()) return;
    final cid = _cid;
    setState(() => _processing = true);
    try {
      final items = [for (final item in _cart) ..._expandedItems(item)];
      await _api.post(
        'pos/sales?companyId=$cid',
        body: {
          'subscriberId': _customerId,
          'subscriberName': _selectedName.isEmpty ? 'Unknown' : _selectedName,
          'totalAmount': _total,
          'taxAmount': _tax,
          'paymentMethod': 'hold',
          'date': DateTime.now().toIso8601String(),
          'companyId': cid,
          'status': 'hold',
          'discount': _discount,
          'items': items,
        },
      );
      _showResult(
        _OrderResult(
          success: true,
          title: 'Bill On Hold',
          description: 'This bill has been held and can be paid later.',
          items: _cart.length,
          total: _total,
        ),
      );
      _resetOrder();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      _showResult(
        _OrderResult(
          success: false,
          title: 'Hold Failed',
          description: e.message.isEmpty ? 'Failed to hold bill' : e.message,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _payNextInstallment() async {
    final inst = _existingInstallment;
    if (inst == null || _customerId.isEmpty) return;
    final cid = _cid;
    final payAmount = inst.installmentAmount > 0
        ? inst.installmentAmount
        : (inst.totalInstallments > 0
              ? inst.totalAmount / inst.totalInstallments
              : 0.0);
    if (payAmount <= 0) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Invalid Amount',
          description: 'Installment amount is zero.',
        ),
      );
      return;
    }
    try {
      await _api.put(
        'pos/installment/${inst.id}/pay?companyId=$cid',
        body: {
          'amount': payAmount,
          'date': DateTime.now().toIso8601String(),
          'method': _paymentMethod ?? 'cash',
        },
      );
      await _fetchInstallment();
      _showResult(
        _OrderResult(
          success: true,
          title: 'Installment Paid!',
          description:
              'PKR ${salesNumber(payAmount)} paid. '
              'Next installment: #${(inst.paidInstallments) + 1}',
          total: payAmount,
        ),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      _showResult(
        _OrderResult(
          success: false,
          title: 'Payment Failed',
          description: e.message.isEmpty
              ? 'Failed to record installment payment'
              : e.message,
        ),
      );
    }
  }

  Future<void> _payDues() async {
    final cid = _cid;
    if (_customerId.isEmpty || cid == null) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Customer not selected',
          description: 'Please select a customer to proceed.',
        ),
      );
      return;
    }
    final amount = double.tryParse(_duesAmount.text) ?? 0;
    if (amount <= 0) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Invalid amount',
          description: 'Enter an amount greater than zero.',
        ),
      );
      return;
    }
    if (amount > _existingPending) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Amount too high',
          description:
              'The customer only owes PKR ${salesNumber(_existingPending)}.',
        ),
      );
      return;
    }
    setState(() => _payingDues = true);
    try {
      final res = await _api.post(
        'pos/dues/pay?companyId=$cid',
        body: {
          'subscriberId': _customerId,
          'subscriberName': _selectedName.isEmpty ? 'Unknown' : _selectedName,
          'amount': amount,
          'paymentMethod': _paymentMethod ?? 'cash',
          'date': DateTime.now().toIso8601String(),
        },
      );
      final remaining =
          (res['data'] is Map ? (res['data'] as Map)['remainingAmount'] : null)
              as num?;
      final left = remaining?.toDouble() ?? 0;
      _showResult(
        _OrderResult(
          success: true,
          title: left > 0 ? 'Dues Collected' : 'All Dues Settled!',
          description: left > 0
              ? 'PKR ${salesNumber(amount)} received. PKR ${salesNumber(left)} still pending for this customer.'
              : 'PKR ${salesNumber(amount)} received. This customer now owes nothing.',
          total: amount,
        ),
      );
      setState(() => _duesAmount.clear());
      await _fetchPending();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      _showResult(
        _OrderResult(
          success: false,
          title: 'Payment Failed',
          description: e.message.isEmpty
              ? 'Failed to record dues payment'
              : e.message,
        ),
      );
    } finally {
      if (mounted) setState(() => _payingDues = false);
    }
  }

  Future<void> _makePromise(
    String paidNowText,
    String promiseDate,
    String description,
  ) async {
    if (_customerId.isEmpty) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Customer not selected',
          description: 'Please select a customer to proceed.',
        ),
      );
      return;
    }
    if (_cart.isEmpty) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Cart is empty',
          description: 'Add products before making a promise.',
        ),
      );
      return;
    }
    if (promiseDate.isEmpty) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Promise date required',
          description: 'Please choose the date the customer will pay by.',
        ),
      );
      return;
    }
    if (!_validateSelectedSNs()) return;

    final paidNow = paidNowText.trim().isEmpty
        ? 0.0
        : (double.tryParse(paidNowText) ?? 0);
    if (paidNow < 0) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Invalid amount',
          description: 'Amount paid now cannot be negative.',
        ),
      );
      return;
    }
    if (paidNow >= _total) {
      _showResult(
        _OrderResult(
          success: false,
          title: 'Nothing left to promise',
          description: 'The amount paid now covers the whole total. Use Complete Payment instead.',
        ),
      );
      return;
    }

    final cid = _cid;
    try {
      final items = [for (final item in _cart) ..._expandedItems(item)];
      await _api.post(
        'pos/promises?companyId=$cid',
        body: {
          'subscriberId': _customerId,
          'subscriberName': _selectedName.isEmpty ? 'Unknown' : _selectedName,
          'internetId': _selectedInternetId,
          'phone': _selectedPhone,
          'totalAmount': _total,
          'taxAmount': _tax,
          'discount': _discount,
          'paymentMethod': _paymentMethod,
          'date': DateTime.now().toIso8601String(),
          'companyId': cid,
          'items': items,
          'paidNow': paidNow,
          'promiseDate': promiseDate,
          'description': description,
        },
      );
      _showResult(
        _OrderResult(
          success: true,
          title: 'Promise Recorded!',
          description:
              'PKR ${salesNumber(_total - paidNow)} is pending payment by $promiseDate.',
          items: _cart.length,
          total: _total,
          paidNow: paidNow,
          pending: _total - paidNow,
        ),
      );
      _resetOrder();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      _showResult(
        _OrderResult(
          success: false,
          title: 'Promise Failed',
          description: e.message.isEmpty
              ? 'Failed to record promise'
              : e.message,
        ),
      );
    }
  }

  void _resetOrder() {
    setState(() {
      _clearCart();
      _customerId = '';
      _customerType = '';
      _isInstallment = false;
      _selectedPlanId = '';
      _existingInstallment = null;
      _existingPending = 0;
      _discount = 0;
    });
  }

  void _showResult(_OrderResult result) {
    if (!mounted) return;
    setState(() => _orderResult = result);
  }

  Future<void> _confirmDeleteProduct() async {
    final product = _productToDelete;
    if (product == null) return;
    final cid = _cid;
    setState(() => _deleting = true);
    try {
      await _api.delete('inventory/products/${product.id}?companyId=$cid');
      await _load();
      if (mounted) showToast(context, '${product.name} has been removed.');
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        showToast(
          context,
          e.message.isEmpty ? 'Could not delete product.' : e.message,
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
          _productToDelete = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NetworkPageHeader(
              icon: Icons.shopping_cart_outlined,
              title: 'Point of Sale (POS)',
              subtitle: 'A retail counter for quick billing, recharges, and device sales.',
              gradient: salesAmberGradient,
            ),
            if (cid == null || cid.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Please select a company to use the POS.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_loading && _rawProducts.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _orderCard(context),
                  const SizedBox(height: 24),
                  _productsCard(context),
                ],
              ),
            const SizedBox(height: 24),
            _dialogs(context),
          ],
        ),
      ),
    );
  }

  Widget _productsCard(BuildContext context) {
    final products = _filteredProducts;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SalesFilterRows(
              rows: [
                [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _searchTerm = v),
                      style: TextStyle(fontSize: 14, color: context.fg),
                      decoration:
                          netInputDecoration(
                            context,
                            hint: 'Search products...',
                          ).copyWith(
                            prefixIcon: Icon(
                              Icons.search,
                              size: 18,
                              color: context.mutedFg,
                            ),
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: products.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No products found.',
                        style: TextStyle(color: context.mutedFg),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      const columns = 3;
                      final width =
                          (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final product in products)
                            SizedBox(
                              width: width,
                              child: _ProductCard(
                                product: product,
                                canDelete: _canDelete,
                                onTap: () => _addToCart(product.id),
                                onDelete: () =>
                                    setState(() => _productToDelete = product),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context) {
    final installment = _installationDetails;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sellToPanel(context),
                if (_customerId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _selectedCustomerPanel(context),
                ],
                if (_customerId.isNotEmpty &&
                    _existingPending > 0 &&
                    _cart.isEmpty) ...[
                  const SizedBox(height: 12),
                  _duesPanel(context),
                ],
                if (_customerId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _installmentPanel(context),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: context.line),
                const SizedBox(height: 12),
                _cartList(context),
              ],
            ),
          ),
          if (_cart.isNotEmpty) ...[
            Divider(height: 1, color: context.line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isInstallment && installment != null) ...[
                    _installmentInfoCard(context, installment),
                    const SizedBox(height: 12),
                  ],
                  if (!_isInstallment) ...[
                    _discountRow(context),
                    const SizedBox(height: 12),
                  ],
                  _totalsBlock(context),
                  const SizedBox(height: 12),
                  _paymentMethods(context),
                  const SizedBox(height: 12),
                  _actions(context, installment),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sellToPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELL TO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: context.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _SellToCheckbox(
                label: 'Subscriber',
                icon: Icons.people_outline,
                color: const Color(0xFF3B82F6),
                checked: _customerType == 'subscriber',
                onChanged: (v) => _setCustomerType('subscriber', v),
              ),
              _SellToCheckbox(
                label: 'Others',
                icon: Icons.person_outline,
                color: const Color(0xFF8B5CF6),
                checked: _customerType == 'customer',
                onChanged: (v) => _setCustomerType('customer', v),
              ),
              _SellToCheckbox(
                label: 'Dealer',
                icon: Icons.handshake_outlined,
                color: const Color(0xFFF59E0B),
                checked: _customerType == 'dealer',
                onChanged: (v) => _setCustomerType('dealer', v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectedCustomerPanel(BuildContext context) {
    final options = _activeOptions;
    final selected = options.where((o) => o.id == _customerId).toList();
    final label = selected.isEmpty ? 'Select...' : selected.first.name;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showDialog<SalesOption>(
                context: context,
                builder: (_) => _OptionPickerDialog(
                  title: _customerType == 'subscriber'
                      ? 'Select Subscriber'
                      : _customerType == 'dealer'
                      ? 'Select Dealer'
                      : 'Select Customer',
                  items: options,
                  selectedId: _customerId,
                ),
              );
              if (picked != null) {
                await _selectCustomer(
                  picked.id == _customerId ? '' : picked.id,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _customerId.isEmpty
                            ? context.mutedFg
                            : context.fg,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: 18, color: context.mutedFg),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeBadge(label: _customerType),
              if (_existingPending > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Already owes PKR ${salesNumber(_existingPending)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC026D3),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => _selectCustomer(''),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _duesPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC026D3).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC026D3).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Collect outstanding dues',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC026D3),
                  ),
                ),
              ),
              Text(
                'Owing: PKR ${salesNumber(_existingPending)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFC026D3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duesAmount,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14, color: context.fg),
                  decoration: netInputDecoration(
                    context,
                    hint: 'Amount (max PKR ${salesNumber(_existingPending)})',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GradientButton(
                label: 'Pay',
                gradient: salesRoseGradient,
                loading: _payingDues,
                onPressed: _payingDues ? null : _payDues,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _installmentPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isInstallment = !_isInstallment;
                if (!_isInstallment) {
                  _selectedPlanId = '';
                  _existingInstallment = null;
                }
              });
            },
            child: Row(
              children: [
                Icon(
                  _isInstallment
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 20,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Text(
                  'Installment Sale',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.fg,
                  ),
                ),
              ],
            ),
          ),
          if (_isInstallment && _existingInstallment == null) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDialog<SalesOption>(
                  context: context,
                  builder: (_) => _OptionPickerDialog(
                    title: 'Select Installment Plan',
                    items: [
                      for (final p in _plans)
                        SalesOption(
                          id: p.id,
                          name:
                              '${p.name} (${p.installments} installments, +${salesNumber(p.percentageIncrease)}%)',
                        ),
                    ],
                    selectedId: _selectedPlanId,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedPlanId = picked.id);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedPlan == null
                            ? 'Select installment plan...'
                            : _selectedPlan!.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: _selectedPlan == null
                              ? context.mutedFg
                              : context.fg,
                        ),
                      ),
                    ),
                    Icon(Icons.expand_more, size: 18, color: context.mutedFg),
                  ],
                ),
              ),
            ),
          ],
          if (_fetchingInstallment) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checking installment status...',
                  style: TextStyle(fontSize: 12, color: context.mutedFg),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cartList(BuildContext context) {
    if (_cart.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Cart is empty',
            style: TextStyle(color: context.mutedFg),
          ),
        ),
      );
    }
    return Column(
      children: [for (final item in _cart) _cartRow(context, item)],
    );
  }

  Widget _cartRow(BuildContext context, _CartItem item) {
    final sns = purchasedSNs(item.product);
    final models = purchasedModels(item.product);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumb(context, item.product, 50),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _miniField(
                        context,
                        label: 'Price',
                        child: TextField(
                          controller: item.priceCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _updatePrice(item, v),
                          style: TextStyle(fontSize: 13, color: context.fg),
                          decoration: _denseInput(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _miniField(
                      context,
                      label: 'Qty',
                      child: _QtyStepper(
                        value: item.quantity,
                        onChanged: (q) => _updateQuantity(item.product.id, q),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sns.isNotEmpty)
                  _tokenButton(
                    context,
                    label:
                        'SN / MAC (${item.selectedSNs.length}/${item.quantity})',
                    icon: Icons.tag,
                    color: const Color(0xFFF59E0B),
                    text: item.selectedSNs.isEmpty
                        ? 'Select SN numbers...'
                        : item.selectedSNs.join(', '),
                    mono: true,
                    onTap: () => _pickTokens(item, sn: true),
                  ),
                if (models.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _tokenButton(
                    context,
                    label:
                        'Model (${item.selectedModels.length}/${item.quantity})',
                    icon: Icons.sell_outlined,
                    color: const Color(0xFF0EA5E9),
                    text: item.selectedModels.isEmpty
                        ? 'Select models...'
                        : item.selectedModels.join(', '),
                    mono: false,
                    onTap: () => _pickTokens(item, sn: false),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${salesNumber(item.price * item.quantity)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.fg,
                ),
              ),
              const SizedBox(height: 4),
              IconButton(
                onPressed: () =>
                    setState(() => _snEntriesProduct = item.product),
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: 'Show all SN entries',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _removeFromCart(item.product.id),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniField(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.mutedFg)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  Widget _tokenButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required String text,
    required bool mono,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 10, color: context.mutedFg),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mono ? 11 : 12,
                      fontFamily: mono ? 'monospace' : null,
                      color: context.fg,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, size: 16, color: context.mutedFg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _installmentInfoCard(BuildContext context, _InstallmentDetails d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 15,
                color: Color(0xFF059669),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.planName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCol(
                  context,
                  'Each Installment',
                  'PKR ${salesNumber(d.amountPerInstallment)}',
                ),
              ),
              Expanded(
                child: _statCol(
                  context,
                  'Total Installments',
                  '${d.totalInstallments}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCol(
                  context,
                  'Paid',
                  '${d.paidInstallments}/${d.totalInstallments}',
                  sub: 'PKR ${salesNumber(d.paidMoney)}',
                  color: const Color(0xFF059669),
                ),
              ),
              Expanded(
                child: _statCol(
                  context,
                  'Remaining',
                  '${d.remainingInstallments}/${d.totalInstallments}',
                  sub: 'PKR ${salesNumber(d.remainingMoney)}',
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCol(
    BuildContext context,
    String label,
    String value, {
    String? sub,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.mutedFg)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? context.fg,
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: color ?? context.mutedFg),
          ),
      ],
    );
  }

  Widget _discountRow(BuildContext context) {
    return Row(
      children: [
        Text(
          'Discount',
          style: TextStyle(fontSize: 13, color: context.mutedFg),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: _discount == 0 ? '' : _discount.toStringAsFixed(0),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v) ?? 0;
              setState(() {
                _discount = parsed < 0
                    ? 0
                    : (parsed > _maxDiscount ? _maxDiscount : parsed);
              });
            },
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: context.fg),
            decoration: _denseInput(
              context,
              hint: '0 (max ${salesNumber(_maxDiscount)})',
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalsBlock(BuildContext context) {
    return Column(
      children: [
        _totalRow(context, 'Subtotal', 'PKR ${salesNumber(_subtotal)}'),
        if (_isInstallment && _percentageIncrease > 0)
          _totalRow(
            context,
            '+ ${salesNumber(_percentageIncrease)}% Increase',
            'PKR ${salesNumber(_increaseAmount)}',
            color: const Color(0xFF059669),
          ),
        if (!_isInstallment && _discount > 0)
          _totalRow(
            context,
            'Discount',
            '- PKR ${salesNumber(_discount)}',
            color: const Color(0xFF10B981),
          ),
        _totalRow(context, 'Tax', 'PKR ${salesFixed2(_tax)}'),
        const Divider(height: 16),
        _totalRow(
          context,
          'Total',
          'PKR ${salesNumber(_isInstallment ? _adjustedSubtotal : _total)}',
          bold: true,
        ),
      ],
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color ?? (bold ? context.fg : context.mutedFg),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? context.fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethods(BuildContext context) {
    Widget btn(String value, String label, IconData icon) {
      final active = _paymentMethod == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _paymentMethod = value),
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              backgroundColor: active ? AppColors.primary : null,
              foregroundColor: active ? Colors.white : null,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn('card', 'Card', Icons.credit_card),
        btn('bank', 'Bank', Icons.account_balance),
        btn('cash', 'Cash', Icons.attach_money),
      ],
    );
  }

  Widget _actions(BuildContext context, _InstallmentDetails? installment) {
    if (!_canCollectPayment) return const SizedBox.shrink();
    if (_isInstallment) {
      final canPay = _existingInstallment == null
          ? (_cart.isNotEmpty && _selectedPlanId.isNotEmpty)
          : (installment != null && installment.remainingInstallments > 0);
      return GradientButton(
        label: _processing
            ? 'Processing...'
            : 'Pay Installment - PKR ${salesNumber(installment?.amountPerInstallment ?? 0)}',
        gradient: salesEmeraldGradient,
        icon: _processing ? null : Icons.receipt_long_outlined,
        loading: _processing,
        onPressed: (!canPay || _processing) ? null : _completePayment,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_cart.isEmpty || _processing) ? null : _holdBill,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Hold Bill'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GradientButton(
                label: _processing ? 'Processing...' : 'Complete Payment',
                gradient: salesEmeraldGradient,
                loading: _processing,
                onPressed: (_cart.isEmpty || _processing)
                    ? null
                    : _completePayment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (_cart.isEmpty || _processing) ? null : _openPromiseDialog,
          icon: const Icon(Icons.handshake_outlined, size: 16),
          label: const Text('Make a Promise'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: const Color(0xFFB45309),
            side: const BorderSide(color: Color(0xFFFCD34D)),
          ),
        ),
      ],
    );
  }

  Future<void> _openPromiseDialog() async {
    final result =
        await showDialog<({String paidNow, String date, String description})>(
          context: context,
          builder: (_) => _PromiseDialog(total: _total, items: _cart.length),
        );
    if (result == null) return;
    await _makePromise(result.paidNow, result.date, result.description);
  }

  _InstallmentDetails? get _installationDetails {
    if (!_isInstallment) return null;
    final existing = _existingInstallment;
    if (existing != null) {
      final paid = existing.paidInstallments;
      final total = existing.totalInstallments;
      final remaining = total - paid;
      final totalAmount = existing.totalAmount;
      final instAmount = existing.installmentAmount > 0
          ? existing.installmentAmount
          : totalAmount / (total == 0 ? 1 : total);
      return _InstallmentDetails(
        planName: existing.planName.isEmpty
            ? 'Installment Plan'
            : existing.planName,
        amountPerInstallment: instAmount,
        totalInstallments: total,
        paidInstallments: paid,
        remainingInstallments: remaining,
        paidMoney: paid * instAmount,
        remainingMoney: remaining * instAmount,
      );
    }
    final plan = _selectedPlan;
    if (plan != null) {
      final pct = plan.percentageIncrease;
      final totalWithIncrease = _subtotal * (1 + pct / 100);
      final perInstallment = plan.installments > 0
          ? totalWithIncrease / plan.installments
          : 0.0;
      return _InstallmentDetails(
        planName: plan.name,
        amountPerInstallment: perInstallment,
        totalInstallments: plan.installments,
        paidInstallments: 0,
        remainingInstallments: plan.installments,
        paidMoney: 0,
        remainingMoney: totalWithIncrease,
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  Widget _dialogs(BuildContext context) {
    return Column(
      children: [
        _buildDeleteDialog(context),
        _buildSnEntries(context),
        _buildResultDialog(context),
      ],
    );
  }

  Widget _buildDeleteDialog(BuildContext context) {
    return _ModalShell(
      open: _productToDelete != null,
      onClose: () => setState(() => _productToDelete = null),
      title: 'Delete product?',
      actions: [
        TextButton(
          onPressed: _deleting
              ? null
              : () => setState(() => _productToDelete = null),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: _deleting ? 'Deleting...' : 'Delete',
          gradient: salesRoseGradient,
          loading: _deleting,
          onPressed: _deleting ? null : _confirmDeleteProduct,
        ),
      ],
      child: Text(
        'This will permanently delete ${_productToDelete?.name ?? ''} and cannot be undone.',
        style: TextStyle(fontSize: 14, color: context.mutedFg),
      ),
    );
  }

  Widget _buildSnEntries(BuildContext context) {
    final product = _snEntriesProduct;
    final sns = product == null ? const <String>[] : purchasedSNs(product);
    final models = product == null
        ? const <String>[]
        : purchasedModels(product);
    return _ModalShell(
      open: product != null,
      onClose: () => setState(() => _snEntriesProduct = null),
      title: 'All SN entries',
      child: product == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                ),
                const SizedBox(height: 10),
                if (sns.isEmpty)
                  Text(
                    'No SN entries.',
                    style: TextStyle(color: context.mutedFg),
                  )
                else
                  for (var i = 0; i < sns.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.subtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sns[i],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Text(
                            i < models.length ? models[i] : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PKR ${salesNumber(product.price)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }

  Widget _buildResultDialog(BuildContext context) {
    final result = _orderResult;
    return _ModalShell(
      open: result != null,
      onClose: () => setState(() => _orderResult = null),
      title: result?.title ?? '',
      leading: result == null
          ? null
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (result.success
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444))
                        .withValues(alpha: 0.15),
              ),
              child: Icon(
                result.success ? Icons.check_circle : Icons.cancel,
                color: result.success
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                size: 24,
              ),
            ),
      actions: [
        GradientButton(
          label: result?.success == true ? 'Done' : 'Close',
          gradient: result?.success == true
              ? salesEmeraldGradient
              : salesRoseGradient,
          onPressed: () => setState(() => _orderResult = null),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result?.description ?? '',
            style: TextStyle(fontSize: 14, color: context.mutedFg),
          ),
          if (result?.success == true && result?.items != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.subtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.line),
              ),
              child: Column(
                children: [
                  _totalRow(context, 'Items', '${result!.items}'),
                  _totalRow(
                    context,
                    'Total',
                    'PKR ${salesNumber(result.total)}',
                    bold: true,
                  ),
                  if (result.paidNow != null)
                    _totalRow(
                      context,
                      'Paid Now',
                      'PKR ${salesNumber(result.paidNow)}',
                    ),
                  if (result.pending != null)
                    _totalRow(
                      context,
                      'Pending',
                      'PKR ${salesNumber(result.pending)}',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context, PosProduct product, double size) {
    final url = salesBackendImageUrl(product.image);
    final letter = product.name.isEmpty
        ? '?'
        : product.name.characters.first.toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _letterTile(context, letter, size)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _letterTile(context, letter, size),
              ),
      ),
    );
  }

  Widget _letterTile(BuildContext context, String letter, double size) {
    return Container(
      color: context.subtle,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: context.mutedFg,
        ),
      ),
    );
  }

  InputDecoration _denseInput(BuildContext context, {String? hint}) {
    return netInputDecoration(context, hint: hint).copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

class _InstallmentDetails {
  _InstallmentDetails({
    required this.planName,
    required this.amountPerInstallment,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.remainingInstallments,
    required this.paidMoney,
    required this.remainingMoney,
  });

  final String planName;
  final double amountPerInstallment;
  final int totalInstallments;
  final int paidInstallments;
  final int remainingInstallments;
  final double paidMoney;
  final double remainingMoney;
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  final PosProduct product;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final url = salesBackendImageUrl(product.image);
    final letter = product.name.isEmpty
        ? '?'
        : product.name.characters.first.toUpperCase();
    final sns = _PointOfSaleScreenState.purchasedSNs(product);
    final models = _PointOfSaleScreenState.purchasedModels(product);
    final currentSn = sns.isEmpty
        ? null
        : (product.currentSerialIndex < sns.length
              ? sns[product.currentSerialIndex]
              : sns.first);
    final currentModel = models.isEmpty
        ? null
        : (product.currentModelIndex < models.length
              ? models[product.currentModelIndex]
              : models.first);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 244,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: url == null
                            ? _letter(context, letter)
                            : Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _letter(context, letter),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _StockBadge(stock: product.stock),
                      ),
                      if (canDelete)
                        Positioned(
                          top: 2,
                          left: 2,
                          child: _CardMenu(onDelete: onDelete),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.fg,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'PKR ${salesNumber(product.price)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.fg,
                          ),
                        ),
                        if (currentSn != null)
                          Text(
                            'SN: $currentSn'
                            '${sns.length > 1 ? ' (${product.currentSerialIndex + 1}/${sns.length})' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: context.mutedFg,
                            ),
                          ),
                        if (currentModel != null)
                          Text(
                            'Model: $currentModel'
                            '${models.length > 1 ? ' (+${models.length - 1})' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.isDark
                                  ? const Color(0xFF7DD3FC)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _letter(BuildContext context, String letter) => Container(
    color: context.subtle,
    alignment: Alignment.center,
    child: Text(
      letter,
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: context.mutedFg,
      ),
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    final color = out ? const Color(0xFFDC2626) : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: out ? color : context.surface,
        borderRadius: BorderRadius.circular(999),
        border: out ? null : Border.all(color: context.line),
      ),
      child: Text(
        out ? 'Out of Stock' : 'Stock: $stock',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: out ? Colors.white : context.mutedFg,
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Actions',
        icon: const Icon(Icons.more_vert, size: 16),
        padding: EdgeInsets.zero,
        onSelected: (v) {
          if (v == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellToCheckbox extends StatelessWidget {
  const _SellToCheckbox({
    required this.label,
    required this.icon,
    required this.color,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.line),
      ),
      child: Text(
        label.isEmpty ? '-' : label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.mutedFg,
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(context, Icons.remove, () => onChanged(value - 1)),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.fg),
            ),
          ),
          _step(context, Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: context.mutedFg),
      ),
    );
  }
}

class _OptionPickerDialog extends StatefulWidget {
  const _OptionPickerDialog({
    required this.title,
    required this.items,
    required this.selectedId,
  });

  final String title;
  final List<SalesOption> items;
  final String? selectedId;

  @override
  State<_OptionPickerDialog> createState() => _OptionPickerDialogState();
}

class _OptionPickerDialogState extends State<_OptionPickerDialog> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<SalesOption> get _filtered => salesSmartSearch(
    _query,
    widget.items,
    (o) => [
      [o.id],
      [o.name, o.secondary],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _filter,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 14, color: context.fg),
              decoration: netInputDecoration(context, hint: 'Search...')
                  .copyWith(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: context.mutedFg,
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final option = _filtered[i];
                        final selected = option.id == widget.selectedId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            option.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: option.secondary.isEmpty
                              ? null
                              : Text(
                                  option.secondary,
                                  style: const TextStyle(fontSize: 11),
                                ),
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _TokenPickerDialog extends StatefulWidget {
  const _TokenPickerDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.max,
    required this.mono,
  });

  final String title;
  final List<String> options;
  final List<String> selected;
  final int max;
  final bool mono;

  @override
  State<_TokenPickerDialog> createState() => _TokenPickerDialogState();
}

class _TokenPickerDialogState extends State<_TokenPickerDialog> {
  late final List<String> _selected = [...widget.selected];
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  List<String> get _unique {
    final seen = <String>{};
    final out = <String>[];
    for (final o in widget.options) {
      if (seen.add(o)) out.add(o);
    }
    return out;
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _unique;
    return _unique.where((s) => s.toLowerCase().contains(q)).toList();
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.remove(value)) return;
      if (_selected.length >= widget.max) return;
      _selected.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedSet = _selected.toSet();
    final full = widget.max > 0 && _selected.length == widget.max;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _filter,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: 14, color: context.fg),
              decoration: netInputDecoration(context, hint: 'Search...')
                  .copyWith(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: context.mutedFg,
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching entry found',
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final value = _filtered[i];
                        final checked = selectedSet.contains(value);
                        final disabled = !checked && full;
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          onChanged: disabled ? null : (_) => _toggle(value),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            value,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: widget.mono ? 'monospace' : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (full)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'All selected — uncheck to change',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.isDark
                        ? const Color(0xFF34D399)
                        : const Color(0xFF059669),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _PromiseDialog extends StatefulWidget {
  const _PromiseDialog({required this.total, required this.items});

  final double total;
  final int items;

  @override
  State<_PromiseDialog> createState() => _PromiseDialogState();
}

class _PromiseDialogState extends State<_PromiseDialog> {
  final TextEditingController _paidNow = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _date = salesToday();

  @override
  void dispose() {
    _paidNow.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(_paidNow.text);
    return AlertDialog(
      title: const Text('Make a Promise', style: TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'The sale and stock are recorded now. Anything not paid today is '
                'kept as a separate pending amount for this customer.',
                style: TextStyle(fontSize: 13, color: context.mutedFg),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.subtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.line),
                ),
                child: Column(
                  children: [
                    _row(
                      context,
                      'Sale total',
                      'PKR ${salesNumber(widget.total)}',
                    ),
                    _row(context, 'Items', '${widget.items}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Paid now (PKR)',
                style: TextStyle(fontSize: 12, color: context.fg),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _paidNow,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: context.fg),
                decoration: _dense(context, hint: '0'),
              ),
              const SizedBox(height: 12),
              Text(
                'Payment date',
                style: TextStyle(fontSize: 12, color: context.fg),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final initial = DateTime.tryParse(_date) ?? now;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked == null) return;
                  setState(() {
                    _date =
                        '${picked.year.toString().padLeft(4, '0')}-'
                        '${picked.month.toString().padLeft(2, '0')}-'
                        '${picked.day.toString().padLeft(2, '0')}';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _date,
                          style: TextStyle(fontSize: 14, color: context.fg),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: context.mutedFg,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: TextStyle(fontSize: 12, color: context.fg),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _description,
                style: TextStyle(fontSize: 14, color: context.fg),
                decoration: _dense(
                  context,
                  hint: 'Optional note about this promise',
                ),
              ),
              if (parsed != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pending after today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'PKR ${salesNumber(widget.total - parsed)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Record Promise',
          gradient: salesAmberGradient,
          onPressed: () => Navigator.of(context).pop((
            paidNow: _paidNow.text,
            date: _date,
            description: _description.text,
          )),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  InputDecoration _dense(BuildContext context, {String? hint}) =>
      netInputDecoration(context, hint: hint).copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      );
}

/// Minimal modal shell used for the delete / SN-entries / result dialogs. Keeps
/// a single dialog widget alive and shows it when [open] is true, matching the
/// web's controlled dialogs.
class _ModalShell extends StatelessWidget {
  const _ModalShell({
    required this.open,
    required this.onClose,
    required this.title,
    this.actions = const [],
    this.leading,
    required this.child,
  });

  final bool open;
  final VoidCallback onClose;
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return _ModalHost(
      open: open,
      onClose: onClose,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(width: 400, child: child),
        actions: actions.isEmpty ? null : [...actions],
      ),
    );
  }
}

/// Renders [builder] as a dialog while [open] is true, without pushing a route.
/// This mirrors the web's controlled `Dialog open=...` pattern so the POS state
/// (cart, totals) stays mounted behind the overlay.
class _ModalHost extends StatefulWidget {
  const _ModalHost({
    required this.open,
    required this.onClose,
    required this.builder,
  });

  final bool open;
  final VoidCallback onClose;
  final WidgetBuilder builder;

  @override
  State<_ModalHost> createState() => _ModalHostState();
}

class _ModalHostState extends State<_ModalHost> {
  bool _visible = false;
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.open;
    if (_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _push());
    }
  }

  @override
  void didUpdateWidget(covariant _ModalHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      setState(() => _visible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _push());
    } else if (!widget.open && oldWidget.open) {
      _visible = false;
      if (_pushed) {
        _pushed = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _push() async {
    if (_pushed || !_visible) return;
    _pushed = true;
    await showDialog<void>(context: context, builder: widget.builder);
    _pushed = false;
    if (_visible && mounted && widget.open) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
