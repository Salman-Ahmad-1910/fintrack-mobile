import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../theme/app_theme.dart';
import '../../theme/tailwind.dart';
import 'auth_ui.dart';

/// Port of `client/src/app/forgot-password/page.tsx`: request a 6-digit OTP
/// by email (`POST /auth/forgot-password`), then set a new password with it
/// (`POST /auth/reset-password` → `{email, otp, password}`).
///
/// Unlike the web page, the "dev mode" OTP the server echoes back when SMTP is
/// not configured is deliberately never shown: displaying it would let anyone
/// reset any account's password from the app.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static const routeName = '/forgot-password';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, reset }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _obscure = true;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _otpPattern = RegExp(r'^\d{6}$');

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ApiConfig.resolve();
      await ApiClient().post(
        '/auth/forgot-password',
        body: {'email': _email.text.trim()},
      );
      if (!mounted) return;
      setState(() => _step = _Step.reset);
      await showMessageDialog(
        context,
        isError: false,
        title: 'Check Your Email',
        message:
            'If this email is registered, a password reset OTP has been sent '
            'to your inbox.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: 'Request Failed',
        message: e.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_resetForm.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ApiClient().post(
        '/auth/reset-password',
        body: {
          'email': _email.text.trim(),
          'otp': _otp.text.trim(),
          'password': _password.text,
        },
      );
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: false,
        title: 'Password Reset Successful',
        message:
            'Your password has been reset. Please sign in with your new '
            'password.',
        confirmLabel: 'Go to Sign In',
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showMessageDialog(
        context,
        isError: true,
        title: 'Reset Failed',
        message: e.message,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = _step == _Step.email;
    return AuthShell(
      panel: const _ForgotPanel(),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackToHomeLink(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 16),
          AuthCard(
            title: isEmail ? 'Forgot Password' : 'Reset Password',
            description: isEmail
                ? 'Enter your account email and we will send you a 6-digit '
                      'OTP to reset your password.'
                : 'Enter the OTP sent to ${_email.text.trim()} and choose a '
                      'new password.',
            child: isEmail ? _emailStep() : _resetStep(),
          ),
        ],
      ),
    );
  }

  Widget _emailStep() {
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Email',
            controller: _email,
            hint: 'Enter your registered email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _requestOtp(),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Email is required';
              if (!_emailPattern.hasMatch(value)) {
                return 'Invalid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'Send OTP',
            loadingLabel: 'Sending...',
            loading: _loading,
            onPressed: _loading ? null : _requestOtp,
          ),
        ],
      ),
    );
  }

  Widget _resetStep() {
    return Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'OTP Code',
            controller: _otp,
            hint: '6-digit code',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            validator: (v) => _otpPattern.hasMatch((v ?? '').trim())
                ? null
                : 'Please enter the 6-digit code sent to your email.',
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'New Password',
            controller: _password,
            hint: 'At least 6 characters',
            obscure: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) => (v ?? '').length < 6
                ? 'Password must be at least 6 characters long.'
                : null,
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
          AuthField(
            label: 'Confirm Password',
            controller: _confirm,
            hint: 'Re-enter the new password',
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
            validator: (v) => v != _password.text
                ? 'Please make sure both password fields match.'
                : null,
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'Reset Password',
            loadingLabel: 'Resetting...',
            loading: _loading,
            onPressed: _loading ? null : _resetPassword,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _step = _Step.email;
                      _otp.clear();
                    }),
              child: const Text(
                "Didn't receive the code? Send again",
                style: TextStyle(fontSize: 13, color: Tw.gray600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgotPanel extends StatelessWidget {
  const _ForgotPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.lock_reset_outlined, size: 56, color: Colors.white),
        SizedBox(height: 16),
        Text(
          "We'll send a secure OTP to your email so you can set a new "
          'password in minutes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
        ),
      ],
    );
  }
}
