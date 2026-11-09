import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/config/env.dart';
import 'alert_mock_store.dart';

// 학부모 미하차 경고 내역 화면
// 실제 경고 내역 API 연동 전에는 기존 Mock 경고 상태만 표시합니다.
class MissedDropoffAlertScreen extends StatelessWidget {
  const MissedDropoffAlertScreen({super.key});

  bool get _isMockMode => Env.useMock || Session.isMockAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('미하차 경고 내역'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isMockMode
            ? ValueListenableBuilder<bool>(
                valueListenable: AlertMockStore.hasAlert,
                builder: (context, hasAlert, child) {
                  if (!hasAlert) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('현재 테스트 경고가 없습니다.'),
                          SizedBox(height: 8),
                          Text('홈 화면에서 미하차 경고 발생 테스트를 실행해 보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      Card(
                        color: const Color(0xFFFFF4F4),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFE05252)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('미하차 의심 경고 (테스트)',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('대상 차량: 1호차'),
                              const SizedBox(height: 8),
                              const Text('가정된 잔류 인원: 1명'),
                              const SizedBox(height: 8),
                              const Text('확인 상태: 관리자 확인 필요'),
                              const SizedBox(height: 12),
                              const Text(
                                '이 경고는 테스트 데이터입니다. 실제 AI 감지 결과가 아닙니다.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : const Center(
                child: Text(
                  '실제 미하차 경고 내역 API는 아직 연결되지 않았습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
      ),
    );
  }
}
