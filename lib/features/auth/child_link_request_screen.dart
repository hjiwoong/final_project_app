import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ChildLinkRequestScreen extends StatefulWidget {
  const ChildLinkRequestScreen({required this.email, super.key});

  final String email;

  @override
  State<ChildLinkRequestScreen> createState() => _ChildLinkRequestScreenState();
}

class _ChildLinkRequestScreenState extends State<ChildLinkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _children = <_ChildFormEntry>[_ChildFormEntry()];
  bool _loading = false;

  @override
  void dispose() {
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _addChild() => setState(() => _children.add(_ChildFormEntry()));

  void _removeChild(int index) {
    final child = _children.removeAt(index);
    child.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      for (final child in _children) {
        await ApiRepository.instance.addChildRequest(
          email: widget.email,
          name: child.nameController.text.trim(),
          className: child.classController.text.trim(),
          relation: child.relation!,
        );
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SafeArea(
          top: false,
          child: Container(
            margin: AppTheme.sheetMargin,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: AppTheme.sheetDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연결 요청 완료',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '자녀 연결 요청을 접수했습니다. 확인 후 연결됩니다.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage('자녀 연결 요청 실패: ${_errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final response = error.response?.data;
      if (response is Map && response['detail'] != null) {
        return response['detail'].toString();
      }
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자녀 연결 요청'),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '자녀 정보를 추가해 주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '요청은 확인 후 계정에 연결됩니다.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(_children.length, (index) {
                final child = _children[index];
                return Card(
                  key: ValueKey(child),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '자녀 ${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (_children.length > 1)
                              IconButton(
                                onPressed: () => _removeChild(index),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: '자녀 삭제',
                              ),
                          ],
                        ),
                        TextFormField(
                          controller: child.nameController,
                          decoration: _decoration('자녀 이름'),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: child.classController,
                          decoration: _decoration('학년 / 반 (예: 1학년 2반)'),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: child.relation,
                          decoration: _decoration('자녀와의 관계'),
                          items: const [
                            DropdownMenuItem(value: '어머니', child: Text('어머니')),
                            DropdownMenuItem(value: '아버지', child: Text('아버지')),
                            DropdownMenuItem(value: '보호자', child: Text('보호자')),
                            DropdownMenuItem(value: '기타', child: Text('기타')),
                          ],
                          onChanged: (value) =>
                              setState(() => child.relation = value),
                          validator: (value) =>
                              value == null ? '관계를 선택해 주세요.' : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _addChild,
                  icon: const Icon(Icons.add),
                  label: const Text('자녀 추가'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
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
                      : const Text('연결 요청 보내기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? '내용을 입력해 주세요.' : null;

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
  );
}

class _ChildFormEntry {
  final nameController = TextEditingController();
  final classController = TextEditingController();
  String? relation;

  void dispose() {
    nameController.dispose();
    classController.dispose();
  }
}
