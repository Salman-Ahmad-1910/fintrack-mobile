import 'package:flutter/material.dart';

import '../../core/page_permissions.dart';

/// One sidebar destination. [roles] mirrors `allowedRoles` in the web client's
/// `sidebar-nav.tsx` (items with no roles are visible to everyone; admin roles
/// always pass).
class NavItem {
  const NavItem({
    required this.id,
    required this.title,
    required this.icon,
    this.roles,
    this.children,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<String>? roles;
  final List<NavItem>? children;

  bool get hasChildren => children != null && children!.isNotEmpty;
}

class NavGroup {
  const NavGroup({required this.title, required this.items});

  final String title;
  final List<NavItem> items;
}

const List<String> _am = ['admin', 'manager'];
const List<String> _staff = [
  'admin',
  'manager',
  'dealer',
  'sub_dealer',
  'staff',
];
const List<String> _all = [
  'admin',
  'manager',
  'dealer',
  'sub_dealer',
  'staff',
  'recovery_officer',
];

const List<NavGroup> kNavGroups = [
  NavGroup(
    title: 'Dashboard',
    items: [
      NavItem(
        id: '/dashboard',
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
      ),
    ],
  ),
  NavGroup(
    title: 'Network',
    items: [
      NavItem(
        id: '/network/areas',
        title: 'Areas',
        icon: Icons.lan_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/network/pop',
        title: 'POPs',
        icon: Icons.cell_tower,
        roles: _am,
      ),
      NavItem(
        id: '/network/olt',
        title: 'OLTs',
        icon: Icons.account_tree_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/network/splitters',
        title: 'Splitters',
        icon: Icons.call_split,
        roles: _am,
      ),
      NavItem(
        id: '/network/boxes',
        title: 'Box / Media',
        icon: Icons.inventory_2_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Messages',
    items: [
      NavItem(
        id: '/messages/new',
        title: 'New Messages',
        icon: Icons.inbox_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/messages/other',
        title: 'Other Messages',
        icon: Icons.mark_email_unread_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/messages/draft',
        title: 'Draft Messages',
        icon: Icons.edit_note_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/messages/sent',
        title: 'Sent Messages',
        icon: Icons.send_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/messages/expired',
        title: 'Expiry Messages',
        icon: Icons.schedule,
        roles: _all,
      ),
      NavItem(
        id: '/messages/whatsapp-draft',
        title: 'WhatsApp Drafts',
        icon: Icons.chat_bubble_outline,
        roles: _all,
      ),
    ],
  ),
  NavGroup(
    title: 'Subscribers Management',
    items: [
      NavItem(
        id: '/crm/subscriber-detail',
        title: 'Subscriber Detail',
        icon: Icons.people_outline,
        roles: _all,
      ),
      NavItem(
        id: '/subscribers/inquiries',
        title: 'New Inquiries',
        icon: Icons.person_add_outlined,
        roles: _staff,
      ),
      NavItem(
        id: '/subscribers/corporate',
        title: 'Corporate Clients',
        icon: Icons.business_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/crm/customers',
        title: 'Customers',
        icon: Icons.person_outline,
        roles: _all,
      ),
      NavItem(
        id: '/crm/guarantors',
        title: 'Guarantors',
        icon: Icons.how_to_reg_outlined,
        roles: _staff,
      ),
      NavItem(
        id: '/crm/packages',
        title: 'Packages',
        icon: Icons.receipt_long_outlined,
        roles: _staff,
      ),
    ],
  ),
  NavGroup(
    title: 'Sales',
    items: [
      NavItem(
        id: '/sales',
        title: 'Sales',
        icon: Icons.shopping_cart_outlined,
        roles: _staff,
      ),
      NavItem(
        id: '/sales/replaced',
        title: 'Replaced Products',
        icon: Icons.sync_outlined,
        roles: _staff,
      ),
      NavItem(
        id: '/sales/customers',
        title: 'Customers',
        icon: Icons.person_outline,
        roles: _staff,
      ),
      NavItem(
        id: '/sales/installment-plans',
        title: 'Installment Plans',
        icon: Icons.description_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/pos',
        title: 'Point of Sale',
        icon: Icons.point_of_sale_outlined,
        roles: ['admin', 'manager', 'dealer'],
      ),
    ],
  ),
  NavGroup(
    title: 'Transaction',
    items: [
      NavItem(
        id: '/transaction/user-collections',
        title: 'Subscriber Collections',
        icon: Icons.people_outline,
        roles: _all,
      ),
      NavItem(
        id: '/transaction/dealers-collections',
        title: 'Dealers Collections',
        icon: Icons.handshake_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/transaction/allocated-collections',
        title: 'Allocated Collections',
        icon: Icons.assignment_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/transaction/transaction-type',
        title: 'Transaction Type',
        icon: Icons.description_outlined,
        roles: _staff,
      ),
      NavItem(
        id: '/transaction/bad-debt-collections',
        title: 'Bad Debt Collections',
        icon: Icons.warning_amber_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/transaction/bill-creator',
        title: 'Bill Creator',
        icon: Icons.request_quote_outlined,
        roles: ['admin', 'manager', 'dealer'],
      ),
    ],
  ),
  NavGroup(
    title: 'Dealer Management',
    items: [
      NavItem(
        id: '/franchise/my-dealers',
        title: 'My Dealers',
        icon: Icons.people_outline,
        roles: _am,
      ),
      NavItem(
        id: '/franchise/my-dealers/dashboard',
        title: 'Dealer Dashboard',
        icon: Icons.dashboard_outlined,
        roles: ['admin', 'manager', 'dealer', 'sub_dealer'],
      ),
      NavItem(
        id: '/dealer/reports',
        title: 'Reports',
        icon: Icons.folder_outlined,
        roles: ['admin', 'manager', 'dealer'],
        children: [
          NavItem(
            id: '/dealer/reports/collections',
            title: 'Collections',
            icon: Icons.account_balance_wallet_outlined,
            roles: ['admin', 'manager', 'dealer'],
          ),
          NavItem(
            id: '/dealer/reports/defaulters',
            title: 'Defaulters',
            icon: Icons.warning_amber_outlined,
            roles: ['admin', 'manager', 'dealer'],
          ),
          NavItem(
            id: '/dealer/reports/new-dealers',
            title: 'New Dealers',
            icon: Icons.person_add_outlined,
            roles: ['admin', 'manager', 'dealer'],
          ),
          NavItem(
            id: '/dealer/reports/invoices',
            title: 'Invoices',
            icon: Icons.description_outlined,
            roles: ['admin', 'manager', 'dealer'],
          ),
        ],
      ),
    ],
  ),
  NavGroup(
    title: 'Inventory',
    items: [
      NavItem(
        id: '/inventory/brands',
        title: 'Brand',
        icon: Icons.sell_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/unit-types',
        title: 'Unit Type',
        icon: Icons.straighten_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/product-types',
        title: 'Product Type',
        icon: Icons.category_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/products',
        title: 'Product',
        icon: Icons.inventory_2_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/vendors',
        title: 'Vendor',
        icon: Icons.apartment_outlined,
        roles: ['admin', 'manager', 'dealer', 'sub_dealer', 'staff'],
      ),
      NavItem(
        id: '/inventory/vendor-invoices',
        title: 'Vendor Invoice',
        icon: Icons.description_outlined,
        roles: ['admin', 'manager', 'dealer', 'sub_dealer', 'staff'],
      ),
      NavItem(
        id: '/inventory/purchases',
        title: 'Purchase',
        icon: Icons.swap_horiz,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/statuses',
        title: 'Inventory Status',
        icon: Icons.monitor_heart_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/inventory/stock',
        title: 'Stock',
        icon: Icons.warehouse_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Accounts',
    items: [
      NavItem(
        id: '/accounts/account-head',
        title: 'Account Head',
        icon: Icons.layers_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/accounts/account-entry',
        title: 'Account Entry',
        icon: Icons.assignment_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/accounts/account-reports',
        title: 'Account Reports',
        icon: Icons.description_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/accounts/one-day-balance-sheet',
        title: 'One Day Balance Sheet',
        icon: Icons.bar_chart,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Stock Report',
    items: [
      NavItem(
        id: '/reports/abstract-stock',
        title: 'Abstract Stock',
        icon: Icons.inventory_2_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Sale Report',
    items: [
      NavItem(
        id: '/reports/abstract-sale',
        title: 'Abstract Sale',
        icon: Icons.receipt_long_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Complaints',
    items: [
      NavItem(
        id: '/support/complaints/complaint-type',
        title: 'Complaint Type',
        icon: Icons.label_outline,
        roles: _all,
      ),
      NavItem(
        id: '/support/complaints/subject-type',
        title: 'Subject Type',
        icon: Icons.menu_book_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/support/complaints/user',
        title: 'Subscriber Complaint',
        icon: Icons.person_add_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/support/complaints/allocated',
        title: 'Allocated Complaint',
        icon: Icons.assignment_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/support/complaints/report',
        title: 'Complaint Report',
        icon: Icons.description_outlined,
        roles: _all,
      ),
    ],
  ),
  // "Service Desk" (Alerts / Support Tickets) was removed: the web client
  // has no pages for /support/alerts or /admin/support-tickets and no sidebar
  // entries for them, so they only ever showed a placeholder here.
  NavGroup(
    title: 'Recovery Officers',
    items: [
      NavItem(
        id: '/recovery-officers-management/areas',
        title: 'Areas',
        icon: Icons.map_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/recovery-officers-management/officers',
        title: 'Officers',
        icon: Icons.how_to_reg_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Human Resources',
    items: [
      NavItem(
        id: '/hr/staff',
        title: 'Staff',
        icon: Icons.work_outline,
        roles: _am,
      ),
      NavItem(
        id: '/hr/salary',
        title: 'Staff Salary',
        icon: Icons.account_balance_wallet_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/hr/attendance-day',
        title: 'Staff Attendance',
        icon: Icons.calendar_month_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/hr/attendance-subscriber',
        title: 'Attendance Report',
        icon: Icons.fingerprint,
        roles: _am,
      ),
      NavItem(
        id: '/hr/advances',
        title: 'Advances & Loans',
        icon: Icons.volunteer_activism_outlined,
        roles: _am,
      ),
    ],
  ),
  NavGroup(
    title: 'Administration',
    items: [
      NavItem(
        id: '/admin/company-profile',
        title: 'My Company Profile',
        icon: Icons.business_outlined,
        roles: _am,
      ),
      NavItem(
        id: '/admin/roles',
        title: 'Roles & Permissions',
        icon: Icons.verified_user_outlined,
        roles: ['admin'],
      ),
      NavItem(
        id: '/admin/settings',
        title: 'System Config',
        icon: Icons.settings_outlined,
        roles: ['admin'],
      ),
    ],
  ),
  NavGroup(
    title: 'System Log',
    items: [
      NavItem(
        id: '/admin/logs',
        title: 'System Log',
        icon: Icons.history,
        roles: ['admin'],
      ),
    ],
  ),
  NavGroup(
    title: 'Subscriber Reports',
    items: [
      NavItem(
        id: '/subscriber-reports/collections',
        title: 'Subscriber Report',
        icon: Icons.account_balance_wallet_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/collection/pending-subscribers',
        title: 'Pending Subscribers',
        icon: Icons.schedule,
        roles: _all,
      ),
      NavItem(
        id: '/collection/advance-subscribers',
        title: 'Advance Subscribers',
        icon: Icons.trending_up,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/deactivated-users',
        title: 'Deactivate Users List',
        icon: Icons.person_search_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/package-wise',
        title: 'Package Wise List',
        icon: Icons.inventory_2_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/promise-dates',
        title: 'Promise Date Reports',
        icon: Icons.event_note_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/allocated-defaulters',
        title: 'Allocated Defaulters',
        icon: Icons.warning_amber_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/expiry-defaulters',
        title: 'Expiry Wise Defaulters',
        icon: Icons.bar_chart,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/month-defaulters',
        title: 'Month Wise Defaulters',
        icon: Icons.description_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/monthly-collections',
        title: 'Monthly Collections',
        icon: Icons.payments_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/allocated-collections',
        title: 'Allocated Collections',
        icon: Icons.handshake_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/monthwise-collection-monthly',
        title: 'Month Wise Collection Monthly',
        icon: Icons.bar_chart,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/not-generated-collections',
        title: 'Not Generated Collections',
        icon: Icons.edit_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/unpaid-collections',
        title: 'Unpaid Collections',
        icon: Icons.account_balance_wallet_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/subscribers-defaulters',
        title: 'Subscribers Defaulters',
        icon: Icons.warning_amber_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/new-subscribers',
        title: 'New Subscribers List',
        icon: Icons.person_add_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/subscriber-reports/creator-summary',
        title: 'Subscribers Creator Summary',
        icon: Icons.person_add_outlined,
        roles: _all,
      ),
    ],
  ),
  NavGroup(
    title: 'Reports',
    items: [
      NavItem(
        id: '/admin/reports',
        title: 'Reports',
        icon: Icons.area_chart,
        roles: _all,
      ),
    ],
  ),
  NavGroup(
    title: 'Downloads',
    items: [
      NavItem(
        id: '/drivers',
        title: 'Drivers',
        icon: Icons.memory_outlined,
        roles: _all,
      ),
      NavItem(
        id: '/applications',
        title: 'Application',
        icon: Icons.apps_outlined,
        roles: _all,
      ),
    ],
  ),
];

const List<String> _adminRoles = ['admin', 'owner', 'manager'];

/// `filterNavItems` from `sidebar-nav.tsx`:
///  * `allowedRoles` gates by role, unless an admin granted this user the
///    page explicitly (per-user grant wins over role defaults);
///  * once the user's permissions are configured (non-admin roles), only the
///    pages unlocked by their granted ids are shown (`getAllowedHrefs`);
///  * a parent entry with no visible children is hidden.
bool navItemVisible(NavItem item, String? role) {
  final allowed = allowedPageHrefs();
  final roles = item.roles;
  final isAdmin = role == null || role.isEmpty || _adminRoles.contains(role);
  if (item.hasChildren) {
    // A folder has no page of its own, so a role mismatch hides it outright.
    if (!isAdmin && roles != null && !roles.contains(role)) return false;
    return item.children!.any((c) => navItemVisible(c, role));
  }
  if (!isAdmin && roles != null && !roles.contains(role)) {
    if (!(allowed != null && allowed.contains(item.id))) return false;
  }
  if (allowed != null && !allowed.contains(item.id)) return false;
  return true;
}

/// Whether [id] may be opened in the shell: the dashboard always, otherwise
/// only a known, visible navigation entry. Used to stop a hidden page from
/// being reached by any other route (header search, deep links, ...).
bool sectionAllowed(String id, String? role) {
  if (kAlwaysAllowedPages.contains(id)) return true;
  final item = findNavItem(id);
  if (item == null) return false;
  return navItemVisible(item, role);
}

/// Looks a section id up across every group (including nested children).
NavItem? findNavItem(String id) {
  for (final group in kNavGroups) {
    for (final item in group.items) {
      if (item.id == id) return item;
      for (final child in item.children ?? const <NavItem>[]) {
        if (child.id == id) return child;
      }
    }
  }
  return null;
}
