import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/user_role.dart';
import 'account_removal_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  bool get _canLogin =>
      _isValidEmail(_emailController.text.trim()) &&
      _passwordController.text.length >= 8 &&
      !_loading;

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_canLogin || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final role = await ApiRepository.instance.login(
        email,
        _passwordController.text,
      );
      Session.role = role;
      Session.email = email;

      if (!mounted) return;
      Navigator.of(context).pop(role);
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? error.response?.data['detail']?.toString() ?? ''
          : '';
      if (error.response?.statusCode == 403 && detail.contains('계정 삭제 유예 중')) {
        try {
          final email = _emailController.text.trim();
          final password = _passwordController.text;
          final schedule = await ApiRepository.instance
              .getAccountDeletionStatus(email: email, password: password);
          if (!mounted) return;
          final role = await Navigator.of(context).push<UserRole>(
            MaterialPageRoute(
              builder: (_) => AccountDeletionPendingScreen(
                email: email,
                password: password,
                schedule: schedule,
              ),
            ),
          );
          if (role != null && mounted) Navigator.of(context).pop(role);
          return;
        } catch (statusError) {
          if (!mounted) return;
          InAppNotificationBanner.showMessage(
            AppErrorMessage.from(
              statusError,
              fallback: '계정 삭제 진행 상태를 확인하지 못했습니다. 다시 시도해 주세요.',
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(
          error,
          fallback: '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.',
          isLogin: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(
          e,
          fallback: '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.',
          isLogin: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPasswordResetInfo() {
    InAppNotificationBanner.showMessage('비밀번호 재설정은 관리자에게 문의해 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '뒤로가기',
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              Text(
                '시작하려면 계정 정보를 입력해주세요',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 26),
              _buildFieldLabel('이메일'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecoration('이메일 주소 입력'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  if (!_isValidEmail(email)) return '올바른 이메일 주소를 입력해 주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 26),
              _buildFieldLabel('비밀번호'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _login(),
                style: const TextStyle(fontSize: 15),
                decoration: _inputDecoration('8자리 이상 입력').copyWith(
                  suffixIcon: _passwordController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (value.length < 8) return '비밀번호는 8자리 이상 입력해 주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '비밀번호를 잊으신 경우 ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showPasswordResetInfo,
                      child: Text(
                        '비밀번호 재설정',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationThickness: 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _canLogin ? _login : null,
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    errorStyle: TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.error,
      height: 1.2,
    ),
    errorMaxLines: 2,
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    focusedErrorBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: 1.5,
      ),
    ),
  );
}
