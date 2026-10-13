import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/navigation.dart';
import '../../theme/app_theme.dart';
import '../../theme/tailwind.dart';
import 'auth_flow.dart';
import 'auth_ui.dart';

/// Port of `client/src/app/signup/page.tsx`.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static const routeName = '/signup';

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final base = await ApiConfig.resolve();
    if (mounted) setState(() => _serverUrl = base);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.landing, (_) => false);
  }

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: _serverUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend server URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:8090/api/v1',
            helperText: 'Leave empty to use the default server',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url == null) return;
    final resolved = await ApiConfig.resolve(override: url);
    if (mounted) setState(() => _serverUrl = resolved);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    try {
      await ApiConfig.resolve();
      final api = ApiClient();

      final response = await api.post(
        '/auth/signup',
        body: {
          'name': _nameController.text.trim(),
          'companyName': _companyController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      final token = response['token'] as String?;
      final user = (response['user'] as Map<String, dynamic>?) ?? const {};

      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: false,
        title: 'Account Created',
        message:
            'Your account has been created successfully. You will be '
            'redirected to your dashboard.',
        confirmLabel: 'Go to Dashboard',
        onConfirm: () async {
          if (!mounted) return;
          if (token == null || token.isEmpty) return;
          try {
            await AuthFlow.continueWithToken(context, token: token, user: user);
          } on ApiException catch (e) {
            if (!mounted) return;
            await showMessageDialog(
              context,
              isError: true,
              title: 'Registration Failed',
              message: e.message,
            );
          }
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: e.statusCode == 409
            ? 'Email already exists'
            : 'Registration Failed',
        message: e.message.isEmpty
            ? 'Registration failed. Please try again.'
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: 'Registration Failed',
        message: 'Registration failed. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final md = isMdWide(context);

    return AuthShell(
      panel: _SignupPanel(md: md),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackToHomeLink(onTap: _goHome),
          const SizedBox(height: 16),
          AuthCard(
            title: 'Create Account',
            description: 'Join thousands of ISPs managing their business with Fintrack ERP',
            child: _buildForm(context),
          ),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: _editServerUrl,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      size: 13,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _serverUrl ?? 'Locating server…',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthField(
            label: 'Full Name',
            controller: _nameController,
            hint: 'John Doe',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Company Name',
            controller: _companyController,
            hint: 'Acme Inc.',
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Company name is required'
                : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Email',
            controller: _emailController,
            hint: 'm@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Email is required' : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Password',
            controller: _passwordController,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'Create Account',
            loadingLabel: 'Creating Account...',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(fontSize: 14, color: Tw.gray600),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pushNamed(Routes.login),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Tw.gray900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `hidden lg:flex` right pane of the web signup page.
class _SignupPanel extends StatelessWidget {
  const _SignupPanel({required this.md});

  final bool md;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Transform Your ISP Business Today',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: md ? 36 : 30,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Color(0x2E000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          "Get started with the world's most comprehensive ISP management "
          'platform. Join 500+ ISPs already using Fintrack ERP worldwide.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.625, color: Tw.gray300),
        ),
        const SizedBox(height: 40),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelFeature(
              icon: Icons.bolt,
              title: 'Quick Setup',
              subtitle: 'Get started in minutes, not days',
            ),
            SizedBox(height: 8),
            PanelFeature(
              icon: Icons.groups_outlined,
              title: 'Free Trial',
              subtitle: '14 days free, no credit card required',
            ),
            SizedBox(height: 8),
            PanelFeature(
              icon: Icons.language,
              title: 'Global Ready',
              subtitle: 'Support for multiple currencies and languages',
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What you'll get:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _CheckRow('Complete ISP management suite'),
              const SizedBox(height: 12),
              _CheckRow('Automated billing & invoicing'),
              const SizedBox(height: 12),
              _CheckRow('Customer relationship management'),
              const SizedBox(height: 12),
              _CheckRow('24/7 customer support'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 20, color: Tw.green400),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Tw.gray300),
          ),
        ),
      ],
    );
  }
}
