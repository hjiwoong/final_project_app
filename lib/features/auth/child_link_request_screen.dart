import 'package:flutter/material.dart';

import '../../data/mock/mock_repository.dart';

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
      await MockRepository.instance.addChildLinks(
        email: widget.email,
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
          title: const Text('연결 요청 완료'),
          content: const Text('자녀 연결 요청을 접수했습니다. 확인 후 연결됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('자녀 연결 요청 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('자녀 연결 요청'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202329),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                '자녀 정보를 추가해 주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202329),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '요청은 확인 후 계정에 연결됩니다.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ...List.generate(_children.length, (index) {
                final child = _children[index];
                return Card(
                  key: ValueKey(child),
                  color: const Color(0xFFF8F9FA),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE1E3E6)),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF202329),
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
                    foregroundColor: const Color(0xFF202329),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF202329),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE1E3E6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE1E3E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
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
