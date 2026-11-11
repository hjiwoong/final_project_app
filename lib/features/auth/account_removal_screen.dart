import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/account_deletion_schedule.dart';
import '../../data/models/user_role.dart';
import '../auth/login_screen.dart';

class AccountDeletionPendingScreen extends StatefulWidget {
  const AccountDeletionPendingScreen({
    super.key,
    required this.email,
    required this.schedule,
    this.password,
    this.googleIdToken,
  });

  final String email;
  final String? password;
  final String? googleIdToken;
  final AccountDeletionSchedule schedule;

  @override
  State<AccountDeletionPendingScreen> createState() =>
      _AccountDeletionPendingScreenState();
}

class _AccountDeletionPendingScreenState
    extends State<AccountDeletionPendingScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _cancelDeletion() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await ApiRepository.instance.cancelAccountDeletion(
        email: widget.email,
        password: widget.password,
        googleIdToken: widget.googleIdToken,
      );
      if (mounted) Navigator.of(context).pop(role);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (error.response?.statusCode) {
          401 => '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
          403 => '학부모 계정만 삭제를 취소할 수 있습니다.',
          409 => '취소할 삭제 예약이 없습니다.',
          410 => '삭제 유예 기간이 끝나 계정을 복구할 수 없습니다.',
          _ => '삭제 취소에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '삭제 취소에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}년 ${local.month}월 ${local.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.schedule.remainingDays;
    final progress = (1 - remaining / widget.schedule.gracePeriodDays).clamp(
      0.0,
      1.0,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 56,
              color: AppTheme.danger,
            ),
            const SizedBox(height: 20),
            Text(
              '계정 삭제까지 $remaining일 남았습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '삭제 요청일 ${_formatDate(widget.schedule.requestedAt)} · '
              '삭제 예정일 ${_formatDate(widget.schedule.scheduledDeletionAt)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 20),
            const Text(
              '삭제를 취소하면 계정을 계속 사용할 수 있습니다. 삭제 예정일이 지나면 계정과 관련 정보가 영구 삭제됩니다.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _cancelDeletion,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('계정 삭제 취소'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _loading ? null : _logout,
                child: const Text('로그아웃'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountRemovalScreen extends StatelessWidget {
  const AccountRemovalScreen({super.key});

  bool get _canDeleteAccount =>
      Session.accountRole?.toUpperCase() == 'PARENT' ||
      Session.role == UserRole.parent;

  String _roleLabel() {
    final code = Session.accountRole?.toUpperCase();
    return switch (code) {
      'ADMIN' => '관리자',
      'DRIVER' => '기사',
      'PARENT' => '학부모',
      _ => switch (Session.role) {
        UserRole.driver => '기사',
        UserRole.parent => '학부모',
        null => '정보 없음',
      },
    };
  }

  Future<void> _removeAccount(BuildContext context) async {
    final credential = await showModalBottomSheet<_AccountDeletionCredential>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const _AccountDeletionReauthenticationSheet(),
      ),
    );
    if (credential == null || !context.mounted) return;

    final deleted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountDeletionDecisionSheet(credential: credential),
    );
    if (deleted != true || !context.mounted) return;

    await Session.clear();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text('계정 삭제')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '다음 계정을 삭제하려고 합니다.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: isDark ? Colors.black : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: foregroundColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: foregroundColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.name?.isNotEmpty == true
                              ? Session.name!
                              : '사용자',
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Session.email?.isNotEmpty == true
                              ? Session.email!
                              : '이메일 정보 없음',
                          style: TextStyle(
                            color: foregroundColor.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: foregroundColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _roleLabel(),
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded),
              SizedBox(width: 8),
              Text(
                '계정 삭제 시 참고 사항',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '계정 삭제를 요청하면 즉시 로그아웃됩니다. 계정은 30일 후 영구 삭제되며, 계정 삭제 프로세스가 진행되는 중에 다시 로그인하면 프로세스를 취소할 수 있습니다.'
            '\n\n영구적으로 삭제된 후에는 이 계정으로 로그인할 수 없습니다.'
            '\n\n계정과 함께 저장된 주소 및 위치 정보를 비롯해 자녀 정보 또한 전부 삭제됩니다.'
            '\n\n서비스를 계속 이용하려면 계정 삭제 프로세스를 취소하시기 바랍니다.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          if (!_canDeleteAccount) ...[
            const SizedBox(height: 12),
            Text(
              '계정 삭제는 학부모 계정에서만 요청할 수 있습니다.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _canDeleteAccount ? () => _removeAccount(context) : null,
            icon: const Icon(Icons.person_remove_alt_1_rounded),
            label: const Text(
              '계정 삭제',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDeletionCredential {
  const _AccountDeletionCredential.password(String password)
    : currentPassword = password,
      googleIdToken = null;

  const _AccountDeletionCredential.google(String idToken)
    : currentPassword = null,
      googleIdToken = idToken;

  final String? currentPassword;
  final String? googleIdToken;
}

class _AccountDeletionReauthenticationSheet extends StatefulWidget {
  const _AccountDeletionReauthenticationSheet();

  @override
  State<_AccountDeletionReauthenticationSheet> createState() =>
      _AccountDeletionReauthenticationSheetState();
}

class _AccountDeletionReauthenticationSheetState
    extends State<_AccountDeletionReauthenticationSheet> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '현재 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiRepository.instance.verifyAccountPassword(password);
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(
          context,
        ).pop(_AccountDeletionCredential.password(password));
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.response?.statusCode == 401
            ? '현재 비밀번호가 일치하지 않습니다.'
            : '비밀번호를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '비밀번호 확인에 실패했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (Env.googleServerClientId.isEmpty) {
        throw StateError('Google 웹 클라이언트 ID를 설정해 주세요.');
      }
      final account = await GoogleSignIn(
        serverClientId: Env.googleServerClientId,
      ).signIn();
      if (account == null) return;
      if (account.email.toLowerCase() != Session.email?.toLowerCase()) {
        throw StateError('현재 로그인된 계정과 같은 Google 계정으로 인증해 주세요.');
      }
      final idToken = (await account.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google 인증 토큰을 받지 못했습니다. 다시 시도해 주세요.');
      }
      if (mounted) {
        Navigator.of(context).pop(_AccountDeletionCredential.google(idToken));
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google 계정 인증에 실패했습니다. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '계정 삭제 요청',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '비밀번호를 입력하거나 Google 계정으로 다시 인증해 주세요.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_loading,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: '현재 비밀번호',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loading ? null : _submitWithGoogle,
                icon: const FaIcon(FontAwesomeIcons.google),
                label: const Text('Google 계정으로 재인증하기'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
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
                            : const Text('계속'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDeletionDecisionSheet extends StatefulWidget {
  const _AccountDeletionDecisionSheet({required this.credential});

  final _AccountDeletionCredential credential;

  @override
  State<_AccountDeletionDecisionSheet> createState() =>
      _AccountDeletionDecisionSheetState();
}

class _AccountDeletionDecisionSheetState
    extends State<_AccountDeletionDecisionSheet> {
  bool _loading = false;
  String? _error;
  AccountDeletionSchedule? _schedule;

  Future<void> _requestDeletion() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schedule = await ApiRepository.instance.requestAccountDeletion(
        currentPassword: widget.credential.currentPassword,
        googleIdToken: widget.credential.googleIdToken,
      );
      if (mounted) setState(() => _schedule = schedule);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.response?.statusCode) {
          401 => '인증 정보가 올바르지 않거나 연결된 Google 계정이 아닙니다.',
          403 => '학부모 계정만 삭제를 요청할 수 있습니다.',
          409 => '이미 계정 삭제가 예약되어 있습니다.',
          _ => '계정 삭제 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        };
      });
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '계정 삭제 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}년 ${local.month}월 ${local.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                schedule == null ? '계속할까요?' : '삭제 요청 완료되었습니다',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                schedule == null
                    ? '요청 즉시 로그아웃되며 30일 후 계정이 영구 삭제됩니다. '
                          '삭제 대기 중 다시 로그인하면 삭제를 취소할 수 있습니다.'
                    : '요청일: ${_formatDate(schedule.requestedAt)}\n'
                          '영구 삭제 예정일: ${_formatDate(schedule.scheduledDeletionAt)}\n\n'
                          '그동안 이용해 주셔서 감사합니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  if (schedule == null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('돌아가기'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading
                            ? null
                            : schedule == null
                            ? _requestDeletion
                            : () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: schedule == null
                              ? AppTheme.danger
                              : null,
                          shape: const StadiumBorder(),
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
                            : Text(schedule == null ? '계정 삭제 요청' : '로그아웃'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
