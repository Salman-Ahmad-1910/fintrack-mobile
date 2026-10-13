import 'dart:convert';
import 'dart:typed_data';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/api_config.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/admin/company_profile_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the fully-loaded Company Profile form (real company payload through
/// a fake HTTP layer) so bugs in the loaded branch are caught here instead of
/// on the device. The page issues its own network calls in initState, which is
/// why the static ApiClient client is swapped for a MockClient first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyId = 'company-1';
  final companyJson = <String, dynamic>{
    'id': companyId,
    'name': 'SkyNet Broadband',
    'email': 'billing@skynet.pk',
    'contact1': '+92 300 1234567',
    'contact2': '+92 51 1234567',
    'address': 'Blue Area, Islamabad',
    'description': 'Fiber home internet provider.',
    'logo': '',
    'stamp': '',
    'posDiscountPercent': 10,
    'posDiscountUnlimited': true,
    'createdAt': '2026-01-01T00:00:00Z',
    'updatedAt': '2026-01-01T00:00:00Z',
  };

  // Tiny 1x1 transparent PNG so Image.network decodes instead of erroring.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userName': 'Ali Khan',
      'userEmail': 'ali@example.com',
      'selectedCompanyName': 'SkyNet',
      'selectedCompanyId': companyId,
      'userRole': 'admin',
      'api_base': 'http://test/api/v1',
    });
    await Session.load();
    ApiConfig.use('http://test');
    ApiClient.useClientForTesting(
      MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/uploads/')) {
          return http.Response.bytes(
            Uint8List.fromList(pngBytes),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (request.url.path == '/api/v1/admin/companies/$companyId') {
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Record found',
              'data': companyJson,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        return http.Response('{"success":false,"message":"not found"}', 404);
      }),
    );
  });

  Future<void> pumpCompanyProfile(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: CompanyProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('loaded company profile shows the full edit form', (tester) async {
    await pumpCompanyProfile(tester, const Size(1200, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('Company Profile'), findsWidgets);
    expect(find.text('SkyNet Broadband'), findsWidgets);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Contact Email'), findsOneWidget);
    expect(find.text('POS Discount Limit (%)'), findsOneWidget);
    expect(find.text('Company Stamp'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loaded profile form has no overflow at phone width', (
    tester,
  ) async {
    await pumpCompanyProfile(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Company Stamp'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}