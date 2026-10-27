import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPasswordResetInfo() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정은 관리자에게 문의해 주세요.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '뒤로가기',
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202329),
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
              const Text(
                '시작하려면 계정 정보를 입력해주세요',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202329),
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
                            color: const Color(0xFF858B93),
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
                        color: Colors.grey.shade700,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showPasswordResetInfo,
                      child: const Text(
                        '비밀번호 재설정',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF202329),
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
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    disabledForegroundColor: Colors.white,
                    backgroundColor: const Color(0xFF202329),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
      style: const TextStyle(fontSize: 12, color: Color(0xFF858B93)),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9A9EA4)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    errorStyle: const TextStyle(
      fontSize: 11,
      color: Color(0xFFE45B37),
      height: 1.2,
    ),
    errorMaxLines: 2,
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF9A9EA4), width: 1),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF202329), width: 1.5),
    ),
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE45B37), width: 1),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE45B37), width: 1.5),
    ),
  );
}
