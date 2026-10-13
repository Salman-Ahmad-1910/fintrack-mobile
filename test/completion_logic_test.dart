import 'dart:async';
import 'dart:io';

import 'package:fintrack/core/api_client.dart';
import 'package:fintrack/core/page_permissions.dart';
import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/shared/crud_kit.dart';
import 'package:fintrack/features/shell/nav_items.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the logic added while completing the app: page-permission menu
/// filtering (port of `getAllowedHrefs` / `filterNavItems`), client paging
/// and transport error messages.
void main() {
  tearDown(() {
    Session.role = null;
    Session.permissions = [];
    Session.permissionsConfigured = false;
  });

  group('allowedPageHrefs', () {
    test('admin roles are never filtered', () {
      Session.role = 'manager';
      Session.permissionsConfigured = true;
      Session.permissions = [];
      expect(allowedPageHrefs(), isNull);
    });

    test('unconfigured users are not filtered', () {
      Session.role = 'staff';
      Session.permissionsConfigured = false;
      expect(allowedPageHrefs(), isNull);
    });

    test('configured staff only get granted pages plus dashboard', () {
      Session.role = 'staff';
      Session.permissionsConfigured = true;
      Session.permissions = ['13342', '15336'];
      final hrefs = allowedPageHrefs()!;
      expect(
        hrefs,
        containsAll(<String>[
          '/dashboard',
          '/support/complaints/user',
          '/sales/customers',
          '/crm/customers',
        ]),
      );
      expect(hrefs.contains('/hr/staff'), isFalse);
    });
  });

  group('navItemVisible / sectionAllowed', () {
    test('page grant hides ungranted pages for configured staff', () {
      Session.role = 'staff';
      Session.permissionsConfigured = true;
      Session.permissions = ['13342'];
      expect(sectionAllowed('/support/complaints/user', 'staff'), isTrue);
      expect(sectionAllowed('/hr/staff', 'staff'), isFalse);
      expect(sectionAllowed('/dashboard', 'staff'), isTrue);
    });

    test('unknown sections are never allowed', () {
      Session.role = 'admin';
      expect(sectionAllowed('/does-not-exist', 'admin'), isFalse);
    });

    test('admin sees everything in the menu', () {
      Session.role = 'admin';
      for (final group in kNavGroups) {
        for (final item in group.items) {
          expect(navItemVisible(item, 'admin'), isTrue, reason: item.id);
        }
      }
    });
  });

  group('kitPage', () {
    final rows = List<int>.generate(23, (i) => i);
    test('slices pages', () {
      expect(kitPage(rows, 1, 10), List<int>.generate(10, (i) => i));
      expect(kitPage(rows, 3, 10), [20, 21, 22]);
    });
    test('out of range falls back to first page', () {
      expect(kitPage(rows, 9, 10).first, 0);
    });
  });

  group('transportErrorMessage', () {
    test('certificate failures are explained', () {
      final msg = ApiClient.transportErrorMessage(
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
      );
      expect(msg.toLowerCase(), contains('certificate'));
    });
    test('timeouts are explained', () {
      final msg = ApiClient.transportErrorMessage(TimeoutException('x'));
      expect(msg, contains('did not respond'));
    });
    test('socket errors mention the connection', () {
      final msg = ApiClient.transportErrorMessage(
        const SocketException('Failed host lookup'),
      );
      expect(msg, contains('internet connection'));
    });
  });
}
