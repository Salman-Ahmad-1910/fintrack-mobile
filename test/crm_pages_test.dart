import 'dart:convert';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/api_config.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/crm/corporate_screen.dart';
import 'package:fintrack/features/crm/customers_screen.dart';
import 'package:fintrack/features/crm/guarantors_screen.dart';
import 'package:fintrack/features/crm/inquiries_screen.dart';
import 'package:fintrack/features/crm/packages_screen.dart';
import 'package:fintrack/features/crm/subscriber_detail_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke coverage for the six Subscribers Management / CRM screens: each
/// header, a representative row and the phone-width layout must render without
/// throwing. Data is served through a fake HTTP layer because every screen
/// fetches in initState.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyId = 'company-1';

  final customers = [
    {
      'id': 'cu1',
      'name': 'Ali Raza',
      'cnic': '42201-1234567-8',
      'phone': '0300-1234567',
      'city': 'Karachi',
      'status': 'active',
      'outstandingBalance': 1500,
      'companyId': companyId,
    },
  ];
  final guarantors = [
    {
      'id': 'g1',
      'name': 'Guarantor One',
      'cnic': '42201-7654321-1',
      'phone': '0301-7654321',
      'customerId': 'cu1',
      'customerName': 'Ali Raza',
      'companyId': companyId,
    },
  ];
  final corporate = [
    {
      'id': 'corp1',
      'companyName': 'Acme Corp',
      'contactPerson': 'John Doe',
      'contactPhone': '0300-1112223',
      'negotiatedPricing': 'Flat 10%',
      'contractStartDate': '2026-01-01',
      'contractEndDate': '2026-12-31',
      'totalConnections': 25,
      'companyId': companyId,
    },
  ];
  final packages = [
    {
      'id': 'pk1',
      'packageNumber': 'PKG-001',
      'name': 'Bronze',
      'speed': '10 Mbps',
      'price': 1500,
      'salePrice': 1400,
      'purchasePrice': 1000,
      'packageType': 'Internet',
      'companyName': 'SkyNet',
      'companyId': companyId,
    },
    {
      'id': 'pk2',
      'packageNumber': 'PKG-002',
      'name': 'Basic Cable',
      'price': 900,
      'salePrice': 850,
      'purchasePrice': 600,
      'packageType': 'TV Cable',
      'companyName': 'SkyNet',
      'companyId': companyId,
    },
  ];
  final inquiries = [
    {
      'id': 'inq1',
      'name': 'Lead One',
      'internetId': 'IN-100',
      'cell': '0300-1234567',
      'mobile': '0312-7654321',
      'address': 'House 1, DHA',
      'connectionType': 'both',
      'installationDate': '2026-03-15',
      'status': 'new',
      'companyId': companyId,
    },
  ];
  final connections = [
    {
      'id': 'conn1',
      'internetId': 'IN-001',
      'name': 'Ahmed Khan',
      'address': 'Street 1, DHA',
      'cell': '03001234567',
      'mobile': '03127654321',
      'connectionType': 'both',
      'installationDate': '2026-02-01',
      'packageCable': 'Basic Cable',
      'packageInternet': 'Bronze',
      'status': 'active',
      'sublocalityId': 'a1',
      'companyId': companyId,
    },
  ];
  final areas = [
    {
      'id': 'a1',
      'city': 'Karachi',
      'zone': 'South',
      'locality': 'DHA',
      'subLocality': 'Street 1',
      'companyId': companyId,
    },
  ];
  final boxes = [
    {'id': 'b1', 'name': 'BX-001', 'companyId': companyId},
  ];
  final companies = [
    {'id': companyId, 'name': 'SkyNet'},
  ];
  final splitters = [
    {
      'id': 's1',
      'name': 'DHA-P6-S1',
      'location': 'Street 5',
      'oltId': 'o1',
      'totalPorts': 8,
      'availablePorts': 5,
      'companyId': companyId,
    },
  ];

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
        List<dynamic>? payload;
        if (path == '/api/v1/crm/customers') payload = customers;
        if (path == '/api/v1/crm/guarantors') payload = guarantors;
        if (path == '/api/v1/subscribers/corporate') payload = corporate;
        if (path == '/api/v1/billing/packages') payload = packages;
        if (path == '/api/v1/subscribers/inquiries') payload = inquiries;
        if (path == '/api/v1/subscribers') payload = connections;
        if (path == '/api/v1/admin/connections') payload = connections;
        if (path == '/api/v1/network/areas') payload = areas;
        if (path == '/api/v1/network/boxes') payload = boxes;
        if (path == '/api/v1/network/splitters') payload = splitters;
        if (path == '/api/v1/companies') payload = companies;
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

  testWidgets('customers screen renders header and sample row', (tester) async {
    await pump(tester, const CustomersScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Customers'), findsWidgets);
    expect(find.text('Ali Raza'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('guarantors screen renders header and sample row', (tester) async {
    await pump(tester, const GuarantorsScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Guarantors'), findsWidgets);
    expect(find.text('Guarantor One'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('corporate screen renders header and sample row', (tester) async {
    await pump(tester, const CorporateScreen(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Corporate Clients'), findsWidgets);
    expect(find.text('Acme Corp'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('packages screen renders header and package rows', (tester) async {
    await pump(tester, const PackagesScreen(), const Size(1400, 1200));
    expect(tester.takeException(), isNull);
    expect(find.text('Internet Packages'), findsWidgets);
    expect(find.text('Bronze'), findsWidgets);
    expect(find.text('Basic Cable'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inquiries screen renders header and sample row', (tester) async {
    await pump(tester, const InquiriesScreen(), const Size(1600, 1000));
    expect(tester.takeException(), isNull);
    expect(find.text('New Inquiries'), findsWidgets);
    expect(find.text('Lead One'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('subscriber detail renders header and sample row', (tester) async {
    await pump(tester, const SubscriberDetailScreen(), const Size(1600, 1000));
    expect(tester.takeException(), isNull);
    expect(find.text('Subscriber Detail'), findsWidgets);
    expect(find.text('Ahmed Khan'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each crm screen is overflow-free at phone width', (
    tester,
  ) async {
    for (final screen in const [
      CustomersScreen(),
      GuarantorsScreen(),
      CorporateScreen(),
      PackagesScreen(),
      InquiriesScreen(),
      SubscriberDetailScreen(),
    ]) {
      await pump(tester, screen, const Size(390, 844));
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
