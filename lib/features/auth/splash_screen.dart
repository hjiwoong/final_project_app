import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// 로딩 화면: 크림색 단색 배경 가운데에 버스만.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// 로딩이 끝나면 호출 (자동 로그인 확인 후 화면 이동 등)
  final VoidCallback onFinished;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Center(
        child: Image.asset(
          'assets/images/splash_bus.png',
          width: 180, // 버스 크기
          height: 180,
          semanticLabel: '통학이',
        ),
      ),
    );
  }
}
