import 'dart:convert';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/api_config.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/messages/draft_messages_screen.dart';
import 'package:fintrack/features/messages/expired_messages_screen.dart';
import 'package:fintrack/features/messages/new_messages_screen.dart';
import 'package:fintrack/features/messages/other_messages_screen.dart';
import 'package:fintrack/features/messages/sent_messages_screen.dart';
import 'package:fintrack/features/messages/whatsapp_draft_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke coverage for the six Messages screens: each header, a representative
/// row and the phone-width layout must render without throwing. Data is served
/// through a fake HTTP layer because every screen fetches in initState.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyId = 'company-1';
  final now = DateTime.now().toIso8601String();

  final templates = [
    {
      'id': 't1',
      'title': 'COLLECTION',
      'message': 'Dear {name}, your balance is {balance}.',
      'parameters': 'name, balance',
      'companyId': companyId,
    },
  ];

  final messages = [
    {
      'id': 'm1',
      'status': 'sent',
      'name': 'Ahmed Khan',
      'entityId': 'c1',
      'internetId': 'IN-001',
      'mobileNo': '03001234567',
      'messageType': 'Internet Card',
      'messageText': 'Your internet card is active.',
      'sendTo': 'Subscriber',
      'sentBy': 'Admin',
      'sendedAt': now,
      'createdAt': now,
      'companyId': companyId,
    },
    {
      'id': 'm2',
      'status': 'draft',
      'name': 'Bilal',
      'entityId': 'c1',
      'internetId': 'IN-002',
      'mobileNo': '03007654321',
      'messageType': 'Promotion',
      'messageText': 'Special discount available.',
      'sendTo': 'Subscriber',
      'createdAt': now,
      'companyId': companyId,
    },
    {
      'id': 'm3',
      'status': 'whatsapp_draft',
      'name': 'Sana',
      'entityId': 'c1',
      'internetId': 'IN-003',
      'mobileNo': '03009998887',
      'messageType': 'New User',
      'messageText': 'Welcome aboard!',
      'sendTo': 'Subscriber',
      'createdAt': now,
      'companyId': companyId,
    },
    {
      'id': 'm4',
      'status': 'sent',
      'name': 'Sara',
      'entityId': 'c1',
      'internetId': 'IN-004',
      'mobileNo': '03005556677',
      'messageType': 'Defaulter',
      'messageText': 'Defaulter: please clear your dues.',
      'sendTo': 'Subscriber',
      'sentBy': 'Admin',
      'sendedAt': now,
      'createdAt': now,
      'companyId': companyId,
    },
  ];

  final connections = [
    {
      'id': 'c1',
      'name': 'Ahmed Khan',
      'internetId': 'IN-001',
      'cell': '03001234567',
      'address': 'Street 1, DHA',
      'status': 'active',
      'connectionType': 'Fiber',
      'boxNumber': 'BX-001',
      'packageInternet': '10 Mbps',
      'packageCable': 'Basic',
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

  final companies = [
    {'id': companyId, 'name': 'SkyNet', 'role': 'admin'},
  ];

  final dealers = [
    {
      'id': 'd1',
      'name': 'Dealer One',
      'phone': '03001112223',
      'walletBalance': 5000,
    },
  ];
  final recovery = [
    {
      'id': 'r1',
      'name': 'Officer One',
      'phone': '03001112224',
      'target': 10000,
    },
  ];
  final staff = [
    {'id': 's1', 'name': 'Staff One', 'phone': '03001112225'},
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
        if (path == '/api/v1/messages') payload = messages;
        if (path == '/api/v1/messages/templates') payload = templates;
        if (path == '/api/v1/admin/connections') payload = connections;
        if (path == '/api/v1/admin/recovery-officers') payload = recovery;
        if (path == '/api/v1/network/areas') payload = areas;
        if (path == '/api/v1/dealers') payload = dealers;
        if (path == '/api/v1/hr/staff') payload = staff;
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

  testWidgets('new messages screen renders header and template', (
    tester,
  ) async {
    await pump(tester, const NewMessagesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('New Messages'), findsWidgets);
    expect(find.text('COLLECTION'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sent messages screen renders header and row', (tester) async {
    await pump(tester, const SentMessagesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Sent Messages'), findsWidgets);
    expect(find.text('Your internet card is active.'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('draft messages screen renders header and row', (tester) async {
    await pump(tester, const DraftMessagesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Draft Messages'), findsWidgets);
    expect(find.text('Bilal'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('whatsapp draft screen renders header and row', (tester) async {
    await pump(tester, const WhatsappDraftScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('WhatsApp Draft Messages'), findsWidgets);
    expect(find.text('Sana'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('other messages screen renders header and row', (tester) async {
    await pump(tester, const OtherMessagesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Other Messages'), findsWidgets);
    expect(find.text('Ahmed Khan'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expired messages screen renders header and row', (tester) async {
    await pump(tester, const ExpiredMessagesScreen(), const Size(1200, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Expiry Messages'), findsWidgets);
    expect(find.text('Sara'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each messages screen is overflow-free at phone width', (
    tester,
  ) async {
    for (final screen in const [
      NewMessagesScreen(),
      SentMessagesScreen(),
      DraftMessagesScreen(),
      WhatsappDraftScreen(),
      OtherMessagesScreen(),
      ExpiredMessagesScreen(),
    ]) {
      await pump(tester, screen, const Size(390, 844));
      expect(tester.takeException(), isNull, reason: '$screen overflowed');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
