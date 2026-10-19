import 'package:flutter/material.dart';

import '../../data/mock/mock_repository.dart';
import '../../widgets/primary_button.dart';

class _ChildFormEntry {
  final nameController = TextEditingController();
  final classController = TextEditingController();
  String? relation;

  void dispose() {
    nameController.dispose();
    classController.dispose();
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final List<_ChildFormEntry> _children = [_ChildFormEntry()];

  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _addChild() {
    setState(() => _children.add(_ChildFormEntry()));
  }

  void _removeChild(int index) {
    final child = _children.removeAt(index);
    child.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final request = await MockRepository.instance.signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        children: _children
            .map(
              (child) => MockChildLinkRequest(
                name: child.nameController.text.trim(),
                className: child.classController.text.trim(),
                relation: child.relation!,
              ),
            )
            .toList(),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('목업 요청 접수 완료'),
          content: Text(
            '회원가입 요청이 접수되었습니다.\n'
            '자녀 ${request.children.length}명의 연결은 관리자의 승인 대기 중입니다.\n\n'
            '실험용 목업으로, 앱을 종료하면 요청 정보가 사라집니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('목업 회원가입 요청 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '안전한 통학의 시작',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '계정 정보와 자녀 연결 요청을 함께 입력해 주세요.',
                      style: TextStyle(color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: _inputDecoration(
                        label: '이름',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름을 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _inputDecoration(
                        label: '이메일',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return '이메일을 입력해 주세요.';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return '올바른 이메일 주소를 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _inputDecoration(
                        label: '비밀번호',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해 주세요.';
                        }
                        if (value.length < 8) {
                          return '비밀번호는 8자 이상 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordConfirmationController,
                      obscureText: _obscurePasswordConfirmation,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _inputDecoration(
                        label: '비밀번호 확인',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscurePasswordConfirmation
                              ? '비밀번호 표시'
                              : '비밀번호 숨기기',
                          icon: Icon(
                            _obscurePasswordConfirmation
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePasswordConfirmation =
                                  !_obscurePasswordConfirmation;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 한 번 더 입력해 주세요.';
                        }
                        if (value != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '자녀 연결 요청',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addChild,
                          icon: const Icon(Icons.add),
                          label: const Text('자녀 추가'),
                        ),
                      ],
                    ),
                    Text(
                      '입력한 자녀 정보는 관리자가 확인한 뒤 연결됩니다.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_children.length, (index) {
                      final child = _children[index];
                      return Padding(
                        key: ValueKey(child),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '자녀 ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (_children.length > 1)
                                    IconButton(
                                      tooltip: '자녀 삭제',
                                      onPressed: () => _removeChild(index),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: child.nameController,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: '자녀 이름',
                                  icon: Icons.child_care_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '자녀 이름을 입력해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: child.classController,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: '학년 / 반',
                                  icon: Icons.class_outlined,
                                  suffixIcon: const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: Center(
                                      widthFactor: 1,
                                      child: Text('예: 1학년 2반'),
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '학년과 반을 입력해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: child.relation,
                                decoration: _inputDecoration(
                                  label: '자녀와의 관계',
                                  icon: Icons.family_restroom,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '어머니',
                                    child: Text('어머니'),
                                  ),
                                  DropdownMenuItem(
                                    value: '아버지',
                                    child: Text('아버지'),
                                  ),
                                  DropdownMenuItem(
                                    value: '보호자',
                                    child: Text('보호자'),
                                  ),
                                  DropdownMenuItem(
                                    value: '기타',
                                    child: Text('기타'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => child.relation = value);
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return '자녀와의 관계를 선택해 주세요.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: '회원가입 및 연결 요청',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('이미 계정이 있으신가요? 로그인'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
