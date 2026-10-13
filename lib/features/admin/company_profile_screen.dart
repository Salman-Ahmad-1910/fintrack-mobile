import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'admin_utils.dart';

/// Flutter counterpart of `client/src/app/(app)/admin/company-profile/page.tsx`
/// — edit a company's public info, POS discount limits and invoice stamp.
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  Map<String, dynamic>? _company;
  bool _loading = true;
  bool _saving = false;
  bool _savingDiscount = false;
  bool _stampUploading = false;
  bool _logoUploading = false;
  int _stampVersion = 0;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact1 = TextEditingController();
  final _contact2 = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _posPercent = TextEditingController();

  bool _posUnlimited = false;

  String? get _cid => Session.companyId;

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

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _contact1,
      _contact2,
      _address,
      _description,
      _posPercent,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() {
        _loading = false;
        _company = null;
      });
      return;
    }
    try {
      final json = await _api.get('/admin/companies/$cid');
      if (!mounted) return;
      setState(() {
        _company = json;
        _loading = false;
        _applyCompany(json);
        _stampVersion = 0;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _company = null;
      });
    }
  }

  void _applyCompany(Map<String, dynamic> company) {
    String s(String key) => (company[key] as String?) ?? '';

    _name.text = s('name');
    _email.text = s('email');
    _contact1.text = s('contact1');
    _contact2.text = s('contact2');
    _address.text = s('address');
    _description.text = s('description');
    final pct = company['posDiscountPercent'];
    _posPercent.text = pct == null
        ? ''
        : (pct is num
              ? (pct == pct.roundToDouble() ? pct.toInt().toString() : '$pct')
              : '$pct');
    _posUnlimited = company['posDiscountUnlimited'] == true;
  }

  double get _posPct => double.tryParse(_posPercent.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AdminPageHeader(
            icon: Icons.business_outlined,
            title: 'Company Profile',
            subtitle: "Manage your company's public information and settings.",
          ),
          if (_company == null && !_loading)
            _NoCompanyCard(onRetry: _retry)
          else if (_company == null)
            _LoadingCard()
          else
            ..._buildForm(context),
        ],
      ),
    );
  }

  void _retry() {
    setState(() => _loading = true);
    _fetch();
  }

  List<Widget> _buildForm(BuildContext context) {
    final company = _company!;
    return [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row: logo upload + editable name + Save Changes.
            LayoutBuilder(
              builder: (context, constraints) {
                final logo = _LogoUpload(
                  company: company,
                  uploading: _logoUploading,
                  onChanged: _onLogoChanged,
                );
                final title = Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _name.text.trim().isEmpty ? 'Company' : _name.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                );
                final save = EmeraldButton(
                  label: _saving ? 'Saving...' : 'Save Changes',
                  loading: _saving,
                  onPressed: _saving ? null : _saveChanges,
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          logo,
                          const SizedBox(width: 16),
                          Expanded(child: title),
                        ],
                      ),
                      const SizedBox(height: 12),
                      save,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    logo,
                    const SizedBox(width: 16),
                    Expanded(child: title),
                    save,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _field('Company Name', _name),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _field('Contact Email', _email)),
                const SizedBox(width: 12),
                Expanded(child: _field('Contact Phone 1', _contact1)),
              ],
            ),
            const SizedBox(height: 16),
            _field('Contact Phone 2', _contact2),
            const SizedBox(height: 16),
            _field('Address', _address, maxLines: 3),
            const SizedBox(height: 16),
            _field('Description', _description, maxLines: 3),
            const Divider(height: 32),
            // ---------------- POS discount ----------------
            Text(
              'POS Discount Limit (%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.fg,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _posPercent,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'e.g., 10'),
            ),
            const SizedBox(height: 6),
            Text(
              "Maximum discount a POS user can give, as a percentage of the sale's selling-price total.",
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 48,
                  child: Checkbox(
                    value: _posUnlimited,
                    onChanged: (v) =>
                        setState(() => _posUnlimited = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlimited discount in POS',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.fg,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        'When checked, the percentage limit is ignored and only the selling price caps the discount.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.mutedFg,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final saveDiscount = OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: (_saving || _savingDiscount)
                      ? null
                      : _saveDiscount,
                  child: _savingDiscount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Discount % Permanently'),
                );
                final note = Text(
                  'Saves the POS discount percentage and unlimited checkbox to this company permanently.',
                  style: TextStyle(fontSize: 12, color: context.mutedFg),
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      saveDiscount,
                      const SizedBox(height: 8),
                      note,
                    ],
                  );
                }
                return Row(
                  children: [
                    saveDiscount,
                    const SizedBox(width: 12),
                    Expanded(child: note),
                  ],
                );
              },
            ),
            const Divider(height: 32),
            // ---------------- Stamp ----------------
            Text(
              'Company Stamp',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Stamp image shown on printed invoices.',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StampBox(
                  stampUrl: company['stamp'] == null
                      ? null
                      : '${ApiConfig.base}/uploads/company_stamps/$_cid?v=$_stampVersion',
                  hasStamp: (company['stamp'] as String?)?.isNotEmpty ?? false,
                  uploading: _stampUploading,
                  onPick: _pickStamp,
                  onDelete: _deleteStamp,
                ),
                if ((company['stamp'] as String?)?.isNotEmpty ?? false)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: _stampUploading ? null : _deleteStamp,
                    child: const Text('Remove Stamp'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ];
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _saveChanges() async {
    final company = _company;
    if (company == null) return;
    setState(() => _saving = true);
    try {
      await _api.put(
        '/admin/companies/${company['id']}',
        body: {
          ...company,
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'contact1': _contact1.text.trim(),
          'contact2': _contact2.text.trim(),
          'address': _address.text.trim(),
          'description': _description.text.trim(),
          'posDiscountPercent': _posPct,
          'posDiscountUnlimited': _posUnlimited,
        },
      );
      if (!mounted) return;
      showToast(context, 'Company updated successfully.');
      _fetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(
        context,
        e.isUnauthorized ? 'Session expired' : e.message,
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDiscount() async {
    final company = _company;
    if (company == null) return;
    setState(() => _savingDiscount = true);
    try {
      await _api.put(
        '/admin/companies/${company['id']}',
        body: {
          ...company,
          'posDiscountPercent': _posPct,
          'posDiscountUnlimited': _posUnlimited,
        },
      );
      if (!mounted) return;
      showToast(context, 'POS discount settings saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingDiscount = false);
    }
  }

  Future<PlatformFile?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    return result?.files.single;
  }

  Future<void> _pickStamp() async {
    final file = await _pickImage();
    if (file == null || file.path == null) return;
    final name = file.name.toLowerCase();
    if (!(name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png'))) {
      if (mounted) {
        showToast(
          context,
          'Please select a JPG, JPEG, or PNG file.',
          error: true,
        );
      }
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        showToast(
          context,
          'Please select an image smaller than 5MB.',
          error: true,
        );
      }
      return;
    }
    setState(() => _stampUploading = true);
    try {
      await _api.postFile(
        '/upload/company-stamp',
        filePath: file.path!,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() => _stampVersion++);
      showToast(context, 'Company stamp uploaded successfully.');
      _fetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _stampUploading = false);
    }
  }

  Future<void> _deleteStamp() async {
    try {
      await _api.delete('/upload/company-stamp');
      if (!mounted) return;
      setState(() => _stampVersion++);
      showToast(context, 'Company stamp removed successfully.');
      _fetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _onLogoChanged() async {
    final file = await _pickImage();
    if (file == null || file.path == null) return;
    final name = file.name.toLowerCase();
    if (!(name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png'))) {
      if (mounted) {
        showToast(
          context,
          'Please select a JPG, JPEG, or PNG file.',
          error: true,
        );
      }
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        showToast(
          context,
          'Please select an image smaller than 5MB.',
          error: true,
        );
      }
      return;
    }
    setState(() => _logoUploading = true);
    try {
      final res = await _api.postFile(
        '/upload/company-image',
        filePath: file.path!,
        filename: file.name,
      );
      final filename = (res['filename'] as String?) ?? '';
      final company = _company;
      if (company != null && filename.isNotEmpty) {
        await _api.put(
          '/admin/companies/${company['id']}',
          body: {...company, 'logo': filename},
        );
      }
      if (!mounted) return;
      showToast(context, 'Company image uploaded successfully.');
      _fetch();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _logoUploading = false);
    }
  }
}

class _NoCompanyCard extends StatelessWidget {
  const _NoCompanyCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Company Selected',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Please select a company to view its profile.',
            style: TextStyle(fontSize: 14, color: context.mutedFg),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(48),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Company logo tile: shows the current logo (or a fallback) and lets the
/// user pick a new one. The Delete appears in the header as "Remove Picture".
class _LogoUpload extends StatelessWidget {
  const _LogoUpload({
    required this.company,
    required this.onChanged,
    this.uploading = false,
  });

  final Map<String, dynamic> company;
  final Future<void> Function() onChanged;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final cid = company['id'] as String?;
    return GestureDetector(
      onTap: uploading ? null : onChanged,
      child: Container(
        width: 80,
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.line),
          color: context.subtle,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cid == null || cid.isEmpty)
              _fallback()
            else
              Image.network(
                '${ApiConfig.base}/uploads/company_images/$cid',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _fallback(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
              ),
            if (uploading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.business_rounded, color: Colors.white, size: 28),
    );
  }
}

class _StampBox extends StatelessWidget {
  const _StampBox({
    required this.stampUrl,
    required this.hasStamp,
    required this.uploading,
    required this.onPick,
    required this.onDelete,
  });

  final String? stampUrl;
  final bool hasStamp;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 128,
        height: 80,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: context.line, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: context.isDark ? AppColors.darkMuted : const Color(0xFFF9FAFB),
        ),
        child: hasStamp && stampUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    stampUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  if (uploading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _miniBtn(
                          Icons.upload_outlined,
                          Colors.white,
                          AppColors.emerald600,
                          onPick,
                        ),
                        const SizedBox(width: 6),
                        _miniBtn(
                          Icons.delete_outline,
                          Colors.white,
                          AppColors.destructive,
                          onDelete,
                        ),
                      ],
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (uploading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.sell_outlined, size: 20, color: context.mutedFg),
                  const SizedBox(height: 2),
                  Text(
                    'Upload Stamp',
                    style: TextStyle(fontSize: 10, color: context.mutedFg),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color fg, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: fg),
      ),
    );
  }
}
