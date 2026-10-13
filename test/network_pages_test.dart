import 'dart:convert';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/api_config.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/network/areas_screen.dart';
import 'package:fintrack/features/network/boxes_screen.dart';
import 'package:fintrack/features/network/olt_screen.dart';
import 'package:fintrack/features/network/pop_screen.dart';
import 'package:fintrack/features/network/splitters_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke coverage for the five Network CRUD screens: each header, its sample
/// rows and the phone-width layout must render without throwing. Data is
/// served through a fake HTTP layer because every screen fetches in initState.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyId = 'company-1';

  final areas = [
    {
      'id': 'a1',
      'city': 'Karachi',
      'zone': 'South',
      'locality': 'DHA Phase 6',
      'subLocality': 'Street 1',
      'companyId': companyId,
    },
  ];
  final pops = [
    {
      'id': 'p1',
      'name': 'DHA POP',
      'location': 'Office 1',
      'status': 'online',
      'companyId': companyId,
    },
  ];
  final olts = [
    {
      'id': 'o1',
      'name': 'DHA-OLT-1',
      'location': 'DHA P6',
      'ipAddress': '10.10.1.1',
      'ports': 16,
      'popId': 'p1',
      'companyId': companyId,
    },
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
  final boxes = [
    {'id': 'b1', 'name': 'BX-001', 'companyId': companyId},
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
        if (path == '/api/v1/network/areas') payload = areas;
        if (path == '/api/v1/network/pops') payload = pops;
        if (path == '/api/v1/network/olts') payload = olts;
        if (path == '/api/v1/network/splitters') payload = splitters;
        if (path == '/api/v1/network/boxes') payload = boxes;
        if (payload != null) {
          return http.Response(
            jsonEncode({'success': true, 'message': 'ok', 'data': payload}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"success":false,"message":"not found"}',
          404,
        );
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

  testWidgets('areas screen renders header and sample row', (tester) async {
    await pump(tester, const AreasScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Area Management'), findsOneWidget);
    expect(find.text('Karachi'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pop screen renders header and status badge', (tester) async {
    await pump(tester, const PopScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('POP Management'), findsOneWidget);
    expect(find.text('DHA POP'), findsWidgets);
    expect(find.text('online'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('olt screen renders header and IP address', (tester) async {
    await pump(tester, const OltScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('OLT Management'), findsOneWidget);
    expect(find.text('10.10.1.1'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('splitters screen renders header and utilisation', (tester) async {
    await pump(tester, const SplittersScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Splitter Management'), findsOneWidget);
    expect(find.text('DHA-P6-S1'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('boxes screen renders header and box number', (tester) async {
    await pump(tester, const BoxesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Box / Media Management'), findsOneWidget);
    expect(find.text('BX-001'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each network screen is overflow-free at phone width', (
    tester,
  ) async {
    for (final screen in const [
      AreasScreen(),
      PopScreen(),
      OltScreen(),
      SplittersScreen(),
      BoxesScreen(),
    ]) {
      await pump(tester, screen, const Size(390, 844));
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
