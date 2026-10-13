import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../features/admin/company_profile_screen.dart';
import '../../features/admin/roles_screen.dart';
import '../../features/admin/settings_screen.dart';
import '../../features/accounts/account_entry_screen.dart';
import '../../features/accounts/account_head_screen.dart';
import '../../features/accounts/account_reports_screen.dart';
import '../../features/accounts/one_day_balance_sheet_screen.dart';
import '../../features/admin/system_log_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dealers/my_dealers_screen.dart';
import '../../features/hr/hr_screens.dart';
import '../../features/reports/subscriber_reports_screens.dart';
import '../../features/support/complaints_screens.dart';
import '../../features/network/areas_screen.dart';
import '../../features/network/boxes_screen.dart';
import '../../features/network/olt_screen.dart';
import '../../features/network/pop_screen.dart';
import '../../features/network/splitters_screen.dart';
import '../../features/crm/corporate_screen.dart';
import '../../features/crm/customers_screen.dart';
import '../../features/crm/guarantors_screen.dart';
import '../../features/crm/inquiries_screen.dart';
import '../../features/crm/packages_screen.dart';
import '../../features/crm/subscriber_detail_screen.dart';
import '../../features/inventory/brands_screen.dart';
import '../../features/inventory/inventory_status_screen.dart';
import '../../features/inventory/product_types_screen.dart';
import '../../features/inventory/products_screen.dart';
import '../../features/inventory/purchases_screen.dart';
import '../../features/inventory/stock_screen.dart';
import '../../features/inventory/unit_types_screen.dart';
import '../../features/inventory/vendor_invoices_screen.dart';
import '../../features/inventory/vendors_screen.dart';
import '../../features/recovery/area_assignment_screen.dart';
import '../../features/recovery/recovery_officers_screen.dart';
import '../../features/messages/draft_messages_screen.dart';
import '../../features/messages/expired_messages_screen.dart';
import '../../features/messages/new_messages_screen.dart';
import '../../features/messages/other_messages_screen.dart';
import '../../features/messages/sent_messages_screen.dart';
import '../../features/messages/whatsapp_draft_screen.dart';
import '../../features/sales/installment_plans_screen.dart';
import '../../features/sales/point_of_sale_screen.dart';
import '../../features/sales/replaced_products_screen.dart';
import '../../features/sales/sales_customers_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/transaction/allocated_collections_screen.dart';
import '../../features/transaction/bad_debt_collections_screen.dart';
import '../../features/transaction/bill_creator_screen.dart';
import '../../features/transaction/dealers_collections_screen.dart';
import '../../features/transaction/transaction_type_screen.dart';
import '../../features/transaction/user_collections_screen.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'app_header.dart';
import 'coming_soon.dart';
import 'nav_items.dart';
import 'sidebar.dart';
import 'sync_status_bar.dart';

/// App chrome shared by every signed-in screen: pinned sidebar on wide
/// layouts (drawer on narrow ones) plus the top bar — the Flutter counterpart
/// of the web client's `AppShell`.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialSection = '/dashboard'});

  final String initialSection;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _section = widget.initialSection;

  /// Width at which the sidebar switches from drawer to pinned column
  /// (roughly the web client's `md` breakpoint).
  static const double _breakpoint = 1000;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  /// The web client re-reads `/auth/me` on every load, so a permission change
  /// made by an admin applies without signing out. Mirror that here; failures
  /// (offline, server down) simply keep the cached profile.
  Future<void> _refreshProfile() async {
    try {
      final me = await ApiClient().get('/auth/me');
      final profile = MeProfile.fromJson(me);
      await Session.saveProfile(
        newRole: profile.role.isNotEmpty ? profile.role : (Session.role ?? ''),
        newPermissions: profile.permissions,
        configured: profile.permissionsConfigured,
        name: profile.name.isNotEmpty ? profile.name : null,
        email: profile.email.isNotEmpty ? profile.email : null,
        id: profile.id,
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the cached session; a 401 is already handled by the caller
      // screens' unauthorized handlers.
    }
  }

  void _select(String id) {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (id == _section) return;
    setState(() => _section = id);
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    // Same as the web `useUser().logout`: tell the server (marks the user
    // offline / audit trail) but never block sign-out on the network.
    if (Session.isAuthenticated) {
      try {
        await ApiClient()
            .post('/auth/logout', body: const <String, dynamic>{})
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await Session.clear();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= _breakpoint;

    final sidebar = Sidebar(
      activeId: _section,
      onSelect: _select,
      onLogout: _logout,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.bg,
      drawer: wide
          ? null
          : Drawer(
              width: 284,
              backgroundColor: AppColors.sidebar,
              child: sidebar,
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) SizedBox(width: 272, child: sidebar),
            Expanded(
              child: Column(
                children: [
                  AppHeader(
                    onMenu: wide
                        ? null
                        : () => _scaffoldKey.currentState?.openDrawer(),
                    onSelect: _select,
                    onLogout: _logout,
                  ),
                  const SyncStatusBar(),
                  Expanded(child: _buildSection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    if (!sectionAllowed(_section, Session.role)) {
      return const ComingSoonScreen(
        title: 'Access denied',
        icon: Icons.lock_outline,
        message: 'You do not have permission to open this page. '
            'Ask your administrator to grant it under Roles & Permissions.',
      );
    }
    return _sectionFor(_section);
  }

  Widget _sectionFor(String section) {
    switch (section) {
      case '/dashboard':
        return const DashboardScreen();
      case '/admin/company-profile':
        return const CompanyProfileScreen();
      case '/admin/roles':
        return const RolesScreen();
      case '/admin/settings':
        return const SettingsScreen();
      case '/network/areas':
        return const AreasScreen();
      case '/network/pop':
        return const PopScreen();
      case '/network/olt':
        return const OltScreen();
      case '/network/splitters':
        return const SplittersScreen();
      case '/network/boxes':
        return const BoxesScreen();
      case '/messages/new':
        return const NewMessagesScreen();
      case '/messages/other':
        return const OtherMessagesScreen();
      case '/messages/draft':
        return const DraftMessagesScreen();
      case '/messages/sent':
        return const SentMessagesScreen();
      case '/messages/expired':
        return const ExpiredMessagesScreen();
      case '/messages/whatsapp-draft':
        return const WhatsappDraftScreen();
      case '/crm/customers':
        return const CustomersScreen();
      case '/crm/guarantors':
        return const GuarantorsScreen();
      case '/crm/packages':
        return const PackagesScreen();
      case '/subscribers/corporate':
        return const CorporateScreen();
      case '/subscribers/inquiries':
        return const InquiriesScreen();
      case '/crm/subscriber-detail':
        return const SubscriberDetailScreen();
      case '/sales':
        return const SalesScreen();
      case '/sales/replaced':
        return const ReplacedProductsScreen();
      case '/sales/customers':
        return const SalesCustomersScreen();
      case '/sales/installment-plans':
        return const InstallmentPlansScreen();
      case '/inventory/brands':
        return const BrandsScreen();
      case '/inventory/unit-types':
        return const UnitTypesScreen();
      case '/inventory/product-types':
        return const ProductTypesScreen();
      case '/inventory/products':
        return const ProductsScreen();
      case '/inventory/vendors':
        return const VendorsScreen();
      case '/inventory/vendor-invoices':
        return const VendorInvoicesScreen();
      case '/inventory/purchases':
        return const PurchasesScreen();
      case '/inventory/statuses':
        return const InventoryStatusScreen();
      case '/inventory/stock':
        return const StockScreen();
      case '/inventory/pos':
        return const PointOfSaleScreen();
      case '/transaction/dealers-collections':
        return const DealersCollectionsScreen();
      case '/transaction/user-collections':
        return const UserCollectionsScreen();
      case '/transaction/allocated-collections':
        return const AllocatedCollectionsScreen();
      case '/transaction/transaction-type':
        return const TransactionTypeScreen();
      case '/transaction/bad-debt-collections':
        return const BadDebtCollectionsScreen();
      case '/transaction/bill-creator':
        return const BillCreatorScreen();
      case '/accounts/account-head':
        return const AccountHeadScreen();
      case '/accounts/account-entry':
        return const AccountEntryScreen();
      case '/accounts/account-reports':
        return const AccountReportsScreen();
      case '/accounts/one-day-balance-sheet':
        return const OneDayBalanceSheetScreen();
      case '/recovery-officers-management/officers':
        return const RecoveryOfficersScreen();
      case '/recovery-officers-management/areas':
        return const AreaAssignmentScreen();
      // ---- Complaints ----
      case '/support/complaints/complaint-type':
        return const ComplaintTypesScreen();
      case '/support/complaints/subject-type':
        return const SubjectTypesScreen();
      case '/support/complaints/user':
        return const SubscriberComplaintsScreen();
      case '/support/complaints/allocated':
        return const AllocatedComplaintsScreen();
      case '/support/complaints/report':
        return const ComplaintReportScreen();
      // ---- Human Resources ----
      case '/hr/staff':
        return const StaffScreen();
      case '/hr/salary':
        return const SalaryScreen();
      case '/hr/attendance-day':
        return const AttendanceDayScreen();
      case '/hr/attendance-subscriber':
        return const AttendanceReportScreen();
      case '/hr/advances':
        return const AdvancesScreen();
      // ---- Admin / downloads / dealers ----
      case '/admin/logs':
        return const SystemLogScreen();
      case '/drivers':
        return const DownloadsScreen(key: ValueKey('drivers'), kind: 'drivers');
      case '/applications':
        return const DownloadsScreen(
          key: ValueKey('applications'),
          kind: 'applications',
        );
      case '/franchise/my-dealers':
        return const MyDealersScreen();
      // ---- Subscriber reports ----
      case '/collection/pending-subscribers':
        return const PendingSubscribersScreen();
      case '/collection/advance-subscribers':
        return const ConnectionReportScreen(
          key: ValueKey('advance'),
          kind: ConnectionReportKind.advance,
        );
      case '/subscriber-reports/deactivated-users':
        return const ConnectionReportScreen(
          key: ValueKey('deactivated'),
          kind: ConnectionReportKind.deactivated,
        );
      case '/subscriber-reports/expiry-defaulters':
        return const ConnectionReportScreen(
          key: ValueKey('expiry'),
          kind: ConnectionReportKind.expiryDefaulters,
        );
      case '/subscriber-reports/new-subscribers':
        return const ConnectionReportScreen(
          key: ValueKey('new'),
          kind: ConnectionReportKind.newSubscribers,
        );
      case '/subscriber-reports/package-wise':
        return const ConnectionReportScreen(
          key: ValueKey('package'),
          kind: ConnectionReportKind.packageWise,
        );
      case '/subscriber-reports/creator-summary':
        return const ConnectionReportScreen(
          key: ValueKey('creator'),
          kind: ConnectionReportKind.creatorSummary,
        );
    }

    final item = findNavItem(section);
    return ComingSoonScreen(
      title: item?.title ?? 'Section',
      icon: item?.icon ?? Icons.hourglass_top_outlined,
    );
  }
}
