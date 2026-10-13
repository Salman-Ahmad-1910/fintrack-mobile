import 'session.dart';

/// Port of the web client's `PERMISSION_PAGES` + `getAllowedHrefs`
/// (`client/src/lib/permission-pages.ts`): which sidebar pages each granted
/// permission id unlocks. Kept verbatim so the mobile menu shows exactly the
/// pages the web sidebar shows for the same user.
///
/// This only shapes navigation — the Go backend's RBAC / page guards remain
/// the real authorisation boundary.
const Map<String, List<String>> kPermissionPages = {
  '13309': ['/network/areas'],
  '13310': ['/network/areas'],
  '13311': ['/network/areas'],
  '13312': ['/network/areas'],
  '13313': ['/crm/packages'],
  '13314': ['/network/boxes'],
  '13315': ['/crm/subscriber-detail'],
  '13316': ['/subscribers/inquiries'],
  '13351': ['/crm/subscriber-detail'],
  '13318': ['/franchise/my-dealers'],
  '15385': ['/franchise/my-dealers/dashboard'],
  '13317': ['/recovery-officers-management/officers'],
  '13319': ['/recovery-officers-management/areas'],
  '13305': ['/transaction/allocated-collections'],
  '13324': ['/transaction/transaction-type'],
  '14079': ['/transaction/user-collections'],
  '13308': ['/transaction/user-collections'],
  '13304': ['/transaction/user-collections'],
  '13320': ['/transaction/bill-creator'],
  '13321': ['/transaction/dealers-collections'],
  '13357': ['/transaction/bad-debt-collections'],
  '15323': ['/support/complaints/subject-type'],
  '15325': ['/support/complaints/complaint-type'],
  '15326': ['/support/complaints/report'],
  '13342': ['/support/complaints/user'],
  '13343': ['/support/complaints/allocated'],
  '13347': ['/messages/draft'],
  '13348': ['/messages/sent'],
  '13359': ['/messages/whatsapp-draft'],
  '13346': ['/messages/other'],
  '13345': ['/messages/expired'],
  '13344': ['/messages/new'],
  '13322': ['/accounts/account-head'],
  '13323': ['/accounts/account-entry'],
  '15387': ['/accounts/account-entry'],
  '13341': ['/accounts/one-day-balance-sheet'],
  '15313': ['/inventory/purchases'],
  '15312': ['/inventory/products'],
  '15309': ['/inventory/brands'],
  '15311': ['/inventory/unit-types'],
  '15310': ['/inventory/vendors'],
  '15321': ['/inventory/product-types'],
  '15314': ['/inventory/statuses'],
  '15315': ['/sales'],
  '15336': ['/sales/customers', '/crm/customers'],
  '15337': ['/sales/installment-plans'],
  '15338': ['/inventory/pos'],
  '15391': ['/fiber-jointing'],
  '15317': ['/hr/advances'],
  '15318': ['/hr/salary'],
  '15324': ['/hr/attendance-subscriber'],
  '15322': ['/hr/attendance-day'],
  '15316': ['/hr/staff'],
  '15386': ['/admin/logs'],
  '13307': ['/subscriber-reports/allocated-defaulters'],
  '13325': ['/subscriber-reports/month-defaulters'],
  '13326': ['/subscriber-reports/collections'],
  '13328': ['/subscriber-reports/package-wise'],
  '13329': ['/subscriber-reports/promise-dates'],
  '13330': ['/subscriber-reports/collections'],
  '13355': ['/subscriber-reports/monthly-collections'],
  '13349': ['/subscriber-reports/expiry-defaulters'],
  '13356': ['/subscriber-reports/collections'],
  '13354': ['/subscriber-reports/monthly-collections'],
  '13358': ['/subscriber-reports/collections'],
  '13306': ['/subscriber-reports/collections'],
  '13353': ['/subscriber-reports/month-defaulters'],
  '13327': ['/subscriber-reports/deactivated-users'],
  '15327': ['/subscriber-reports/creator-summary'],
  '15329': ['/subscriber-reports/new-subscribers'],
  '15330': ['/subscriber-reports/subscribers-defaulters'],
  '15331': ['/subscriber-reports/allocated-collections'],
  '15332': ['/subscriber-reports/monthwise-collection-monthly'],
  '13331': ['/dealer/reports/collections'],
  '13333': ['/dealer/reports/new-dealers'],
  '13350': ['/dealer/reports/invoices'],
  '13332': ['/dealer/reports/defaulters'],
  '13336': ['/accounts/account-reports'],
  '15319': ['/reports/abstract-stock'],
  '15320': ['/reports/abstract-sale'],
  '13338': ['/admin/roles'],
  '13337': ['/admin/settings'],
  '15384': ['/dashboard'],
  '15365': ['/network/pop'],
  '15366': ['/network/olt'],
  '15367': ['/network/splitters'],
  '15368': ['/subscribers/corporate'],
  '15370': ['/crm/guarantors'],
  '15371': ['/sales/replaced'],
  '15372': ['/inventory/vendor-invoices'],
  '15373': ['/inventory/stock'],
  '15376': ['/admin/company-profile'],
  '15378': ['/drivers'],
  '15379': ['/applications'],
  '15380': ['/collection/pending-subscribers'],
  '15381': ['/collection/advance-subscribers'],
  '15382': ['/subscriber-reports/not-generated-collections'],
  '15383': ['/subscriber-reports/unpaid-collections'],
};

/// Pages that are never filtered out (`ALWAYS_ALLOWED`).
const List<String> kAlwaysAllowedPages = ['/dashboard'];

/// Roles that bypass page filtering in the web sidebar
/// (`isAdminRole` in `sidebar-nav.tsx`).
const List<String> kNavAdminRoles = ['admin', 'owner', 'manager'];

/// `getAllowedHrefs` — null means "no page filtering" (admin roles, or a user
/// whose permissions have not been configured yet), exactly like the web.
Set<String>? allowedPageHrefs() {
  final role = Session.role ?? '';
  if (kNavAdminRoles.contains(role)) return null;
  if (!Session.permissionsConfigured) return null;
  final hrefs = <String>{...kAlwaysAllowedPages};
  for (final id in Session.permissions) {
    final pages = kPermissionPages[id];
    if (pages != null) hrefs.addAll(pages);
  }
  return hrefs;
}
