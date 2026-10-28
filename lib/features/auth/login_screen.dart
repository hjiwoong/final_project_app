import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/env.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/user_role.dart';
import '../driver/driver_shell.dart';
import '../parent/parent_shell.dart';
import 'email_login_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;



  Future<UserRole?> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      if (Env.googleServerClientId.isEmpty) {
        throw StateError('Google 웹 클라이언트 ID를 GOOGLE_SERVER_CLIENT_ID로 설정하세요.');
      }

      final googleSignIn = GoogleSignIn(
        serverClientId: Env.googleServerClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) return null;

      final idToken = (await account.authentication).idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google ID 토큰을 받지 못했습니다. OAuth 설정을 확인하세요.');
      }

      return await ApiRepository.instance.loginWithGoogle(idToken);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google 로그인을 실패했습니다.: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLoginOptions() async {
    final result = await showModalBottomSheet<_LoginSheetResult>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LoginOptionsSheet(
        loading: _loading,
        onGoogleLogin: () async {
          final role = await _loginWithGoogle();
          if (role != null && sheetContext.mounted) {
            Navigator.of(sheetContext).pop(_resultFor(role));
          }
        },
        onEmailLogin: () =>
            Navigator.of(sheetContext).pop(_LoginSheetResult.email),
      ),
    );
    if (!mounted || result == null) return;
    if (result == _LoginSheetResult.email) {
      final role = await Navigator.of(context).push<UserRole>(
        MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
      );
      if (!mounted || role == null) return;
      _navigateToRole(role);
    } else {
      _navigateToRole(
        result == _LoginSheetResult.driver ? UserRole.driver : UserRole.parent,
      );
    }
  }

  _LoginSheetResult _resultFor(UserRole role) => role == UserRole.driver
      ? _LoginSheetResult.driver
      : _LoginSheetResult.parent;

  void _navigateToRole(UserRole role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            role == UserRole.driver ? const DriverShell() : const ParentShell(),
      ),
    );
  }

  void _showSignUp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const _BusIllustration(),
                        const SizedBox(height: 28),
                        Text(
                          '안전한 통학의 시작',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF202329),
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '아이들의 등하굣길을 함께 지켜요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _showLoginOptions,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF202329),
                          side: const BorderSide(color: Color(0xFFD8DADD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '로그인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _showSignUp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF202329),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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

class _BusIllustration extends StatelessWidget {
  const _BusIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 218,
            height: 218,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F6FF),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 24,
            left: 20,
            child: _decorationDot(const Color(0xFFFFD66B), 18),
          ),
          Positioned(
            top: 43,
            right: 22,
            child: _decorationDot(const Color(0xFFB7D7FF), 12),
          ),
          Positioned(
            bottom: 30,
            left: 28,
            child: _decorationDot(const Color(0xFFBFE8D1), 13),
          ),
          Positioned(
            top: 42,
            right: 55,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF3B82F6),
                size: 30,
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: 35,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFBD3D),
                size: 23,
              ),
            ),
          ),
          Positioned(
            top: 90,
            child: Container(
              width: 178,
              height: 106,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC94A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF202329), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F202329),
                    offset: Offset(0, 7),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SizedBox(width: 13),
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF4FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF202329),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: Color(0xFF202329),
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 45,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF202329),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            size: 17,
                            color: Color(0xFF202329),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                  Container(
                    height: 27,
                    decoration: const BoxDecoration(
                      color: Color(0xFF202329),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_Wheel(), SizedBox(width: 74), _Wheel()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            child: Container(
              width: 150,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFB7D7FF),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorationDot(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Wheel extends StatelessWidget {
  const _Wheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: const Color(0xFF202329),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
    );
  }
}

enum _LoginSheetResult { email, driver, parent }

class _LoginOptionsSheet extends StatelessWidget {
  const _LoginOptionsSheet({
    required this.loading,
    required this.onGoogleLogin,
    required this.onEmailLogin,
  });

  final bool loading;
  final Future<void> Function() onGoogleLogin;
  final VoidCallback onEmailLogin;

  @override
  Widget build(BuildContext context) {
    return _SheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            '로그인 방법 선택',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onGoogleLogin,
              icon: const FaIcon(
                FontAwesomeIcons.google,
                size: 18,
                color: Color(0xFF000000),
              ),
              label: const Text(
                'Google 계정으로 계속하기',
                style: TextStyle(
                  color: Color(0xFF202329),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE1E3E6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: TextButton.icon(
              onPressed: loading ? null : onEmailLogin,
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('이메일로 로그인'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF343A40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE1E3E6)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: child,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD9DDE2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
