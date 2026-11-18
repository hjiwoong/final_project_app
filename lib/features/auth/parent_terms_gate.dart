import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/errors/app_error_message.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/signup_term.dart';
import '../../widgets/logout_confirmation_dialog.dart';

class ParentTermsGate extends StatefulWidget {
  const ParentTermsGate({
    super.key,
    required this.child,
    required this.onLogout,
    this.gateway,
    this.onAccepted,
  });

  final Widget child;
  final Future<void> Function() onLogout;
  final TermsGateway? gateway;
  final VoidCallback? onAccepted;

  @override
  State<ParentTermsGate> createState() => _ParentTermsGateState();
}

class _ParentTermsGateState extends State<ParentTermsGate> {
  TermsGateway get _gateway => widget.gateway ?? ApiRepository.instance;

  final Object _handlerOwner = Object();
  bool _loading = true;
  bool _accepted = false;
  bool _retryBlockedRequest = false;
  String? _error;
  Future<bool>? _activeTermsFlow;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.registerTermsRequiredHandler(
      _handlerOwner,
      _handleTermsRequired,
    );
    _loadInitialTerms();
  }

  @override
  void dispose() {
    ApiClient.instance.unregisterTermsRequiredHandler(_handlerOwner);
    super.dispose();
  }

  Future<void> _loadInitialTerms() async {
    final pending = Session.pendingTerms;
    if (pending.isEmpty) {
      if (!mounted) return;
      setState(() {
        _accepted = true;
        _loading = false;
      });
      widget.onAccepted?.call();
      return;
    }

    await _prepareAndShow(pending);
  }

  Future<bool> _handleTermsRequired(DioException _) {
    final activeFlow = _activeTermsFlow;
    if (activeFlow != null) return activeFlow;

    if (mounted) {
      setState(() {
        _accepted = false;
        _loading = true;
        _retryBlockedRequest = true;
        _error = null;
      });
    }
    late final Future<bool> flow;
    flow = _openTermsForBlockedRequest().whenComplete(() {
      if (identical(_activeTermsFlow, flow)) _activeTermsFlow = null;
    });
    _activeTermsFlow = flow;
    return flow;
  }

  Future<bool> _openTermsForBlockedRequest() async {
    try {
      final pending = await _gateway.getPendingTerms();
      if (pending.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = '약관 확인이 필요하지만 미동의 약관 정보를 찾지 못했습니다.';
          });
        }
        return false;
      }
      return _prepareAndShow(pending);
    } catch (error) {
      if (mounted) {
        setState(() {
          _accepted = false;
          _loading = false;
          _error = AppErrorMessage.from(
            error,
            fallback: '약관 확인이 필요하지만 정보를 불러오지 못했습니다.',
          );
        });
      }
      return false;
    }
  }

  Future<bool> _prepareAndShow(List<SignupTermAgreement> pending) async {
    try {
      final terms = await _gateway.getSignupTerms();
      final history = await _gateway.getMyAgreements();
      if (!mounted) return false;
      final hasPreviousConsent = pending.any(
        (pendingTerm) =>
            history.any((agreement) => agreement.type == pendingTerm.type),
      );
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _ExistingMemberTermsSheet(
          terms: terms,
          pendingTerms: pending,
          termsChanged: hasPreviousConsent,
          onAgree: _saveAgreements,
          onLogout: widget.onLogout,
        ),
      );
      if (accepted == true && mounted) {
        Session.pendingTerms = const [];
        setState(() {
          _accepted = true;
          _loading = false;
          _retryBlockedRequest = false;
          _error = null;
        });
        widget.onAccepted?.call();
        return true;
      }
      return false;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _accepted = false;
        _loading = false;
        _error = AppErrorMessage.from(error, fallback: '약관 정보를 확인하지 못했습니다.');
      });
      return false;
    }
  }

  Future<_TermsSaveResult> _saveAgreements(
    List<SignupTermAgreement> pending,
  ) async {
    try {
      await _gateway.saveAgreements(pending);
      return const _TermsSaveResult.success();
    } on DioException catch (error) {
      if (error.response?.statusCode == 422) {
        return _refreshAfterVersionConflict();
      }
      return _TermsSaveResult.failure(
        AppErrorMessage.from(error, fallback: '동의를 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    } catch (error) {
      return _TermsSaveResult.failure(
        AppErrorMessage.from(error, fallback: '동의를 저장하지 못했습니다. 다시 시도해 주세요.'),
      );
    }
  }

  Future<_TermsSaveResult> _refreshAfterVersionConflict() async {
    try {
      final pending = await _gateway.getPendingTerms();
      final terms = await _gateway.getSignupTerms();
      return _TermsSaveResult.failure(
        '약관이 다시 변경되었습니다',
        terms: terms,
        pendingTerms: pending,
        termsChanged: true,
      );
    } catch (error) {
      return _TermsSaveResult.failure(
        '약관이 다시 변경되었습니다. 최신 약관을 불러오지 못했습니다. 다시 시도해 주세요.',
      );
    }
  }

  Future<void> _logoutFromErrorScreen() async {
    final shouldLogout = await showLogoutConfirmationDialog(context);
    if (shouldLogout && mounted) await widget.onLogout();
  }

  Future<void> _retryTermsLoad() async {
    if (_retryBlockedRequest) {
      setState(() {
        _loading = true;
        _error = null;
      });
      await _openTermsForBlockedRequest();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadInitialTerms();
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error ?? '약관 확인이 필요합니다.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retryTermsLoad,
                        child: const Text('다시 시도'),
                      ),
                      TextButton(
                        onPressed: _logoutFromErrorScreen,
                        child: const Text('동의하지 않고 로그아웃'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TermsSaveResult {
  const _TermsSaveResult.success()
    : message = null,
      terms = null,
      pendingTerms = null,
      termsChanged = false;

  const _TermsSaveResult.failure(
    this.message, {
    this.terms,
    this.pendingTerms,
    this.termsChanged = false,
  });

  final String? message;
  final List<SignupTermInfo>? terms;
  final List<SignupTermAgreement>? pendingTerms;
  final bool termsChanged;
}

class _ExistingMemberTermsSheet extends StatefulWidget {
  const _ExistingMemberTermsSheet({
    required this.terms,
    required this.pendingTerms,
    required this.termsChanged,
    required this.onAgree,
    required this.onLogout,
  });

  final List<SignupTermInfo> terms;
  final List<SignupTermAgreement> pendingTerms;
  final bool termsChanged;
  final Future<_TermsSaveResult> Function(
    List<SignupTermAgreement> pendingTerms,
  )
  onAgree;
  final Future<void> Function() onLogout;

  @override
  State<_ExistingMemberTermsSheet> createState() =>
      _ExistingMemberTermsSheetState();
}

class _ExistingMemberTermsSheetState extends State<_ExistingMemberTermsSheet> {
  late List<SignupTermInfo> _terms = widget.terms;
  late List<SignupTermAgreement> _pendingTerms = widget.pendingTerms;
  late bool _termsChanged = widget.termsChanged;
  final Set<SignupTermType> _readTerms = {};
  bool _loading = false;
  String? _error;

  Future<void> _agree() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.onAgree(_pendingTerms);
    if (!mounted) return;
    if (result.message == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _loading = false;
      _error = result.message;
      if (result.terms != null) _terms = result.terms!;
      if (result.pendingTerms != null) {
        _pendingTerms = result.pendingTerms!;
      }
      _termsChanged = result.termsChanged || _termsChanged;
    });
  }

  Future<void> _logout() async {
    if (_loading) return;
    final shouldLogout = await showLogoutConfirmationDialog(context);
    if (!shouldLogout || !mounted) return;
    Navigator.of(context).pop(false);
    await widget.onLogout();
  }

  Future<void> _showTermDetail(SignupTermInfo term) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExistingMemberTermDetailSheet(term: term),
    );
    if (mounted) setState(() => _readTerms.add(term.type));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            margin: AppTheme.sheetMargin,
            decoration: AppTheme.sheetDecoration(context, radius: 20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '약관 확인',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _termsChanged
                            ? '약관이 변경되어 다시 동의가 필요해요.'
                            : '서비스 이용을 위해 아래 약관을 확인해 주세요.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Flexible(fit: FlexFit.loose, child: _termsList()),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    '계속하면 위 약관에 모두 동의한 것으로 처리됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _agree,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('동의하고 계속하기'),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _logout,
                  child: const Text('동의하지 않고 로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _termsList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      itemCount: _terms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final term = _terms[index];
        final isPending = _pendingTerms.any(
          (pending) => pending.type == term.type,
        );
        final isRead = _readTerms.contains(term.type);
        final version = term.version.replaceAll('-', '.');
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${term.required ? '(필수)' : '(선택)'} ${term.title}',
                  ),
                ),
                if (_termsChanged && isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '변경됨',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$version 시행',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            trailing: Icon(
              isRead ? Icons.check_rounded : Icons.chevron_right_rounded,
            ),
            onTap: _loading ? null : () => _showTermDetail(term),
          ),
        );
      },
    );
  }
}

class _ExistingMemberTermDetailSheet extends StatelessWidget {
  const _ExistingMemberTermDetailSheet({required this.term});

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
                        '${term.version.replaceAll('-', '.')} 시행',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
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
