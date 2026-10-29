
import 'package:flutter/material.dart';

import 'bus_trip_mock_store.dart';

// 학부모 버스 운행 현황 (Mock 데이터)
class BusStatusScreen extends StatelessWidget {
  const BusStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('버스 운행 현황'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 버스 운행 상태 (Mock)
          ValueListenableBuilder<BusTripStatus>(
            valueListenable: BusTripMockStore.status,
            builder: (context, status, child) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.directions_bus,
                    size: 32,
                  ),
                  title: const Text('1호차'),
                  subtitle: const Text('차량번호: 12가3456'),
                  trailing: Chip(
                    label: Text(
                      BusTripMockStore.getStatusText(status),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '현재 차량 위치',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 버스 위치에 따라 변경되는 Mock 지도
          ValueListenableBuilder<double>(
            valueListenable: BusTripMockStore.progress,
            builder: (context, progress, child) {
              return _MockBusMap(progress: progress);
            },
          ),

          const SizedBox(height: 16),

          // 예상 도착 시간 (Mock)
          ValueListenableBuilder<double>(
            valueListenable: BusTripMockStore.progress,
            builder: (context, progress, child) {
              return ValueListenableBuilder<BusTripStatus>(
                valueListenable: BusTripMockStore.status,
                builder: (context, status, child) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blue,
                      ),
                      title: const Text('예상 도착 시간'),
                      subtitle: const Text('학교 도착까지'),
                      trailing: Text(
                        BusTripMockStore.getEtaText(status),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '운행 진행 상황',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // 운행 진행 상황 (Mock)
          ValueListenableBuilder<BusTripStatus>(
            valueListenable: BusTripMockStore.status,
            builder: (context, status, child) {
              final hasStarted = status != BusTripStatus.before;
              final isRunning = status == BusTripStatus.running;
              final isFinished = status == BusTripStatus.finished;

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        hasStarted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: hasStarted
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: const Text('운행 시작'),
                      subtitle: Text(
                        hasStarted
                            ? '오전 8:10 (Mock)'
                            : '운행 시작 대기',
                      ),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: Icon(
                        isRunning
                            ? Icons.directions_bus
                            : isFinished
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isRunning
                            ? Colors.blue
                            : isFinished
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(
                        isFinished ? '운행 완료' : '현재 운행 중',
                      ),
                      subtitle: Text(
                        isRunning
                            ? '학교로 이동 중'
                            : isFinished
                            ? '운행이 종료되었습니다'
                            : '운행 시작 대기',
                      ),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: Icon(
                        isFinished
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isFinished
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: const Text('학교 도착'),
                      subtitle: Text(
                        isFinished
                            ? '도착 완료 (Mock)'
                            : '도착 대기',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 운행 상태 및 버스 위치 변경 버튼 (Mock)
          ValueListenableBuilder<BusTripStatus>(
            valueListenable: BusTripMockStore.status,
            builder: (context, status, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == BusTripStatus.before)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.startTrip,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('운행 시작 테스트'),
                    ),

                  if (status == BusTripStatus.running)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.moveBus,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('버스 위치 이동 테스트'),
                    ),

                  if (status == BusTripStatus.running)
                    const SizedBox(height: 8),

                  if (status == BusTripStatus.running)
                    ElevatedButton.icon(
                      onPressed: BusTripMockStore.finishTrip,
                      icon: const Icon(Icons.stop),
                      label: const Text('운행 종료 테스트'),
                    ),

                  const SizedBox(height: 8),

                  OutlinedButton(
                    onPressed: BusTripMockStore.resetTrip,
                    child: const Text('운행 상태 초기화'),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          const Text(
            '※ 현재 표시되는 차량 위치와 도착 시간은 테스트 데이터입니다.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// 서버 연결 없이 표시하는 버스 운행 경로 예시
class _MockBusMap extends StatelessWidget {
  final double progress;

  const _MockBusMap({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // 기존 Mock 경로를 따라 버스 이동
          final points = [
            Offset(width * 0.15, height * 0.78),
            Offset(width * 0.35, height * 0.78),
            Offset(width * 0.35, height * 0.50),
            Offset(width * 0.75, height * 0.50),
            Offset(width * 0.75, height * 0.22),
            Offset(width * 0.85, height * 0.22),
          ];

          final lengths = <double>[];
          double totalLength = 0;

          for (int i = 0; i < points.length - 1; i++) {
            final length =
                (points[i + 1] - points[i]).distance;

            lengths.add(length);
            totalLength += length;
          }

          double remaining =
              progress.clamp(0.0, 1.0).toDouble() *
                  totalLength;

          Offset busPosition = points.last;

          for (int i = 0; i < lengths.length; i++) {
            if (remaining <= lengths[i]) {
              final ratio = remaining / lengths[i];

              busPosition = Offset.lerp(
                points[i],
                points[i + 1],
                ratio,
              )!;

              break;
            }

            remaining -= lengths[i];
          }

          return Stack(
            children: [
              // 지도 배경 및 이동 경로
              Positioned.fill(
                child: CustomPaint(
                  painter: _BusRoutePainter(),
                ),
              ),

              // 출발지
              const Positioned(
                left: 18,
                bottom: 16,
                child: _MapMarker(
                  icon: Icons.home,
                  label: '출발지',
                  color: Colors.green,
                ),
              ),

              // 도착지
              const Positioned(
                right: 18,
                top: 16,
                child: _MapMarker(
                  icon: Icons.school,
                  label: '학교',
                  color: Colors.deepOrange,
                ),
              ),

              // 현재 버스 위치
              Positioned(
                left: (busPosition.dx - 55)
                    .clamp(0.0, width - 110)
                    .toDouble(),
                top: (busPosition.dy - 24)
                    .clamp(0.0, height - 70)
                    .toDouble(),
                child: const SizedBox(
                  width: 110,
                  child: _MapMarker(
                    icon: Icons.directions_bus,
                    label: '현재 버스 위치',
                    color: Colors.blue,
                  ),
                ),
              ),

              const Positioned(
                right: 10,
                bottom: 10,
                child: Text(
                  'Mock 경로',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 지도 위의 위치 표시
class _MapMarker extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MapMarker({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: color,
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),

        const SizedBox(height: 4),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// 지도 배경 도로와 버스 이동 경로 그리기
class _BusRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 도로 스타일
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;

    // 가로 도로 1
    final road1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width, size.height * 0.3);

    // 가로 도로 2
    final road2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.7);

    // 세로 도로 1
    final road3 = Path()
      ..moveTo(size.width * 0.35, 0)
      ..lineTo(size.width * 0.35, size.height);

    // 세로 도로 2
    final road4 = Path()
      ..moveTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.75, size.height);

    // 도로 그리기
    canvas.drawPath(road1, roadPaint);
    canvas.drawPath(road2, roadPaint);
    canvas.drawPath(road3, roadPaint);
    canvas.drawPath(road4, roadPaint);

    // 버스 이동 경로 스타일
    final routePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 출발지에서 학교까지의 Mock 경로
    final route = Path()
      ..moveTo(size.width * 0.15, size.height * 0.78)
      ..lineTo(size.width * 0.35, size.height * 0.78)
      ..lineTo(size.width * 0.35, size.height * 0.50)
      ..lineTo(size.width * 0.75, size.height * 0.50)
      ..lineTo(size.width * 0.75, size.height * 0.22)
      ..lineTo(size.width * 0.85, size.height * 0.22);

    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
