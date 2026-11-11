import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';

import '../../core/notifications/in_app_notification_banner.dart';

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
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty) {
      setState(() => _error = '현재 비밀번호를 입력해 주세요.');
      return;
    }

    if (next.length < 8) {
      setState(() => _error = '새 비밀번호는 8자 이상이어야 합니다.');
      return;
    }

    const punctuation = r"""!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~""";
    if (!RegExp(r'[A-Z]').hasMatch(next) ||
        !next.split('').any(punctuation.contains)) {
      setState(() => _error = '새 비밀번호에 영문 대문자와 특수문자를 포함해 주세요.');
      return;
    }

    if (utf8.encode(next).length > 72) {
      setState(() => _error = '새 비밀번호가 너무 깁니다. (최대 72바이트)');
      return;
    }

    if (next == current) {
      setState(() => _error = '새 비밀번호는 현재 비밀번호와 달라야 합니다.');
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

    try {
      await ApiRepository.instance.changePassword(
        currentPassword: current,
        newPassword: next,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = (error.response?.data is Map)
          ? (error.response?.data['detail']?.toString() ?? '')
          : '';
      setState(() {
        _error = switch (error.response?.statusCode) {
          400 => '새 비밀번호는 현재 비밀번호와 달라야 합니다.',
          401 when detail.contains('현재 비밀번호') => '현재 비밀번호가 올바르지 않습니다.',
          401 => '로그인이 만료되었습니다. 다시 로그인해 주세요.',
          403 => '이 계정은 비밀번호 변경을 사용할 수 없습니다.',
          422 => '새 비밀번호는 4자 이상이며 영문 대문자와 특수문자를 포함해야 합니다.',
          _ => '비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        };
        _saving = false;
      });
      return;
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.';
        _saving = false;
      });
      return;
    }

    if (!mounted) return;

    setState(() => _saving = false);
    InAppNotificationBanner.showMessage('비밀번호가 변경되었습니다.');
    Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(
    String label, {
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: colorScheme.onSurfaceVariant,
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
              Text(
                '비밀번호를 입력해 주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: _fieldDecoration(
                  '현재 비밀번호',
                  obscureText: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
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
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    InAppNotificationBanner.showMessage(
                      '비밀번호 재설정은 관리자에게 문의해 주세요.',
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '비밀번호를 잊으셨나요?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
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
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
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
