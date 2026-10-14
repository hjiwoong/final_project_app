import 'package:flutter/material.dart';

/// 경고 상세: LLM 요약 + RAG 대응 수칙
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('경고 상세')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            color: Color(0xFFFEE2E2),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('🚨 미하차 의심 1명',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Text('✨'),
              title: Text('AI 요약'),
              subtitle: Text('종점에서 하차 후 1명이 남아 있을 가능성이 있습니다.'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Text('📄'),
              title: Text('대응 수칙'),
              subtitle: Text('즉시 차량 확인 후 보호자·학교에 연락'),
            ),
          ),
        ],
      ),
    );
  }
}
