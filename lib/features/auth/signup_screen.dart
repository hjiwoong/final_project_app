import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';
import '../parent/parent_shell.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _nameController = TextEditingController();

  int _step = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _loading = false;

  bool get _validEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(_emailController.text.trim());
  bool get _validPassword {
    final password = _passwordController.text;
    return password.length >= 4 &&
        utf8.encode(password).length <= 72 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        _hasAsciiPunctuation(password);
  }

  bool _hasAsciiPunctuation(String value) => value.codeUnits.any(
    (code) =>
        (code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126),
  );
  bool get _passwordsMatch =>
      _passwordConfirmationController.text == _passwordController.text;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextFromEmail() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  void _nextFromPassword() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 2);
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await ApiRepository.instance.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ParentShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage('회원가입 실패: ${_errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error) {
    return AppErrorMessage.from(
      error,
      fallback: '회원가입을 완료하지 못했습니다. 입력 정보를 확인하고 다시 시도해 주세요.',
    );
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              _ProgressIndicator(step: _step),
              const SizedBox(height: 28),
              Text(
                _stepTitle,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
              ..._buildCurrentStepFields(),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading || !_canContinue
                      ? null
                      : switch (_step) {
                          0 => _nextFromEmail,
                          1 => _nextFromPassword,
                          _ => _createAccount,
                        },
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
                      : Text(
                          _step == 2 ? '계정 만들기' : '다음',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_step == 0)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('이미 계정이 있으신가요? 로그인'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
    0 => '이메일을 입력하세요',
    1 => '비밀번호를 설정하세요',
    _ => '이름을 입력하세요',
  };

  String get _stepDescription => switch (_step) {
    0 => '계정에 사용할 이메일 주소를 입력해 주세요.',
    1 => '4자 이상, 영문 대문자와 특수문자를 포함해 주세요.',
    _ => '마지막으로 계정에 표시할 이름을 입력해 주세요.',
  };

  bool get _canContinue => switch (_step) {
    0 => _validEmail,
    1 => _validPassword && _passwordsMatch,
    _ => _nameController.text.trim().isNotEmpty,
  };

  List<Widget> _buildCurrentStepFields() {
    switch (_step) {
      case 0:
        return [
          _fieldLabel('이메일'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _nextFromEmail(),
            decoration: _inputDecoration('이메일 주소 입력'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return null;
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return '올바른 이메일 주소를 입력해 주세요.';
              }
              return null;
            },
          ),
        ];
      case 1:
        return [
          _fieldLabel('비밀번호'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('4자 이상 · 대문자 · 특수문자').copyWith(
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              if (value.length < 4) return '비밀번호는 4자리 이상 입력해 주세요.';
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return '영문 대문자를 1개 이상 포함해 주세요.';
              }
              if (!_hasAsciiPunctuation(value)) {
                return '특수문자를 1개 이상 포함해 주세요.';
              }
              if (utf8.encode(value).length > 72) {
                return '비밀번호가 너무 깁니다. (최대 72바이트)';
              }
              return null;
            },
          ),
          if (_validPassword) ...[
            const SizedBox(height: 24),
            _fieldLabel('비밀번호 확인'),
            TextFormField(
              controller: _passwordConfirmationController,
              obscureText: _obscureConfirmation,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _nextFromPassword(),
              decoration: _inputDecoration('비밀번호를 다시 입력해 주세요').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (value != _passwordController.text) {
                  return '비밀번호가 일치하지 않습니다.';
                }
                return null;
              },
            ),
          ],
        ];
      default:
        return [
          _fieldLabel('이름'),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _createAccount(),
            decoration: _inputDecoration('이름 입력'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null,
          ),
        ];
    }
  }

  Widget _fieldLabel(String label) => Padding(
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

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (index) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
            decoration: BoxDecoration(
              color: index <= step
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
