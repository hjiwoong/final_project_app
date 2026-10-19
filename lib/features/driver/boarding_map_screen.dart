import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../widgets/primary_button.dart';
import 'boarding_capture_screen.dart';

/// ② 탑승 지도: 네이버 지도 + 정류장 마커 + 학부모 출결 반영 UI (스크린샷 스타일)
class BoardingMapScreen extends StatefulWidget {
  final String tripId;
  const BoardingMapScreen({super.key, required this.tripId});

  @override
  State<BoardingMapScreen> createState() => _BoardingMapScreenState();
}

class _BoardingMapScreenState extends State<BoardingMapScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  int _currentStopIndex = 1; // 0: 1번 정류장, 1: 2번 정류장(접근시), 2: 마지막 정류장(유치원)
  bool _isSheetCollapsed = false;
  double _collapsedSheetSize = 0.12;

  final List<Map<String, dynamic>> _stops = [
    {
      'title': '📍 1번 정류장 도착',
      'student': '박서연 · 7세 · 학부모 앱 출석 설정 ON',
      'status': '승차 완료',
      'statusColor': Colors.green,
    },
    {
      'title': '📍 2번 정류장 도착',
      'student': '김하늘 · 1학년 2반 · 학부모 앱 출석 설정 ON',
      'status': '출석',
      'statusColor': Colors.red,
    },
    {
      'title': '🏫 ○○유치원 도착 · 마지막 정류장',
      'student': '탑승 5명 · 결석 3명 제외 (탑승 예정 8명)',
      'status': '종점',
      'statusColor': Colors.blue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_updateSheetState);
  }

  @override
  void dispose() {
    _sheetController
      ..removeListener(_updateSheetState)
      ..dispose();
    super.dispose();
  }

  void _updateSheetState() {
    if (!_sheetController.isAttached) return;
    final isCollapsed = _sheetController.size <= _collapsedSheetSize + 0.01;
    if (isCollapsed != _isSheetCollapsed) {
      setState(() => _isSheetCollapsed = isCollapsed);
    }
  }

  void _nextStop() {
    if (_currentStopIndex < _stops.length - 1) {
      setState(() {
        _currentStopIndex++;
      });
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BoardingCaptureScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stop = _stops[_currentStopIndex];
    final isLast = _currentStopIndex == _stops.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('탑승 지도'),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsedSheetSize = (88 / constraints.maxHeight)
              .clamp(0.1, 0.3)
              .toDouble();
          final expandedSheetSize = (152 / constraints.maxHeight)
              .clamp(collapsedSheetSize + 0.05, 0.5)
              .toDouble();
          _collapsedSheetSize = collapsedSheetSize;

          return Stack(
            children: [
              NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(37.5666102, 126.9783881),
                    zoom: 15,
                  ),
                  locationButtonEnable: true,
                ),
                onMapReady: (controller) {
                  debugPrint('네이버 지도 로딩 완료');
                },
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendDot(Colors.red, '출석 대기'),
                        const SizedBox(width: 14),
                        _buildLegendDot(Colors.green, '승차 완료'),
                        const SizedBox(width: 14),
                        _buildLegendDot(Colors.grey, '결석'),
                      ],
                    ),
                  ),
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: expandedSheetSize,
                minChildSize: collapsedSheetSize,
                maxChildSize: expandedSheetSize,
                snap: true,
                snapSizes: [collapsedSheetSize, expandedSheetSize],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                      children: [
                        Center(
                          child: Semantics(
                            label: '정류장 정보 패널을 위아래로 밀어 지도 보기',
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop['title'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (stop['statusColor'] as Color)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      stop['status'],
                                      style: TextStyle(
                                        color: stop['statusColor'],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stop['student'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!_isSheetCollapsed) ...[
                                const SizedBox(height: 10),
                                PrimaryButton(
                                  label: isLast ? '탑승 완료' : '승차 완료',
                                  onPressed: _nextStop,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
