import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../data/api/api_repository.dart';

class AlertChatScreen extends StatefulWidget {
  const AlertChatScreen({
    super.key,
    this.alertId,
    this.alertContext,
    this.initialResponse,
  });

  final int? alertId;
  final Map<String, String>? alertContext;
  final Map<String, dynamic>? initialResponse;

  @override
  State<AlertChatScreen> createState() => _AlertChatScreenState();
}

class _AlertChatScreenState extends State<AlertChatScreen> {
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  List<String> _suggestions = const [];
  bool _loading = false;
  bool _cancelRequested = false;
  CancelToken? _activeCancelToken;
  String? _error;
  String? _failedMessage;
  List<Map<String, String>> _failedHistory = const [];
  late int? _activeAlertId;
  late Map<String, String>? _activeAlertContext;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_handleInputFocusChange);
    _activeAlertId = widget.alertId;
    _activeAlertContext = widget.alertContext;
    final initial = widget.initialResponse;
    final answer = initial?['answer'];
    if (answer is String && answer.trim().isNotEmpty) {
      _messages.add(
        _ChatMessage(
          role: 'bot',
          text: answer,
          sources: _readSources(initial?['sources']),
          sourceDate: _readSourceDate(initial),
        ),
      );
      _suggestions = _readSuggestions(initial?['suggestions']);
      _scrollToBottom();
    } else {
      _loadGreeting();
    }
  }

  @override
  void dispose() {
    _activeCancelToken?.cancel();
    _controller.dispose();
    _inputFocusNode
      ..removeListener(_handleInputFocusChange)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInputFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGreeting() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiRepository.instance.getChatGreeting();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'bot',
            text: response['reply'] as String? ?? '',
            formatParagraphs: false,
          ),
        );
        _suggestions = _readSuggestions(response['suggestions']);
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = AppErrorMessage.from(
          error,
          fallback: 'AI 안내를 불러오지 못했습니다. 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startNewChat() async {
    if (_loading) return;
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '새 대화 시작',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text('현재 대화를 제거하고, 새로운 대화를 시작할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (shouldStart != true || !mounted) return;

    _controller.clear();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _messages.clear();
      _suggestions = const [];
      _error = null;
      _failedMessage = null;
      _failedHistory = const [];
      _activeAlertId = null;
      _activeAlertContext = null;
    });
    await _loadGreeting();
  }

  Future<void> _sendMessage([String? suggestion]) async {
    if (_loading) return;
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty) return;

    final history = _messages
        .where((message) => !message.isNotice)
        .map((message) => {'role': message.role, 'text': message.text})
        .toList(growable: false);
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _suggestions = const [];
      _loading = true;
      _error = null;
      _failedMessage = null;
    });
    _scrollToBottom();
    await _requestReply(text, history);
  }

  Future<void> _retryLastMessage() async {
    final message = _failedMessage;
    if (message == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _requestReply(message, _failedHistory);
  }

  void _cancelResponse() {
    final cancelToken = _activeCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) return;
    setState(() => _cancelRequested = true);
    cancelToken.cancel('사용자가 챗봇 답변을 중지했습니다.');
  }

  Future<void> _requestReply(
    String message,
    List<Map<String, String>> history,
  ) async {
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    _cancelRequested = false;
    try {
      final response = await ApiRepository.instance.sendChatMessage(
        message: message,
        history: history,
        alertId: _activeAlertId,
        cancelToken: cancelToken,
      );
      if (!mounted) return;
      setState(() {
        if (_cancelRequested) {
          _appendStopNotice();
        } else {
          _messages.add(
            _ChatMessage(
              role: 'bot',
              text: response['reply'] as String? ?? '안내를 준비하지 못했습니다.',
              sources: _readSources(response['sources']),
              sourceDate: _readSourceDate(response),
            ),
          );
          _suggestions = _readSuggestions(response['suggestions']);
          _failedMessage = null;
        }
      });
      _scrollToBottom();
    } catch (error) {
      if (_cancelRequested) {
        if (mounted) {
          setState(_appendStopNotice);
          _scrollToBottom();
        }
        return;
      }
      if (error is DioException && CancelToken.isCancel(error)) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = AppErrorMessage.from(
          error,
          fallback: '답변을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        );
        _failedMessage = message;
        _failedHistory = history;
      });
    } finally {
      _activeCancelToken = null;
      if (mounted) {
        setState(() {
          _loading = false;
          _cancelRequested = false;
        });
      }
    }
  }

  void _appendStopNotice() {
    if (_messages.isNotEmpty && _messages.last.isNotice) return;
    _messages.add(
      const _ChatMessage(
        role: 'notice',
        text: '사용자가 응답을 중지했습니다.',
        isNotice: true,
      ),
    );
    _suggestions = const [];
  }

  List<Map<String, dynamic>> _readSources(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((source) => Map<String, dynamic>.from(source))
        .toList(growable: false);
  }

  List<String> _readSuggestions(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  ({String label, String value})? _readSourceDate(
    Map<String, dynamic>? response,
  ) {
    if (response == null) return null;
    for (final key in ['as_of', 'effective_at', 'updated_at']) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) {
        final date = DateTime.tryParse(value);
        final displayValue = date == null
            ? value
            : '${date.toLocal().year}.${date.toLocal().month.toString().padLeft(2, '0')}.'
                  '${date.toLocal().day.toString().padLeft(2, '0')}';
        return (
          label: key == 'updated_at' ? '자료 갱신' : '정보 기준',
          value: displayValue,
        );
      }
    }
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('챗봇'),
        actions: [
          IconButton(
            tooltip: '새 채팅',
            onPressed: _loading ? null : _startNewChat,
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.onSecondaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '챗봇을 긴급 용도로 사용하지 마세요.',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_activeAlertContext case final alertContext?)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '연결된 안전 알림${_activeAlertId == null ? '' : ' · #$_activeAlertId'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      ?alertContext['busName'],
                      ?alertContext['detectedAt'],
                      ?alertContext['status'],
                    ].join(' · '),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (alertContext['message'] case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(message, maxLines: 2),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  _messages.length +
                  (_loading ? 1 : 0) +
                  (_error != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  if (_messages[index].isNotice) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: Text(
                          _messages[index].text,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }
                  return _MessageBubble(message: _messages[index]);
                }
                if (_loading && index == _messages.length) {
                  return const _LoadingBubble();
                }
                return _ErrorBubble(
                  message: _error!,
                  onRetry: _failedMessage == null
                      ? _loadGreeting
                      : _retryLastMessage,
                );
              },
            ),
          ),
          if ((_suggestions.isNotEmpty || _messages.isNotEmpty) && !_loading)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.isNotEmpty
                    ? _suggestions.length
                    : _defaultSuggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestions = _suggestions.isNotEmpty
                      ? _suggestions
                      : _defaultSuggestions;
                  return ActionChip(
                    label: Text(suggestions[index]),
                    onPressed: _loading
                        ? null
                        : () => _sendMessage(suggestions[index]),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: _inputFocusNode.hasFocus
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: _inputFocusNode.hasFocus ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canStop = _loading && _activeCancelToken != null;
                    final canCancel = canStop && !_cancelRequested;
                    final canSend = !_loading && value.text.trim().isNotEmpty;
                    final characterCount = value.text.characters.length;
                    final showCharacterCount = characterCount >= 280;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _inputFocusNode,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 500,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: '무엇이든 물어보세요',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: canCancel
                                  ? _cancelResponse
                                  : canSend
                                  ? () => _sendMessage()
                                  : null,
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                canStop ? Icons.stop_rounded : Icons.send,
                              ),
                              tooltip: canStop
                                  ? _cancelRequested
                                        ? '중지 중'
                                        : '답변 중지'
                                  : '전송',
                            ),
                          ],
                        ),
                        if (showCharacterCount)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 8,
                              top: 2,
                              bottom: 2,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$characterCount/500',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: characterCount >= 490
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _defaultSuggestions => _activeAlertId == null
      ? const ['경고 알림은 어떻게 확인하나요?', '자녀 연결은 어떻게 하나요?']
      : const ['지금 무엇을 확인해야 하나요?', '이 알림은 어떤 상황인가요?'];
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.sources = const [],
    this.sourceDate,
    this.formatParagraphs = true,
    this.isNotice = false,
  });

  final String role;
  final String text;
  final List<Map<String, dynamic>> sources;
  final ({String label, String value})? sourceDate;
  final bool formatParagraphs;
  final bool isNotice;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = isUser || !message.formatParagraphs
        ? message.text
        : message.text.replaceAll(RegExp(r'(?<=[.!?。！？])[ \t]+(?=\S)'), '\n\n');
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              displayText,
              textAlign: TextAlign.left,
              style: const TextStyle(height: 1.5),
            ),
            if (message.sources.isNotEmpty || message.sourceDate != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.sources.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          '참고 자료 (${message.sources.length})',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: message.sourceDate == null
                            ? null
                            : Text(
                                '${message.sourceDate?.label}: '
                                '${message.sourceDate?.value}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                        children: [
                          for (final source in message.sources.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source['title'] as String? ?? '안전 안내 자료',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (source['source'] is String &&
                                      (source['source'] as String).isNotEmpty)
                                    Text(
                                      source['source'] as String,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    if (message.sources.isEmpty && message.sourceDate != null)
                      Text(
                        '${message.sourceDate?.label}: '
                        '${message.sourceDate?.value}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('생각 중'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    ),
  );
}
