import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'admin_utils.dart';
import 'permission_defs.dart';

const List<PermissionDef> _defs = kPermissionDefs;

List<String> get _modules => kPermissionModules;

/// Folder sidebar filter options, computed like the web's `FOLDER_OPTIONS`
/// (secondary shows "N permissions" for the folder's modules).
List<({String id, String name, String secondary})> get _folderOptions => [
  for (final f in kPermissionFolders)
    (
      id: f.id,
      name: f.name,
      secondary:
          '${f.modules.isEmpty ? _defs.length : _defs.where((p) => f.modules.contains(p.module)).length} permissions',
    ),
];

/// Flutter counterpart of `client/src/app/(app)/admin/roles/{page.tsx,
/// _components/client-page.tsx}` — KPI cards, user picker, folder filter and
/// the permission table with per-page CRUD children grouped by module.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  static const List<
    ({String key, String label, IconData icon, String endpoint})
  >
  _userCategories = [
    (
      key: 'staff',
      label: 'Staff',
      icon: Icons.people_outline,
      endpoint: 'hr/staff',
    ),
    (
      key: 'recovery',
      label: 'Recovery Officer',
      icon: Icons.how_to_reg_outlined,
      endpoint: 'admin/recovery-officers',
    ),
    (
      key: 'dealer',
      label: 'Dealer',
      icon: Icons.handshake_outlined,
      endpoint: 'dealers',
    ),
  ];

  List<Map<String, dynamic>> _roles = [];
  bool _rolesLoading = true;

  String _category = '';
  final _searchController = TextEditingController();
  String _search = '';
  bool _showDropdown = false;
  String? _selectedUserId;
  String _selectedUserName = '';
  bool _permLoaded = false;
  bool _isLoadingPerms = false;
  bool _isSaving = false;

  String _selectedFolder = kAllFoldersId;
  final Map<String, bool> _expanded = {};

  final Map<String, List<Map<String, dynamic>>> _usersByCategory = {};
  Map<String, ({bool web, bool mobile})> _perm = {};
  late final Map<String, List<ChildDef>> _childrenByParent = () {
    final map = <String, List<ChildDef>>{};
    for (final child in kPermissionChildDefs) {
      map.putIfAbsent(child.parentId, () => []).add(child);
    }
    return map;
  }();

  static void _handleUnauthorized() {
    Session.clear();
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  String? get _cid => Session.companyId;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    final cid = _cid;
    setState(() => _rolesLoading = true);
    try {
      final json = await _api.get(
        '/admin/roles',
        query: {if (cid != null && cid.isNotEmpty) 'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _roles = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .toList();
        _rolesLoading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() {
        _roles = [];
        _rolesLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _userList => _usersByCategory[_category] ?? [];

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _search.trim();
    final list = query.isEmpty
        ? _userList.take(20).toList()
        : <Map<String, dynamic>>[];
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    final result = _userList
        .where((u) {
          final id = (u['id'] as String?) ?? '';
          final name = (u['name'] as String?) ?? '';
          final email = (u['email'] as String?) ?? '';
          final phone = (u['phone'] as String?) ?? '';
          return id.toLowerCase().contains(q) ||
              name.toLowerCase().contains(q) ||
              email.toLowerCase().contains(q) ||
              phone.toLowerCase().contains(q);
        })
        .take(20)
        .toList();
    return result;
  }

  Future<void> _selectCategory(String key) async {
    final cid = _cid;
    setState(() {
      _category = key;
      _selectedUserId = null;
      _selectedUserName = '';
      _search = '';
      _searchController.clear();
      _permLoaded = false;
      _perm = {};
    });
    if (cid == null || cid.isEmpty || _usersByCategory.containsKey(key)) return;
    try {
      final spec = _userCategories.firstWhere((c) => c.key == key);
      final json = await _api.get(spec.endpoint, query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _usersByCategory[key] = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _usersByCategory[key] = []);
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUserId = user['id'] as String?;
      _selectedUserName = (user['name'] ?? user['email'] ?? '') as String;
      _search = _selectedUserName;
      _searchController.text = _search;
      _showDropdown = false;
      _permLoaded = false;
      _perm = {};
    });
  }

  // ------------------------------------------------------------------ Data --

  Future<void> _loadPermissions() async {
    final userId = _selectedUserId;
    final cid = _cid;
    if (userId == null || cid == null) return;
    setState(() => _isLoadingPerms = true);
    try {
      final json = await _api.get(
        '/admin/roles/users/$userId/permissions',
        query: {'companyId': cid},
      );
      final data = ApiClient.listData(json).whereType<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        final map = <String, ({bool web, bool mobile})>{
          for (final id in allPermissionIds) id: (web: false, mobile: false),
        };
        final saved = <String>{};
        for (final p in data) {
          final id = (p['permissionId'] as String?) ?? '';
          if (id.isEmpty || !map.containsKey(id)) continue;
          map[id] = (
            web: (p['webEnabled'] as bool?) ?? true,
            mobile: (p['mobileEnabled'] as bool?) ?? true,
          );
          saved.add(id);
        }
        // Per-page CRUD children inherit their parent's state when the parent
        // was saved before these children existed.
        for (final child in kPermissionChildDefs) {
          if (saved.contains(child.id)) continue;
          final parent = map[child.parentId] ?? (web: false, mobile: false);
          map[child.id] = (web: parent.web, mobile: parent.mobile);
        }
        _perm = map;
        _permLoaded = true;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, 'Failed to load permissions', error: true);
    } finally {
      if (mounted) setState(() => _isLoadingPerms = false);
    }
  }

  // Cascade helpers mirroring the web's `setWithChildren` /
  // `setParentFromChild`.

  void _toggleWeb(String id) {
    setState(() {
      final prev = _perm[id] ?? (web: false, mobile: false);
      final web = !prev.web;
      _perm[id] = (web: web, mobile: prev.mobile);
      for (final child in _childrenByParent[id] ?? const <ChildDef>[]) {
        final c = _perm[child.id] ?? (web: false, mobile: false);
        _perm[child.id] = (web: web, mobile: c.mobile);
      }
    });
  }

  void _toggleMobile(String id) {
    setState(() {
      final prev = _perm[id] ?? (web: false, mobile: false);
      final mobile = !prev.mobile;
      _perm[id] = (web: prev.web, mobile: mobile);
      for (final child in _childrenByParent[id] ?? const <ChildDef>[]) {
        final c = _perm[child.id] ?? (web: false, mobile: false);
        _perm[child.id] = (web: c.web, mobile: mobile);
      }
    });
  }

  void _toggleChildWeb(String parentId, String childId) {
    setState(() {
      final prev = _perm[childId] ?? (web: false, mobile: false);
      final web = !prev.web;
      _perm[childId] = (web: web, mobile: prev.mobile);
      if (!(_perm[parentId]?.web ?? false) && !web) return;
      final parent = _perm[parentId] ?? (web: false, mobile: false);
      _perm[parentId] = (web: true, mobile: parent.mobile);
    });
  }

  void _toggleChildMobile(String parentId, String childId) {
    setState(() {
      final prev = _perm[childId] ?? (web: false, mobile: false);
      final mobile = !prev.mobile;
      _perm[childId] = (web: prev.web, mobile: mobile);
      if (!(_perm[parentId]?.mobile ?? false) && !mobile) return;
      final parent = _perm[parentId] ?? (web: false, mobile: false);
      _perm[parentId] = (web: parent.web, mobile: true);
    });
  }

  /// Parents and their per-page CRUD children for a module (the module "select
  /// all" must cover the children too, otherwise it can never read as checked).
  List<String> _modulePermissionIds(String module) => [
    for (final p in _defs.where((p) => p.module == module)) p.id,
    for (final p in kPermissionChildDefs.where((p) => p.module == module)) p.id,
  ];

  void _toggleModuleWeb(String module, bool checked) {
    setState(() {
      for (final id in _modulePermissionIds(module)) {
        final prev = _perm[id] ?? (web: false, mobile: false);
        _perm[id] = (web: checked, mobile: prev.mobile);
      }
    });
  }

  void _toggleModuleMobile(String module, bool checked) {
    setState(() {
      for (final id in _modulePermissionIds(module)) {
        final prev = _perm[id] ?? (web: false, mobile: false);
        _perm[id] = (web: prev.web, mobile: checked);
      }
    });
  }

  bool _moduleWebAll(String module) =>
      _modulePermissionIds(module).every((id) => _perm[id]?.web == true);

  bool _moduleMobileAll(String module) =>
      _modulePermissionIds(module).every((id) => _perm[id]?.mobile == true);

  int get _enabledCount => _perm.values.where((v) => v.web || v.mobile).length;

  Future<void> _savePermissions() async {
    final userId = _selectedUserId;
    final cid = _cid;
    if (userId == null || cid == null) return;
    setState(() => _isSaving = true);
    try {
      final permList = [
        for (final entry in _perm.entries)
          {
            'permissionId': entry.key,
            'webEnabled': entry.value.web,
            'mobileEnabled': entry.value.mobile,
          },
      ];
      await _api.put(
        '/admin/roles/users/$userId/permissions',
        body: {'permissions': permList, 'companyId': cid},
      );
      if (!mounted) return;
      showToast(context, 'Permissions saved successfully.');
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ------------------------------------------------------------------ UI ---

  @override
  Widget build(BuildContext context) {
    final visibleModules = _selectedFolder == kAllFoldersId
        ? _modules
        : (_folderById(_selectedFolder)?.modules ?? _modules)
              .where(_modules.contains)
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const AdminPageHeader(
          icon: Icons.key_outlined,
          title: 'Role Management',
          subtitle: 'Manage roles, permissions, and access levels.',
        ),
        _buildKpis(context),
        const SizedBox(height: 20),
        _selectSubscriberCard(context),
        if (_permLoaded) ...[
          const SizedBox(height: 16),
          _permCard(context, visibleModules),
        ],
      ],
    );
  }

  PermissionFolder? _folderById(String id) {
    for (final f in kPermissionFolders) {
      if (f.id == id) return f;
    }
    return null;
  }

  Widget _buildKpis(BuildContext context) {
    // The Go Role model serializes `permissions` as a comma-joined string
    // (`strings.Join(roleData.Permissions, ",")`), so both shapes are handled.
    Iterable<String> permsOf(Map<String, dynamic> role) {
      final raw = role['permissions'];
      if (raw is List) return raw.whereType<String>();
      if (raw is String) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      }
      return const <String>[];
    }

    int permissionsCount = 0;
    int withUsers = 0;
    final seenPerms = <String>{};
    for (final role in _roles) {
      for (final p in permsOf(role)) {
        if (seenPerms.add(p)) permissionsCount++;
      }
      final count = (role['_count'] as Map<String, dynamic>?)?['users'];
      if (count is num && count > 0) withUsers++;
    }

    final kpis = [
      (
        label: 'Total Roles',
        value: _roles.length,
        icon: Icons.verified_user_outlined,
        iconColor: const Color(0xFF2563EB),
        bg: const Color(0xFFDBEAFE),
      ),
      (
        label: 'With Subscribers',
        value: withUsers,
        icon: Icons.people_outline,
        iconColor: const Color(0xFF059669),
        bg: const Color(0xFFD1FAE5),
      ),
      (
        label: 'Permissions',
        value: permissionsCount,
        icon: Icons.key_outlined,
        iconColor: const Color(0xFF9333EA),
        bg: const Color(0xFFF3E8FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < kpis.length; i++)
              SizedBox(
                width: columns == 3
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth,
                child: _KpiCard(kpi: kpis[i], loading: _rolesLoading),
              ),
          ],
        );
      },
    );
  }

  Widget _selectSubscriberCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Subscriber',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in _userCategories)
                _CategoryTab(
                  label: cat.label,
                  icon: cat.icon,
                  selected: _category == cat.key,
                  onTap: () => _selectCategory(cat.key),
                ),
            ],
          ),
          if (_category.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Responsive: input + Show button sit side-by-side when there is
            // room, stack otherwise. The input column holds its own dropdown.
            LayoutBuilder(
              builder: (context, constraints) {
                final input = _userSearchInput(context);
                final show = _BlueButton(
                  label: 'Show',
                  icon: Icons.remove_red_eye_outlined,
                  loading: _isLoadingPerms,
                  onPressed: (_selectedUserId == null || _isLoadingPerms)
                      ? null
                      : _loadPermissions,
                );
                if (constraints.maxWidth >= 420) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 10),
                      show,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: show),
                  ],
                );
              },
            ),
            if (_selectedUserId != null) ...[
              const SizedBox(height: 12),
              _selectedBadge(context),
            ],
          ],
        ],
      ),
    );
  }

  Widget _userSearchInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search by name or ID',
          style: TextStyle(fontSize: 12, color: context.mutedFg),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.line),
            borderRadius: BorderRadius.circular(8),
            color: context.inputFill,
          ),
          child: TextField(
            key: const ValueKey('roles-search'),
            controller: _searchController,
            onChanged: (v) {
              setState(() {
                _search = v;
                _showDropdown = true;
              });
            },
            onTap: () => setState(() => _showDropdown = true),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type name or ID...',
              filled: false,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 34,
                vertical: 12,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 18, color: context.mutedFg),
              ),
            ),
          ),
        ),
        if (_showDropdown && _filteredUsers.isNotEmpty) _userDropdown(context),
      ],
    );
  }

  Widget _selectedBadge(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.subtle,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              _selectedUserId!.length > 8
                  ? _selectedUserId!.substring(0, 8)
                  : _selectedUserId!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('•'),
            ),
            Flexible(
              child: Text(
                _selectedUserName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userDropdown(BuildContext context) {
    final users = _filteredUsers;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < users.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.line),
                InkWell(
                  onTap: () => _selectUser(users[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          users[i]['id'].toString().length > 8
                              ? users[i]['id'].toString().substring(0, 8)
                              : users[i]['id'].toString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (users[i]['name'] as String?) ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (((users[i]['email'] ?? users[i]['phone'])
                                    as String?)
                                ?.isNotEmpty ??
                            false) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              (users[i]['email'] ?? users[i]['phone'])
                                  .toString(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedFg,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _permCard(BuildContext context, List<String> visibleModules) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_enabledCount permissions enabled',
                      style: TextStyle(fontSize: 14, color: context.mutedFg),
                    ),
                  ],
                );
                final dropdown = _FolderDropdown(
                  items: _folderOptions,
                  value: _selectedFolder,
                  onChanged: (id) => setState(() => _selectedFolder = id),
                  placeholder: 'Search folder...',
                );
                if (constraints.maxWidth >= 560) {
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      dropdown,
                      const SizedBox(width: 12),
                      EmeraldButton(
                        label: _isSaving ? 'Saving...' : 'Save',
                        icon: Icons.save_outlined,
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _savePermissions,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    dropdown,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: EmeraldButton(
                        label: _isSaving ? 'Saving...' : 'Save',
                        icon: Icons.save_outlined,
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _savePermissions,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: context.line),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _permissionTable(context, visibleModules),
          ),
        ],
      ),
    );
  }

  static const double _colId = 150;
  static const double _colName = 250;
  static const double _colModule = 170;
  static const double _colWeb = 72;
  static const double _colMobile = 72;

  Widget _permissionTable(BuildContext context, List<String> visibleModules) {
    const tableWidth = _colId + _colName + _colModule + _colWeb + _colMobile;
    return SizedBox(
      width: tableWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: context.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.6)
                : AppColors.muted.withValues(alpha: 0.6),
            child: Row(
              children: [
                _cell('ID', _colId),
                _cell('Name', _colName),
                _cell('Module Name', _colModule),
                _cell('Website', _colWeb, center: true),
                _cell('Mobile', _colMobile, center: true),
              ],
            ),
          ),
          if (visibleModules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No permissions found for this folder.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mutedFg),
              ),
            )
          else
            for (final module in visibleModules) ...[
              _moduleRow(context, module),
              for (final p in _defs.where((p) => p.module == module))
                _permissionRow(context, p),
            ],
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool center = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _moduleRow(BuildContext context, String module) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkMuted : AppColors.muted,
        border: Border(bottom: BorderSide(color: context.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Text(
              module,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _toggleModuleWeb(module, !_moduleWebAll(module)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _moduleWebAll(module),
                    onChanged: (v) => _toggleModuleWeb(module, v ?? false),
                  ),
                  Text(
                    'Web',
                    style: TextStyle(fontSize: 12, color: context.mutedFg),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  _toggleModuleMobile(module, !_moduleMobileAll(module)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _moduleMobileAll(module),
                    onChanged: (v) => _toggleModuleMobile(module, v ?? false),
                  ),
                  Text(
                    'Mobile',
                    style: TextStyle(fontSize: 12, color: context.mutedFg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionRow(BuildContext context, PermissionDef p) {
    final perm = _perm[p.id] ?? (web: false, mobile: false);
    final children = _childrenByParent[p.id] ?? const <ChildDef>[];
    final isOpen = _expanded[p.id] ?? false;
    final expandable = children.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: expandable ? () => _toggleExpanded(p.id) : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.line)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _colId,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      p.id,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: context.mutedFg,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _colName,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (expandable) ...[
                          Icon(
                            isOpen
                                ? Icons.arrow_drop_down
                                : Icons.chevron_right,
                            size: 18,
                            color: context.mutedFg,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: expandable
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: _colModule,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      p.module,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: context.mutedFg),
                    ),
                  ),
                ),
                SizedBox(
                  width: _colWeb,
                  child: Center(child: check(perm.web, () => _toggleWeb(p.id))),
                ),
                SizedBox(
                  width: _colMobile,
                  child: Center(
                    child: check(perm.mobile, () => _toggleMobile(p.id)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          for (final child in children) _childRow(context, p, child),
      ],
    );
  }

  void _toggleExpanded(String id) {
    setState(() => _expanded[id] = !(_expanded[id] ?? false));
  }

  Widget _childRow(BuildContext context, PermissionDef parent, ChildDef child) {
    final perm = _perm[child.id] ?? (web: false, mobile: false);
    return Container(
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.darkMuted.withValues(alpha: 0.35)
            : AppColors.muted.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: context.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _colId,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 40,
                right: 12,
                top: 6,
                bottom: 6,
              ),
              child: Text(
                child.id,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: context.mutedFg.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _colName,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 40,
                right: 12,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                children: [
                  Text('↳', style: TextStyle(color: context.mutedFg)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      child.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _colModule,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 40,
                right: 12,
                top: 6,
                bottom: 6,
              ),
              child: Text(
                parent.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.mutedFg),
              ),
            ),
          ),
          SizedBox(
            width: _colWeb,
            child: Center(
              child: check(
                perm.web,
                () => _toggleChildWeb(child.parentId, child.id),
              ),
            ),
          ),
          SizedBox(
            width: _colMobile,
            child: Center(
              child: check(
                perm.mobile,
                () => _toggleChildMobile(child.parentId, child.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget check(bool value, VoidCallback onTap) {
    return Checkbox(value: value, onChanged: (_) => onTap());
  }
}

/// Searchable dropdown mirroring the web `SearchableDropdown`
/// (`matchContainsOnly`): typing filters by id / name / secondary, no clear
/// button, clicking an option closes it.
class _FolderDropdown extends StatefulWidget {
  const _FolderDropdown({
    required this.items,
    required this.value,
    required this.onChanged,
    required this.placeholder,
  });

  final List<({String id, String name, String secondary})> items;
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  State<_FolderDropdown> createState() => _FolderDropdownState();
}

class _FolderDropdownState extends State<_FolderDropdown> {
  final _controller = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({String id, String name, String secondary})? get _selected {
    for (final item in widget.items) {
      if (item.id == widget.value) return item;
    }
    return null;
  }

  List<({String id, String name, String secondary})> get _filtered {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where(
          (i) =>
              i.id.toLowerCase().contains(q) ||
              i.name.toLowerCase().contains(q) ||
              i.secondary.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapRegion(
      onTapOutside: (_) {
        setState(() {
          _open = false;
          _controller.clear();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _open ? theme.colorScheme.primary : context.line,
              ),
              borderRadius: BorderRadius.circular(8),
              color: context.inputFill,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search, size: 16, color: context.mutedFg),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() => _open = true),
                    onTap: () => setState(() => _open = true),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: _selected == null ? context.mutedFg : context.fg,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      suffixIcon: _selected != null && !_open
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '✓',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 208),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No results found',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: context.mutedFg),
                      ),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < _filtered.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: context.line),
                              InkWell(
                                onTap: () {
                                  widget.onChanged(_filtered[i].id);
                                  setState(() {
                                    _open = false;
                                    _controller.clear();
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  color: _filtered[i].id == widget.value
                                      ? context.subtle
                                      : null,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _filtered[i].name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              _filtered[i].id == widget.value
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (_filtered[i].secondary.isNotEmpty)
                                        Text(
                                          _filtered[i].secondary,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: context.mutedFg,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, required this.loading});

  final ({String label, int value, IconData icon, Color iconColor, Color bg})
  kpi;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kpi.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.mutedFg,
                  ),
                ),
                const SizedBox(height: 10),
                loading
                    ? Container(
                        height: 28,
                        width: 90,
                        decoration: BoxDecoration(
                          color: context.line,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        '${kpi.value}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kpi.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(kpi.icon, size: 20, color: kpi.iconColor),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.fg;
    final background = selected ? AppColors.primary : context.surface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: selected ? null : Border.all(color: context.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blue gradient button (`bg-gradient-to-r from-blue-500 to-cyan-600`).
class _BlueButton extends StatelessWidget {
  const _BlueButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? const [Color(0xFF3B82F6), Color(0xFF0891B2)]
                : const [Color(0xFF93C5FD), Color(0xFF67E8F9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
