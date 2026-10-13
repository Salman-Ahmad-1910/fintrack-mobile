/// Permission catalogue shown on the Roles & Permissions page.
///
/// Transcribed 1:1 from `client/src/lib/permission-pages.ts` in the web
/// reference (`PERMISSION_DEFS`, `PERMISSION_FOLDERS`, `PAGE_PERMISSIONS`,
/// `PERMISSION_CHILD_DEFS`). These ids are what gets stored in the
/// `user_permissions` table when an admin saves rights for a user.
class PermissionDef {
  const PermissionDef(this.id, this.name, this.module);

  final String id;
  final String name;
  final String module;
}

class PermissionFolder {
  const PermissionFolder(this.id, this.name, this.modules);

  final String id;
  final String name;
  final List<String> modules;
}

/// A page-level permission can own finer-grained children that control the
/// individual features and buttons on that page. Child ids are derived from the
/// parent id (`"13309:create"`) so they never collide with the legacy numeric
/// ids.
class ChildDef {
  const ChildDef(
    this.id,
    this.name,
    this.module,
    this.parentId,
    this.key,
    this.label,
  );

  final String id;
  final String name;
  final String module;
  final String parentId;
  final String key;
  final String label;
}

const String kAllFoldersId = 'all';

const List<PermissionDef> kPermissionDefs = [
  PermissionDef('13309', 'Area', 'Network'),
  PermissionDef('15365', 'POPs', 'Network'),
  PermissionDef('15366', 'OLTs', 'Network'),
  PermissionDef('15367', 'Splitters', 'Network'),
  PermissionDef('13314', 'Box/Media', 'Network'),
  PermissionDef('13315', 'Subscribers Details', 'Subscriber Management'),
  PermissionDef('13316', 'New Inquiries', 'Subscriber Management'),
  PermissionDef('15368', 'Corporate Clients', 'Subscriber Management'),
  PermissionDef('13313', 'Package', 'Subscriber Management'),
  PermissionDef('13351', 'Subscriber Location', 'Subscriber Management'),
  PermissionDef('13318', 'My Dealers', 'Dealer Management'),
  PermissionDef('15385', 'Dealer Dashboard', 'Dealer Management'),
  PermissionDef('13331', 'Collections', 'Dealer Management'),
  PermissionDef('13332', 'Defaulters', 'Dealer Management'),
  PermissionDef('13333', 'New Dealers', 'Dealer Management'),
  PermissionDef('13350', 'Invoices', 'Dealer Management'),
  PermissionDef('13317', 'Recovery Officer', 'Recovery Officer'),
  PermissionDef('13319', 'Area Assignment', 'Recovery Officer'),
  PermissionDef('13305', 'Allocated Collection', 'Transactions'),
  PermissionDef('13324', 'Transaction Type', 'Transactions'),
  PermissionDef('14079', 'New Collection', 'Transactions'),
  PermissionDef('13308', 'Reprint Slip', 'Transactions'),
  PermissionDef('13304', 'Subscribers Collections', 'Transactions'),
  PermissionDef('15388', 'Collection Search', 'Transactions'),
  PermissionDef('15389', 'Collection Summary', 'Transactions'),
  PermissionDef('13320', 'Bills Creator', 'Transactions'),
  PermissionDef('13321', 'Dealers Collections', 'Transactions'),
  PermissionDef('13357', 'Baddebt Collection', 'Transactions'),
  PermissionDef('15323', 'Subject Type', 'Complain'),
  PermissionDef('15325', 'Complain Type', 'Complain'),
  PermissionDef('15326', 'Complain Report', 'Complain'),
  PermissionDef('13342', 'Subscribers Complain', 'Complain'),
  PermissionDef('13343', 'Allocated Complains', 'Complain'),
  PermissionDef('13347', 'Draft Messages', 'Messages'),
  PermissionDef('13348', 'Sent Messages', 'Messages'),
  PermissionDef('13359', 'Whatsapp Draft Message', 'Messages'),
  PermissionDef('13346', 'Other Messages', 'Messages'),
  PermissionDef('13345', 'Expiry Messages', 'Messages'),
  PermissionDef('13344', 'New Messages', 'Messages'),
  PermissionDef('13322', 'Account Heads', 'Accounts'),
  PermissionDef('13323', 'Account Entry', 'Accounts'),
  PermissionDef('15387', 'Account Entry Filters & Table', 'Accounts'),
  PermissionDef('13341', 'One Day Accounts', 'Accounts'),
  PermissionDef('15309', 'Brand', 'Inventory'),
  PermissionDef('15311', 'Unit Type', 'Inventory'),
  PermissionDef('15321', 'Product Type', 'Inventory'),
  PermissionDef('15312', 'Products', 'Inventory'),
  PermissionDef('15310', 'Vendor', 'Inventory'),
  PermissionDef('15372', 'Vendor Invoice', 'Inventory'),
  PermissionDef('15313', 'Purchase', 'Inventory'),
  PermissionDef('15314', 'Inventory Status', 'Inventory'),
  PermissionDef('15373', 'Stock', 'Inventory'),
  PermissionDef('15315', 'Sales', 'Sales'),
  PermissionDef('15336', 'Customers', 'Sales'),
  PermissionDef('15337', 'Installment Plans', 'Sales'),
  PermissionDef('15338', 'Point of Sale', 'Sales'),
  PermissionDef('15370', 'Guarantors', 'Sales'),
  PermissionDef('15316', 'Staff', 'Human Resources'),
  PermissionDef('15318', 'Staff Salary', 'Human Resources'),
  PermissionDef('15322', 'Staff Attendance', 'Human Resources'),
  PermissionDef('15324', 'Attendance Report', 'Human Resources'),
  PermissionDef('15317', 'Advance and Loans', 'Human Resources'),
  PermissionDef('15386', 'System Log', 'System Logs'),
  PermissionDef('13307', 'Allocated Defualters', 'Subscribers Reports'),
  PermissionDef('13325', 'Subscribers Defaulter', 'Subscribers Reports'),
  PermissionDef('13326', 'New Subscribers List', 'Subscribers Reports'),
  PermissionDef('13328', 'Package Wise List', 'Subscribers Reports'),
  PermissionDef('13329', 'Promise Date Report', 'Subscribers Reports'),
  PermissionDef('13330', 'Allocated Collections', 'Subscribers Reports'),
  PermissionDef('13355', 'Month Wise Collection', 'Subscribers Reports'),
  PermissionDef('13349', 'Expiry Wise Defaulter', 'Subscribers Reports'),
  PermissionDef('13356', 'Collection Not Generated', 'Subscribers Reports'),
  PermissionDef(
    '13354',
    'Monthly Collection Month Wise',
    'Subscribers Reports',
  ),
  PermissionDef('13358', 'Unpaid Collection', 'Subscribers Reports'),
  PermissionDef('13306', 'Subscriber Collections', 'Subscribers Reports'),
  PermissionDef('13353', 'Month Wise Defualter', 'Subscribers Reports'),
  PermissionDef('13327', 'Deactivate Subscriber List', 'Subscribers Reports'),
  PermissionDef('15327', 'Subscribers Creator Summary', 'Subscribers Reports'),
  PermissionDef('15329', 'New Subscribers List', 'Subscribers Reports'),
  PermissionDef('15330', 'Subscribers Defaulters', 'Subscribers Reports'),
  PermissionDef('15331', 'Allocated Collections', 'Subscribers Reports'),
  PermissionDef(
    '15332',
    'Month Wise Collection Monthly',
    'Subscribers Reports',
  ),
  PermissionDef('13336', 'Accounts Report', 'Accounts'),
  PermissionDef('15319', 'Abstract Stock', 'Stock Reports'),
  PermissionDef('15320', 'Abstract Sales', 'Sales Reports'),
  PermissionDef('15376', 'My Company Profile', 'Administration'),
  PermissionDef('13338', 'Roles & Permissions', 'Administration'),
  PermissionDef('13337', 'System Config', 'Administration'),
  PermissionDef('15334', 'Dashboard Summary', 'Dashboard'),
  PermissionDef('15390', 'Charts & Activity', 'Dashboard'),
  PermissionDef('15384', 'Dashboard', 'Dashboard'),
  PermissionDef('15362', 'Add / Create', 'CRUD'),
  PermissionDef('15363', 'Update / Edit', 'CRUD'),
  PermissionDef('15364', 'Delete', 'CRUD'),
  PermissionDef('15371', 'Replaced Products', 'Sales'),
  PermissionDef('15378', 'Drivers', 'Downloads'),
  PermissionDef('15379', 'Application', 'Downloads'),
  PermissionDef('15380', 'Pending Subscribers', 'Subscribers Reports'),
  PermissionDef('15381', 'Advance Subscribers', 'Subscribers Reports'),
  PermissionDef('15382', 'Not Generated Collections', 'Subscribers Reports'),
  PermissionDef('15383', 'Unpaid Collections', 'Subscribers Reports'),
];

/// Sidebar folders, in the exact order they appear in the navigation, mapped to
/// the permission modules they own. `modules` is empty for the "all" entry,
/// which means every module.
const List<PermissionFolder> kPermissionFolders = [
  PermissionFolder(kAllFoldersId, 'All Folders', []),
  PermissionFolder('dashboard', 'Dashboard', ['Dashboard']),
  PermissionFolder('network', 'Network', ['Network']),
  PermissionFolder('messages', 'Messages', ['Messages']),
  PermissionFolder('subscribers-management', 'Subscribers Management', [
    'Subscriber Management',
  ]),
  PermissionFolder('sales', 'Sales', ['Sales']),
  PermissionFolder('transaction', 'Transaction', ['Transactions']),
  PermissionFolder('dealer-management', 'Dealer Management', [
    'Dealer Management',
  ]),
  PermissionFolder('inventory', 'Inventory', ['Inventory']),
  PermissionFolder('accounts', 'Accounts', ['Accounts']),
  PermissionFolder('stock-report', 'Stock Report', ['Stock Reports']),
  PermissionFolder('sale-report', 'Sale Report', ['Sales Reports']),
  PermissionFolder('complaints', 'Complaints', ['Complain']),
  PermissionFolder('recovery-officers', 'Recovery Officers', [
    'Recovery Officer',
  ]),
  PermissionFolder('human-resources', 'Human Resources', ['Human Resources']),
  PermissionFolder('administration', 'Administration', ['Administration']),
  PermissionFolder('system-log', 'System Log', ['System Logs']),
  PermissionFolder('subscriber-reports', 'Subscriber Reports', [
    'Subscribers Reports',
  ]),
  PermissionFolder('downloads', 'Downloads', ['Downloads']),
  PermissionFolder('general-actions', 'General Actions', ['CRUD']),
];

class ChildKey {
  const ChildKey(this.key, this.label);

  final String key;
  final String label;
}

class PageChildren {
  const PageChildren(this.defs);

  final List<ChildKey> defs;
}

const _crud = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Update'),
  ChildKey('delete', 'Delete'),
]);
const _updateDelete = PageChildren([
  ChildKey('update', 'Update'),
  ChildKey('delete', 'Delete'),
]);
const _createDelete = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('delete', 'Delete'),
]);
const _createUpdate = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Update'),
]);
const _deleteOnly = PageChildren([ChildKey('delete', 'Delete')]);
const _createOnly = PageChildren([ChildKey('create', 'Create')]);
const _subscriberDetail = PageChildren([
  ChildKey('cards', 'Cards'),
  ChildKey('bulk-edit', 'Bulk Edit'),
  ChildKey('import-export', 'Import / Export'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
  ChildKey('status', 'Status'),
]);
const _inquiries = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _corporateClients = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Update'),
  ChildKey('delete', 'Delete'),
]);
const _package = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _recoveryOfficer = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _areaAssignment = PageChildren([
  ChildKey('officer-select', 'Select Officer'),
]);
const _salesCustomers = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _guarantors = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _installmentPlans = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _pos = PageChildren([
  ChildKey('products', 'Products'),
  ChildKey('order-detail', 'Order Detail'),
]);
const _inventoryCatalog = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _vendorInvoice = PageChildren([
  ChildKey('create', 'Buy a Product'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
  ChildKey('print', 'Print'),
  ChildKey('summary', 'Summary'),
]);
const _collectionFullCrud = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('search', 'Search'),
  ChildKey('create', 'Create'),
  ChildKey('update', 'Update'),
  ChildKey('delete', 'Delete'),
]);
const _collectionCreate = PageChildren([
  ChildKey('summary', 'Summary'),
  ChildKey('search', 'Search'),
  ChildKey('create', 'Create'),
]);
const _transactionType = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('update', 'Edit'),
  ChildKey('delete', 'Delete'),
]);
const _billCreator = PageChildren([
  ChildKey('create', 'Create'),
  ChildKey('delete', 'Delete'),
]);
const _myDealer = PageChildren([
  ChildKey('create', 'Add'),
  ChildKey('update', 'Edit'),
  ChildKey('change-status', 'Change Status'),
  ChildKey('delete', 'Delete'),
]);
const _dealerDashboard = PageChildren([
  ChildKey('dealer-select', 'Dealer Select'),
  ChildKey('summary', 'Summary'),
]);
const _reportChildren = PageChildren([
  ChildKey('filters', 'Filters'),
  ChildKey('summary', 'Summary'),
  ChildKey('export', 'Print / Excel'),
]);

/// pagePermissionId → (page name, children), from the web's `PAGE_PERMISSIONS`.
const Map<String, ({String name, PageChildren children})> _pagePermissions = {
  '13309': (name: 'Area', children: _crud),
  '15365': (name: 'POPs', children: _crud),
  '15366': (name: 'OLTs', children: _crud),
  '15367': (name: 'Splitters', children: _crud),
  '13314': (name: 'Box/Media', children: _crud),
  '13315': (name: 'Subscribers Details', children: _subscriberDetail),
  '13316': (name: 'New Inquiries', children: _inquiries),
  '15368': (name: 'Corporate Clients', children: _corporateClients),
  '13313': (name: 'Package', children: _package),
  '13317': (name: 'Recovery Officer', children: _recoveryOfficer),
  '13319': (name: 'Area Assignment', children: _areaAssignment),
  '15336': (name: 'Customers', children: _salesCustomers),
  '15370': (name: 'Guarantors', children: _guarantors),
  '15337': (name: 'Installment Plans', children: _installmentPlans),
  '15338': (name: 'Point of Sale', children: _pos),
  '15309': (name: 'Brand', children: _inventoryCatalog),
  '15310': (name: 'Vendor', children: _inventoryCatalog),
  '15311': (name: 'Unit Type', children: _inventoryCatalog),
  '15312': (name: 'Products', children: _inventoryCatalog),
  '15321': (name: 'Product Type', children: _inventoryCatalog),
  '15372': (name: 'Vendor Invoice', children: _vendorInvoice),
  '13304': (name: 'Subscribers Collections', children: _collectionFullCrud),
  '13321': (name: 'Dealers Collections', children: _collectionFullCrud),
  '13305': (name: 'Allocated Collection', children: _collectionCreate),
  '13357': (name: 'Baddebt Collection', children: _collectionCreate),
  '13324': (name: 'Transaction Type', children: _transactionType),
  '13320': (name: 'Bills Creator', children: _billCreator),
  '13318': (name: 'My Dealer', children: _myDealer),
  '15385': (name: 'Dealer Dashboard', children: _dealerDashboard),
  '13331': (name: 'Collection Report', children: _reportChildren),
  '13332': (name: 'Defaulter Report', children: _reportChildren),
  '13333': (name: 'New Dealer Report', children: _reportChildren),
  '13350': (name: 'Invoice Report', children: _reportChildren),
  '15319': (name: 'Abstract Stock', children: _reportChildren),
  '15320': (name: 'Abstract Sales', children: _reportChildren),
  '15323': (name: 'Subject Type', children: _crud),
  '15325': (name: 'Complain Type', children: _crud),
  '13342': (name: 'Subscribers Complain', children: _crud),
  '13343': (name: 'Allocated Complains', children: _updateDelete),
  '13347': (name: 'Draft Messages', children: _createDelete),
  '13359': (name: 'Whatsapp Draft Message', children: _deleteOnly),
  '13346': (name: 'Other Messages', children: _deleteOnly),
  '13345': (name: 'Expiry Messages', children: _deleteOnly),
  '13344': (name: 'New Messages', children: _crud),
  '13322': (name: 'Account Heads', children: _crud),
  '13323': (name: 'Account Entry', children: _crud),
  '13341': (name: 'One Day Accounts', children: _updateDelete),
  '15313': (name: 'Purchase', children: _crud),
  '15315': (name: 'Sales', children: _updateDelete),
  '15316': (name: 'Staff', children: _crud),
  '15318': (name: 'Staff Salary', children: _createOnly),
  '15322': (name: 'Staff Attendance', children: _createUpdate),
  '15317': (name: 'Advance and Loans', children: _crud),
  '13326': (name: 'New Subscribers List', children: _reportChildren),
  '13330': (name: 'Allocated Collections', children: _reportChildren),
  '13356': (name: 'Collection Not Generated', children: _reportChildren),
  '13358': (name: 'Unpaid Collection', children: _reportChildren),
  '13306': (name: 'Subscriber Collections', children: _reportChildren),
  '13307': (name: 'Allocated Defualters', children: _reportChildren),
  '13325': (name: 'Subscribers Defaulter', children: _reportChildren),
  '13353': (name: 'Month Wise Defualter', children: _reportChildren),
  '13328': (name: 'Package Wise List', children: _reportChildren),
  '13329': (name: 'Promise Date Report', children: _reportChildren),
  '13355': (name: 'Month Wise Collection', children: _reportChildren),
  '13354': (name: 'Monthly Collection Month Wise', children: _reportChildren),
  '13349': (name: 'Expiry Wise Defaulter', children: _reportChildren),
  '13327': (name: 'Deactivate Subscriber List', children: _reportChildren),
  '15327': (name: 'Subscribers Creator Summary', children: _reportChildren),
  '15329': (name: 'New Subscribers List', children: _reportChildren),
  '15330': (name: 'Subscribers Defaulters', children: _reportChildren),
  '15331': (name: 'Allocated Collections', children: _reportChildren),
  '15332': (name: 'Month Wise Collection Monthly', children: _reportChildren),
  '15382': (name: 'Not Generated Collections', children: _reportChildren),
  '15383': (name: 'Unpaid Collections', children: _reportChildren),
  '15380': (name: 'Pending Subscribers', children: _reportChildren),
  '15381': (name: 'Advance Subscribers', children: _reportChildren),
};

String childPermissionId(String parentId, String key) => '$parentId:$key';

String? _moduleOf(String parentId) {
  for (final p in kPermissionDefs) {
    if (p.id == parentId) return p.module;
  }
  return null;
}

/// Per-page CRUD children, derived from [_pagePermissions] exactly like the
/// web's `PERMISSION_CHILD_DEFS`.
List<ChildDef> get kPermissionChildDefs {
  final out = <ChildDef>[];
  _pagePermissions.forEach((parentId, entry) {
    final module = _moduleOf(parentId) ?? 'General';
    for (final child in entry.children.defs) {
      out.add(
        ChildDef(
          childPermissionId(parentId, child.key),
          '${entry.name} - ${child.label}',
          module,
          parentId,
          child.key,
          child.label,
        ),
      );
    }
  });
  return out;
}

/// Children grouped by their parent page permission id.
Map<String, List<ChildDef>> childrenByParent() {
  final map = <String, List<ChildDef>>{};
  for (final child in kPermissionChildDefs) {
    map.putIfAbsent(child.parentId, () => []).add(child);
  }
  return map;
}

/// Every permission id that can be stored for a user: the top-level
/// definitions plus their per-page children.
List<String> get allPermissionIds => [
  for (final p in kPermissionDefs) p.id,
  for (final p in kPermissionChildDefs) p.id,
];

/// Module names in first-seen order (web: `[...new Set(PERMISSIONS.map(p =>
/// p.module))]`).
List<String> get kPermissionModules =>
    <String>{for (final p in kPermissionDefs) p.module}.toList();
