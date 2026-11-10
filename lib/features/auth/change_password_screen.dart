import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentPasswordController.text.trim();
    final next = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty) {
      setState(() => _error = '현재 비밀번호를 입력해 주세요.');
      return;
    }

    if (next.length < 8) {
      setState(() => _error = '새 비밀번호는 8자 이상이어야 합니다.');
      return;
    }

    if (next != confirm) {
      setState(() => _error = '새 비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
    );
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(String label, {required bool obscureText, required VoidCallback onToggle}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.grey.shade50,
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '비밀번호를 입력해 주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: _fieldDecoration(
                  '현재 비밀번호',
                  obscureText: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: _fieldDecoration(
                  '새 비밀번호',
                  obscureText: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: _fieldDecoration(
                  '새 비밀번호 확인',
                  obscureText: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호 재설정은 관리자에게 문의해 주세요.')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '비밀번호를 잊으셨나요?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(_saving ? '변경 중...' : '비밀번호 변경'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: const StadiumBorder(),
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
