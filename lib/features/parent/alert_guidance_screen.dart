import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';

class AlertGuidanceScreen extends StatefulWidget {
  const AlertGuidanceScreen({
    super.key,
    required this.alertId,
    this.initialResponse,
  });

  final int alertId;
  final Map<String, dynamic>? initialResponse;

  @override
  State<AlertGuidanceScreen> createState() => _AlertGuidanceScreenState();
}

class _AlertGuidanceScreenState extends State<AlertGuidanceScreen> {
  final _questionController = TextEditingController();
  bool _loading = false;
  String? _answer;
  String? _mode;
  List<Map<String, dynamic>> _sources = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialResponse;
    if (initial != null) {
      _answer = initial['answer'] as String? ?? '';
      _mode = initial['mode'] as String?;
      final sources = initial['sources'];
      _sources = sources is List
          ? sources
                .whereType<Map>()
                .map((source) => Map<String, dynamic>.from(source))
                .toList(growable: false)
          : const [];
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiRepository.instance.askAlertGuidance(
        alertId: widget.alertId,
        question: _questionController.text,
      );
      final sources = response['sources'];
      if (!mounted) return;
      setState(() {
        _answer = response['answer'] as String? ?? '';
        _mode = response['mode'] as String?;
        _sources = sources is List
            ? sources
                  .whereType<Map>()
                  .map((source) => Map<String, dynamic>.from(source))
                  .toList(growable: false)
            : const [];
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMessage.from(
          error,
          fallback: '대응 수칙을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 대응 수칙')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '등록된 안전 수칙을 바탕으로 안내합니다. 자동 답변은 참고용이며, 급한 상황은 학교 또는 운행 담당자에게 직접 연락해 주세요.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _questionController,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _loading ? null : _ask(),
            decoration: InputDecoration(
              labelText: '궁금한 점을 입력하세요',
              hintText: '예: 지금 누구에게 연락해야 하나요?',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _loading ? null : _ask,
                icon: const Icon(Icons.send),
                tooltip: '질문하기',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_answer == null)
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? '안내를 준비하고 있습니다' : '이 경고의 대응 수칙 보기'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: _ask, child: const Text('다시 시도')),
          ],
          if (_answer != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '안내',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(_answer!),
                    if (_mode != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _mode == 'real' ? 'Gemini 기반 답변' : '문서 기반 대체 답변',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '참고 문서',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              for (final source in _sources)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(source['title'] as String? ?? '대응 수칙'),
                    subtitle: Text(source['source'] as String? ?? ''),
                  ),
                ),
            ],
            OutlinedButton.icon(
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.refresh),
              label: const Text('기본 대응 수칙 다시 보기'),
            ),
          ],
        ],
      ),
    );
  }
}
