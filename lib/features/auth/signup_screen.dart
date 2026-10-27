import 'package:flutter/material.dart';

import '../../data/mock/mock_repository.dart';
import 'child_link_request_screen.dart';

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
  bool get _validPassword => _passwordController.text.length >= 8;
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
      await MockRepository.instance.signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        children: const [],
      );
      if (!mounted) return;
      setState(() => _step = 3);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addChildNow() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ChildLinkRequestScreen(email: _emailController.text.trim()),
      ),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자녀 연결 요청을 추가했습니다.')));
    }
  }

  void _finishSignup() => Navigator.of(context).pop();

  void _goBack() {
    if (_step == 0 || _step == 3) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompletion = _step == 3;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: '뒤로가기',
        ),
        //title: Text(isCompletion ? '가입 완료' : ''),
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              if (!isCompletion) ...[
                _ProgressIndicator(step: _step),
                const SizedBox(height: 28),
                Text(
                  _stepTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202329),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stepDescription,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF202329),
                      disabledBackgroundColor: const Color(0xFFCCCCCC),
                      disabledForegroundColor: Colors.white,
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
                      onPressed: _finishSignup,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF202329),
                      ),
                      child: const Text('이미 계정이 있으신가요? 로그인'),
                    ),
                  ),
              ] else
                _buildCompletion(),
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
    1 => '비밀번호는 8자리 이상으로 설정해 주세요.',
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
            decoration: _inputDecoration('8자리 이상 입력').copyWith(
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
              if (value.length < 8) return '비밀번호는 8자리 이상 입력해 주세요.';
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

  Widget _buildCompletion() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      const Icon(
        Icons.check_circle_rounded,
        size: 64,
        color: Color(0xFF22A06B),
      ),
      const SizedBox(height: 20),
      const Text(
        '계정 가입이 완료되었습니다',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Color(0xFF202329),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '${_nameController.text.trim()}님, 환영합니다.\n자녀 연결은 지금 요청하거나 나중에 추가할 수 있어요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(height: 32),
      SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _addChildNow,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF202329),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('자녀 연결 요청 추가'),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: _finishSignup,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF202329),
            side: const BorderSide(color: Color(0xFFD8DADD)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('나중에 하기'),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '자녀 정보는 가입 후에도 홈 화면에서 언제든 추가할 수 있습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ],
  );

  Widget _fieldLabel(String label) => Padding(
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
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF9A9EA4)),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF202329), width: 1.5),
    ),
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE45B37)),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE45B37), width: 1.5),
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
                  ? const Color(0xFF202329)
                  : const Color(0xFFE6E8EB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
