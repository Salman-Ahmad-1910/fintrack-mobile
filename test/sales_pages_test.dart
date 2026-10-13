import 'dart:convert';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/api_config.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/sales/installment_plans_screen.dart';
import 'package:fintrack/features/sales/point_of_sale_screen.dart';
import 'package:fintrack/features/sales/replaced_products_screen.dart';
import 'package:fintrack/features/sales/sales_customers_screen.dart';
import 'package:fintrack/features/sales/sales_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke coverage for the five Sales / POS screens: each header, a
/// representative row and the phone-width layout must render without throwing.
/// Data is served through a fake HTTP layer because every screen fetches in
/// initState.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyId = 'company-1';

  final companies = [
    {
      'id': companyId,
      'name': 'SkyNet',
      'address': '123 Main Street, Karachi',
      'contact1': '0300-1234567',
      'logo': '',
      'stamp': '',
      'posDiscountPercent': 5,
      'posDiscountUnlimited': false,
    },
  ];
  final sales = [
    {
      'id': 'sale-1',
      'subscriberId': 'sub-1',
      'subscriberName': 'Ahmed Khan',
      'totalAmount': 4500,
      'taxAmount': 250,
      'discount': 0,
      'paymentMethod': 'cash',
      'status': 'completed',
      'date': '2026-03-15T10:30:00Z',
      'isInstallment': false,
      'replacedFrom': '',
      'saleType': 'pos',
      'paidAmount': 4500,
      'paymentStatus': 'paid',
      'promisePayment': false,
      'items': [
        {
          'id': 'item-1',
          'saleId': 'sale-1',
          'productId': 'prod-1',
          'productName': 'Router X',
          'quantity': 1,
          'price': 4250,
          'originalPrice': 4000,
          'taxPercent': 0,
          'saleTax': 250,
          'wthTax': 0,
          'serialNumber': 'SN-ROUTER-001',
          'model': 'RX-100',
        },
      ],
    },
    {
      'id': 'sale-2',
      'subscriberId': 'sub-2',
      'subscriberName': 'Bilal Ahmed',
      'totalAmount': 2000,
      'taxAmount': 0,
      'discount': 0,
      'paymentMethod': 'cash',
      'status': 'replaced',
      'date': '2026-03-10T09:00:00Z',
      'isInstallment': false,
      'replacedFrom': jsonEncode({
        'items': [
          {
            'id': 'item-old-1',
            'saleId': 'sale-2',
            'productId': 'prod-old-1',
            'productName': 'Old Adapter',
            'quantity': 2,
            'price': 1000,
            'originalPrice': 900,
            'taxPercent': 0,
            'saleTax': 0,
            'wthTax': 0,
            'serialNumber': 'SN-OLD-001, SN-OLD-002',
            'model': 'AD-200',
          },
        ],
      }),
      'saleType': 'pos',
      'paidAmount': 2000,
      'paymentStatus': 'paid',
      'promisePayment': false,
      'items': [
        {
          'id': 'item-2',
          'saleId': 'sale-2',
          'productId': 'prod-2',
          'productName': 'New Adapter',
          'quantity': 2,
          'price': 1000,
          'originalPrice': 900,
          'taxPercent': 0,
          'saleTax': 0,
          'wthTax': 0,
          'serialNumber': 'SN-NEW-001, SN-NEW-002',
          'model': 'AD-300',
        },
      ],
    },
  ];
  final plans = [
    {
      'id': 'plan-1',
      'name': '6-Month Easy Plan',
      'installments': 6,
      'percentageIncrease': 10,
      'status': 'active',
      'companyId': companyId,
    },
  ];
  final customers = [
    {
      'id': 'cust-1',
      'name': 'Sara Ali',
      'cnic': '42201-1234567-8',
      'phone': '0300-1234567',
      'city': 'Karachi',
      'status': 'active',
      'totalInvoices': 3,
      'outstandingBalance': 1500,
      'companyId': companyId,
    },
  ];
  final products = [
    {
      'purchaseItemId': 'pi-1',
      'id': 'prod-1',
      'name': 'Router X',
      'price': 4250,
      'stock': 4,
      'unitType': 'piece',
      'taxPercent': 0,
      'purchasePrice': 3000,
      'serialNumber': 'SN-ROUTER-001, SN-ROUTER-002',
      'productSerialNumber': '',
      'currentSerialIndex': 0,
      'model': 'RX-100, RX-101',
      'productModel': '',
      'currentModelIndex': 0,
      'billId': 'bill-1',
      'purchaseNumber': 'PO-001',
      'vendorName': 'Tech Supplies',
      'purchaseDate': '2026-01-05',
      'batch': 'B1',
      'image': '',
    },
  ];
  final dealers = [
    {
      'id': 'dealer-1',
      'name': 'Metro Traders',
      'phone': '0301-2223334',
      'companyId': companyId,
    },
  ];
  final connections = [
    {
      'id': 'conn-1',
      'internetId': 'IN-001',
      'name': 'Ahmed Khan',
      'phone': '03001234567',
      'cell': '03001234567',
      'mobile': '03127654321',
      'companyId': companyId,
    },
  ];
  final promises = [
    {
      'id': 'promise-1',
      'subscriberId': 'sub-1',
      'remainingAmount': 1200,
      'status': 'open',
      'promiseDate': '2026-04-01',
      'companyId': companyId,
    },
  ];
  final installment = {
    'id': 'inst-1',
    'saleId': 'sale-1',
    'subscriberId': 'sub-1',
    'subscriberName': 'Ahmed Khan',
    'installmentPlanId': 'plan-1',
    'planName': '6-Month Easy Plan',
    'totalInstallments': 6,
    'paidInstallments': 2,
    'installmentAmount': 800,
    'totalAmount': 4800,
    'nextInstallment': 3,
    'status': 'active',
    'createdAt': '2026-03-15T10:30:00Z',
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userName': 'Ali Khan',
      'userEmail': 'ali@example.com',
      'selectedCompanyName': 'SkyNet',
      'selectedCompanyId': companyId,
      'userRole': 'admin',
    });
    await Session.load();
    ApiConfig.use('http://test');
    ApiClient.useClientForTesting(
      MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/api/v1/pos/installment/')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'data': {'installment': installment, 'saleItems': []},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        List<dynamic>? payload;
        if (path == '/api/v1/pos/sales') payload = sales;
        if (path == '/api/v1/sales/installment-plans') payload = plans;
        if (path == '/api/v1/crm/customers') payload = customers;
        if (path == '/api/v1/inventory/purchased-products') payload = products;
        if (path == '/api/v1/companies') payload = companies;
        if (path == '/api/v1/dealers') payload = dealers;
        if (path == '/api/v1/admin/connections') payload = connections;
        if (path == '/api/v1/pos/promises') payload = promises;
        if (payload != null) {
          return http.Response(
            jsonEncode({'success': true, 'message': 'ok', 'data': payload}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success":false,"message":"not found"}', 404);
      }),
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(body: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('sales screen renders header and sample row', (tester) async {
    await pump(tester, const SalesScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Sales'), findsWidgets);
    expect(find.text('Ahmed Khan'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('replaced products screen renders header and flattened row', (
    tester,
  ) async {
    await pump(tester, const ReplacedProductsScreen(), const Size(1400, 1000));
    expect(tester.takeException(), isNull);
    expect(find.text('Replaced Products'), findsWidgets);
    expect(find.text('Old Adapter'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sales customers screen renders header and sample row', (
    tester,
  ) async {
    await pump(tester, const SalesCustomersScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Customers'), findsWidgets);
    expect(find.text('Sara Ali'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('installment plans screen renders header and sample row', (
    tester,
  ) async {
    await pump(tester, const InstallmentPlansScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Installment Plans'), findsWidgets);
    expect(find.text('6-Month Easy Plan'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pos screen renders header and a stock product', (tester) async {
    await pump(tester, const PointOfSaleScreen(), const Size(1400, 1200));
    expect(tester.takeException(), isNull);
    expect(find.text('Point of Sale (POS)'), findsWidgets);
    expect(find.text('Order Details'), findsWidgets);
    expect(find.text('Router X'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each sales screen is overflow-free at phone width', (
    tester,
  ) async {
    for (final screen in const [
      SalesScreen(),
      ReplacedProductsScreen(),
      SalesCustomersScreen(),
      InstallmentPlansScreen(),
      PointOfSaleScreen(),
    ]) {
      await pump(tester, screen, const Size(390, 844));
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
