
import 'package:flutter/material.dart';

// 학부모 앱 정보 화면
class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 정보'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),

          // 서비스 아이콘
          const Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.directions_bus,
                size: 46,
                color: Colors.blue,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 서비스 이름
          const Center(
            child: Text(
              'AI 통학버스 안전관리 서비스',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              '어린이의 안전한 통학을 위한 AI 기반 안전관리',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 서비스 소개
          const Text(
            '서비스 소개',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'AI 통학버스 안전관리 서비스는 차량 내부 카메라와 '
                    'AI 인원 검출 기술을 활용하여 어린이의 승하차 상태를 '
                    '교차 확인하고, 미하차 의심 상황을 감지하는 '
                    '안전관리 서비스입니다.\n\n'
                    '학부모는 앱을 통해 자녀의 승하차 상태, '
                    '차량 운행 현황, 안전 알림 등을 확인할 수 있습니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 주요 기능
          const Text(
            '주요 기능',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.child_care,
                    color: Colors.blue,
                  ),
                  title: Text('자녀 승하차 확인'),
                  subtitle: Text('자녀의 승차 및 하차 상태 확인'),
                ),

                Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                  title: Text('미하차 의심 경고'),
                  subtitle: Text('차량 내 잔류 인원 감지 및 경고'),
                ),

                Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: Colors.green,
                  ),
                  title: Text('버스 운행 현황'),
                  subtitle: Text('차량 위치 및 예상 도착 시간 확인'),
                ),

                Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.event_available,
                    color: Colors.orange,
                  ),
                  title: Text('출석·결석 관리'),
                  subtitle: Text('자녀의 날짜별 등교 및 결석 설정'),
                ),

                Divider(height: 1),

                ListTile(
                  leading: Icon(
                    Icons.assessment_outlined,
                    color: Colors.purple,
                  ),
                  title: Text('운행 리포트'),
                  subtitle: Text('급정거·과속·경로 이탈 현황 확인'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 앱 버전 정보
          const Text(
            '앱 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('서비스 유형'),
                  trailing: Text('학부모용 앱'),
                ),

                Divider(height: 1),

                ListTile(
                  title: Text('개발 상태'),
                  trailing: Text('Mock 테스트'),
                ),

                Divider(height: 1),

                ListTile(
                  title: Text('앱 버전'),
                  trailing: Text('개발 버전'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 테스트 안내
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey,
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      '현재 앱은 프로젝트 개발 및 테스트 단계입니다. '
                          '일부 기능은 Mock 데이터를 사용하며 '
                          '실제 차량 운행 정보와 연결되지 않았습니다.',
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
