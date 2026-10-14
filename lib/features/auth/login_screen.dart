import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/mock/mock_repository.dart';
import '../../data/models/user_role.dart';
import '../../widgets/primary_button.dart';
import '../driver/trip_start_screen.dart';
import '../parent/parent_shell.dart';

/// 공용 로그인. role 에 따라 관리자 / 학부모 화면으로 분기
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'driver@school.kr');
  final _password = TextEditingController(text: '1234');
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final role = await MockRepository.instance.login(_email.text, _password.text);
    Session.role = role;
    Session.email = _email.text;
    if (!mounted) return;
    setState(() => _loading = false);

    final Widget next = role == UserRole.driver ? const TripStartScreen() : const ParentShell();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚌', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text('통학버스 안전', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: '로그인', loading: _loading, onPressed: _login),
              const SizedBox(height: 12),
              const Text(
                '테스트: 이메일에 parent 가 들어가면 학부모 화면 (예: parent@school.kr)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
