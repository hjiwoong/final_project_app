import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/signup_term.dart';
import '../parent/parent_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.gateway});

  final SignupGateway? gateway;

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
  String? _emailServerError;

  SignupGateway get _gateway => widget.gateway ?? ApiRepository.instance;

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

  Future<void> _openTerms() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = await showModalBottomSheet<_SignupSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignupTermsSheet(
        loadTerms: _gateway.getSignupTerms,
        onSubmit: _submitSignup,
      ),
    );
    if (!mounted) return;
    switch (result) {
      case _SignupSheetAction.success:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ParentShell()),
          (_) => false,
        );
        break;
      case _SignupSheetAction.conflict:
        setState(() {
          _step = 0;
          _emailServerError = '이미 가입된 이메일입니다.';
        });
        _formKey.currentState?.validate();
        break;
      case null:
        break;
    }
  }

  Future<_SignupSubmissionResult> _submitSignup(
    List<SignupTermInfo> terms,
  ) async {
    try {
      await _gateway.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        agreements: terms
            .map(
              (term) =>
                  SignupTermAgreement(type: term.type, version: term.version),
            )
            .toList(),
      );
      return const _SignupSubmissionResult.success();
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final detail = _responseDetail(error);
      if (statusCode == 409) {
        return const _SignupSubmissionResult.conflict();
      }
      if (statusCode == 422) {
        if (detail.contains('필수 약관에 모두 동의해야 가입할 수 있습니다')) {
          try {
            final refreshedTerms = await _gateway.getSignupTerms();
            return _SignupSubmissionResult.validation(
              '$detail\n최신 약관을 다시 불러왔습니다. 다시 가입해 주세요.',
              terms: refreshedTerms,
            );
          } catch (_) {
            return _SignupSubmissionResult.validation(
              '$detail\n약관을 다시 불러오지 못했습니다. 다시 시도해 주세요.',
            );
          }
        }
        return _SignupSubmissionResult.validation(detail);
      }
      return const _SignupSubmissionResult.failure();
    } catch (_) {
      return const _SignupSubmissionResult.failure();
    }
  }

  String _responseDetail(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return '가입 요청을 처리하지 못했습니다.';
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
                  onPressed: !_canContinue
                      ? null
                      : switch (_step) {
                          0 => _nextFromEmail,
                          1 => _nextFromPassword,
                          _ => _openTerms,
                        },
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  child: Text(
                    switch (_step) {
                      2 => '약관 확인',
                      _ => '다음',
                    },
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
    2 => '이름을 입력하세요',
    _ => '이름을 입력하세요',
  };

  String get _stepDescription => switch (_step) {
    0 => '계정에 사용할 이메일 주소를 입력해 주세요.',
    1 => '4자 이상, 영문 대문자와 특수문자를 포함해 주세요.',
    2 => '마지막으로 계정에 표시할 이름을 입력해 주세요.',
    _ => '마지막으로 계정에 표시할 이름을 입력해 주세요.',
  };

  bool get _canContinue => switch (_step) {
    0 => _validEmail,
    1 => _validPassword && _passwordsMatch,
    2 => _nameController.text.trim().isNotEmpty,
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
            onChanged: (_) => setState(() => _emailServerError = null),
            onFieldSubmitted: (_) => _nextFromEmail(),
            decoration: _inputDecoration('이메일 주소 입력'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return null;
              if (_emailServerError != null) return _emailServerError;
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
      case 2:
        return [
          _fieldLabel('이름'),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _openTerms(),
            decoration: _inputDecoration('이름 입력'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null,
          ),
        ];
      default:
        throw StateError('지원하지 않는 회원가입 단계입니다: $_step');
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
            key: ValueKey('signup-progress-segment-$index'),
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

enum _SignupSheetAction { success, conflict }

class _SignupSubmissionResult {
  const _SignupSubmissionResult.success()
    : action = _SignupSheetAction.success,
      message = null,
      terms = null;
  const _SignupSubmissionResult.conflict()
    : action = _SignupSheetAction.conflict,
      message = null,
      terms = null;
  const _SignupSubmissionResult.failure()
    : action = null,
      message = '가입에 실패했습니다. 다시 시도해주세요',
      terms = null;
  const _SignupSubmissionResult.validation(this.message, {this.terms})
    : action = null;

  final _SignupSheetAction? action;
  final String? message;
  final List<SignupTermInfo>? terms;
}

class _SignupTermsSheet extends StatefulWidget {
  const _SignupTermsSheet({required this.loadTerms, required this.onSubmit});

  final Future<List<SignupTermInfo>> Function() loadTerms;
  final Future<_SignupSubmissionResult> Function(List<SignupTermInfo> terms)
  onSubmit;

  @override
  State<_SignupTermsSheet> createState() => _SignupTermsSheetState();
}

class _SignupTermsSheetState extends State<_SignupTermsSheet> {
  List<SignupTermInfo> _terms = const [];
  bool _loadingTerms = true;
  String? _termsError;
  bool _submitting = false;
  String? _signupError;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() {
      _loadingTerms = true;
      _termsError = null;
    });
    try {
      final terms = await widget.loadTerms();
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _loadingTerms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _terms = const [];
        _termsError = '약관을 불러오지 못했습니다';
        _loadingTerms = false;
      });
    }
  }

  Future<void> _confirmSignup() async {
    if (_submitting ||
        _loadingTerms ||
        _termsError != null ||
        _terms.length != 3) {
      return;
    }
    setState(() {
      _submitting = true;
      _signupError = null;
    });
    final result = await widget.onSubmit(_terms);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.action == _SignupSheetAction.success ||
        result.action == _SignupSheetAction.conflict) {
      Navigator.of(context).pop(result.action);
    } else {
      setState(() {
        _signupError = result.message ?? '가입에 실패했습니다. 다시 시도해주세요';
        if (result.terms != null) _terms = result.terms!;
      });
    }
  }

  Future<void> _showTermDetail(SignupTermInfo term) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignupTermDetailSheet(term: term),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: FractionallySizedBox(
        heightFactor: 0.68,
        child: SafeArea(
          top: false,
          child: Container(
            margin: AppTheme.sheetMargin,
            decoration: AppTheme.sheetDecoration(context, radius: 20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '약관 확인',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '가입하면 쿠키 사용을 포함해 이용약관 및 개인정보 처리방침에 동의하게 됩니다.'
                        '이 서비스는 계정을 안전하게 보호하고, 사용자에게 원할한 서비스를 제공하기 위해 개인정보 처리방침에 명시된 목적으로 귀하의 개인정보가 사용될 수 있습니다.'
                        '약관에 동의하지 않으실 수 있지만 거부할 경우 서비스를 이용할 수 없다는 점을 알아두세요.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Expanded(child: _buildTermsList()),
                if (_signupError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      _signupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _submitting ||
                              _loadingTerms ||
                              _termsError != null ||
                              _terms.length != 3
                          ? null
                          : _confirmSignup,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('가입'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsList() {
    if (_loadingTerms) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_termsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _termsError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitting ? null : _loadTerms,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      itemCount: _terms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final term = _terms[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(term.title),
            subtitle: Text('버전 ${term.version}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _submitting ? null : () => _showTermDetail(term),
          ),
        );
      },
    );
  }
}

class _SignupTermDetailSheet extends StatelessWidget {
  const _SignupTermDetailSheet({required this.term});

  final SignupTermInfo term;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          decoration: AppTheme.sheetDecoration(context, radius: 20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '약관 목록으로 돌아가기',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    Expanded(
                      child: Text(
                        term.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '버전 ${term.version}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        term.type.body,
                        style: const TextStyle(fontSize: 15, height: 1.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupTermDetailScreen extends StatelessWidget {
  const SignupTermDetailScreen({super.key, required this.term});

  final SignupTermInfo term;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(term.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '버전 ${term.version}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                term.type.body,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
