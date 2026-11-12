import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/notifications/in_app_notification_banner.dart';
import '../../data/api/api_repository.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late Future<Map<String, dynamic>> _trips;
  List<Map<String, dynamic>> _loadedTrips = [];
  int _totalTrips = 0;
  bool _loadingMore = false;
  final Map<String, GlobalKey> _dateSectionKeys = {};

  @override
  void initState() {
    super.initState();
    _trips = ApiRepository.instance.getTripRecords();
  }

  Future<void> _refresh() async {
    final trips = ApiRepository.instance.getTripRecords();
    setState(() {
      _trips = trips;
      _loadedTrips = [];
      _totalTrips = 0;
    });
    final result = await trips;
    if (!mounted) return;
    setState(() {
      _loadedTrips = _items(result);
      _totalTrips = result['total'] as int? ?? 0;
    });
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> result) =>
      (result['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<void> _loadMore() async {
    if (_loadingMore || _loadedTrips.length >= _totalTrips) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ApiRepository.instance.getTripRecords(
        offset: _loadedTrips.length,
      );
      if (!mounted) return;
      setState(() {
        _loadedTrips.addAll(_items(result));
        _totalTrips = result['total'] as int? ?? _totalTrips;
      });
    } catch (error) {
      if (mounted) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '추가 운행 기록을 불러오지 못했습니다.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(Map<String, dynamic> trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
  }

  Widget _tripCard(Map<String, dynamic> trip) {
    final colors = Theme.of(context).colorScheme;
    final boarding = TripFormat.toInt(trip['boarding_count']);
    final alighted = TripFormat.toInt(trip['alighted_count']);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDetail(trip),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.directions_bus_outlined,
                  color: TripStatusBadge.colorOf(context, trip),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TripFormat.title(trip),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${TripFormat.timeRange(trip)} · '
                      '${trip['driver_name'] ?? '운전자 정보 없음'}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TripStatusBadge(trip: trip),
                        if (boarding != null || alighted != null)
                          InfoBadge(
                            '승차 ${boarding ?? '-'} · 하차 ${alighted ?? '-'}',
                            colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// 날짜별 섹션 제목을 끼워 넣은 목록
  List<Widget> _groupedTrips(List<Map<String, dynamic>> trips) {
    final widgets = <Widget>[];
    String? lastHeader;
    for (final trip in trips) {
      final date = TripFormat.parse(trip['started_at']);
      final dateKey = '${date!.year}-${date.month}-${date.day}';
      final header = TripFormat.dateHeader(date);
      if (header != lastHeader) {
        widgets.add(
          Padding(
            key: _dateSectionKeys.putIfAbsent(dateKey, () => GlobalKey()),
            padding: EdgeInsets.fromLTRB(4, lastHeader == null ? 4 : 16, 4, 8),
            child: Text(
              header,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        );
        lastHeader = header;
      }
      widgets.add(_tripCard(trip));
    }
    return widgets;
  }

  Future<void> _jumpToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '이동할 날짜 선택',
    );
    if (selectedDate == null || !mounted) return;

    bool hasTripsOnDate() => _loadedTrips.any((trip) {
          final date = TripFormat.parse(trip['started_at']);
          return date?.year == selectedDate.year &&
              date?.month == selectedDate.month &&
              date?.day == selectedDate.day;
        });

    setState(() => _loadingMore = true);
    try {
      while (!hasTripsOnDate() && _loadedTrips.length < _totalTrips) {
        final previousLength = _loadedTrips.length;
        final result = await ApiRepository.instance.getTripRecords(
          offset: previousLength,
        );
        if (!mounted) return;
        setState(() {
          _loadedTrips.addAll(_items(result));
          _totalTrips = result['total'] as int? ?? _totalTrips;
        });
        if (_loadedTrips.length == previousLength) break;
      }

      if (!mounted) return;
      if (!hasTripsOnDate()) {
        InAppNotificationBanner.showMessage('선택한 날짜의 운행 기록이 없습니다.');
        return;
      }

      final dateKey =
          '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
      await WidgetsBinding.instance.endOfFrame;
      final targetContext = _dateSectionKeys[dateKey]?.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          alignment: 0,
        );
      }
    } catch (error) {
      if (mounted) {
        InAppNotificationBanner.showMessage(
          AppErrorMessage.from(error, fallback: '날짜 이동에 실패했습니다.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 기록'),
        actions: [
          IconButton(
            tooltip: '날짜로 이동',
            onPressed: _loadingMore ? null : _jumpToDate,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _trips,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  const Center(child: Text('운행 기록을 불러오지 못했습니다.')),
                  Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              );
            }
            if (_loadedTrips.isEmpty && snapshot.hasData) {
              _loadedTrips = _items(snapshot.data!);
              _totalTrips = snapshot.data!['total'] as int? ?? 0;
            }
            final trips = _loadedTrips;
            if (trips.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('등록된 운행 기록이 없습니다.')),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                ..._groupedTrips(trips),
                if (trips.length < _totalTrips)
                  Center(
                    child: TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? '불러오는 중...' : '더 불러오기'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
