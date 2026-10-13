import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/navigation.dart';
import '../../theme/app_theme.dart';
import '../../theme/tailwind.dart';
import 'auth_flow.dart';
import 'auth_ui.dart';
import 'forgot_password_screen.dart';

/// Port of `client/src/app/login/page.tsx`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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

      final auth = await api.post(
        '/auth/login',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      final token = auth['token'] as String?;
      final user = (auth['user'] as Map<String, dynamic>?) ?? const {};
      if (token == null || token.isEmpty) {
        throw ApiException('Server did not return a session token');
      }

      if (!mounted) return;
      await AuthFlow.continueWithToken(context, token: token, user: user);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: 'Sign In Failed',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: 'Sign In Failed',
        message: 'Invalid credentials. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final md = isMdWide(context);

    return AuthShell(
      panel: _LoginPanel(md: md),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackToHomeLink(onTap: _goHome),
          const SizedBox(height: 16),
          AuthCard(
            title: 'Welcome Back',
            description: 'Sign in to access your ISP management dashboard',
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
            label: 'Email',
            controller: _emailController,
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Password',
            controller: _passwordController,
            hint: 'Enter your password',
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            labelAction: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(fontSize: 12, color: Tw.gray600),
              ),
            ),
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
            label: 'Sign In',
            loadingLabel: 'Signing In...',
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
                  "Don't have an account?",
                  style: TextStyle(fontSize: 14, color: Tw.gray600),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pushNamed(Routes.signup),
                  child: const Text(
                    'Sign up',
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

/// `hidden lg:flex` right pane of the web login page.
class _LoginPanel extends StatelessWidget {
  const _LoginPanel({required this.md});

  final bool md;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Manage Your ISP Business Like Never Before',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: md ? 48 : 36,
            fontWeight: FontWeight.w700,
            height: 1.15,
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
        const SizedBox(height: 48),
        const Text(
          'Join thousands of ISPs worldwide who trust Fintrack ERP for '
          'comprehensive business management, billing, and customer support.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, height: 1.625, color: Tw.gray300),
        ),
        const SizedBox(height: 48),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelFeature(
              icon: Icons.groups_outlined,
              title: '500+ ISPs',
              subtitle: 'Trust our platform worldwide',
            ),
            SizedBox(height: 24),
            PanelFeature(
              icon: Icons.verified_user_outlined,
              title: '99.9% Uptime',
              subtitle: 'Reliable service guarantee',
            ),
            SizedBox(height: 24),
            PanelFeature(
              icon: Icons.trending_up,
              title: '50K+ Users',
              subtitle: 'Active subscribers managed',
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Start your journey',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
      ],
    );
  }
}
