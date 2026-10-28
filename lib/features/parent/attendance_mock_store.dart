
import 'package:flutter/foundation.dart';

class AttendanceMockStore {
  // 기존 학부모 홈에서 사용하는 오늘 결석 상태
  static final ValueNotifier<Map<String, bool>> absent =
  ValueNotifier({
    '김하늘': true,
    '이도윤': false,
  });

  // 날짜별 결석 상태 저장 (Mock)
  static final Map<String, Map<String, bool>> _attendanceByDate = {};

  // 날짜를 YYYY-MM-DD 형식으로 변환
  static String _dateKey(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // 날짜만 비교
  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  // 선택한 날짜의 결석 정보 가져오기
  static Map<String, bool> getAttendance(DateTime date) {
    final key = _dateKey(date);

    if (_attendanceByDate.containsKey(key)) {
      return Map<String, bool>.from(_attendanceByDate[key]!);
    }

    // 오늘은 기존 저장값 사용
    if (_isSameDate(date, DateTime.now())) {
      return Map<String, bool>.from(absent.value);
    }

    // 다른 날짜는 기본적으로 모두 등교
    return {
      for (final name in absent.value.keys) name: false,
    };
  }

  // 기존 저장 함수 유지 (오늘 결석)
  static void save(Map<String, bool> newAbsent) {
    final updated = Map<String, bool>.from(newAbsent);

    absent.value = updated;
    _attendanceByDate[_dateKey(DateTime.now())] =
    Map<String, bool>.from(updated);
  }

  // 선택한 날짜의 결석 정보 저장
  static void saveForDate(
      DateTime date,
      Map<String, bool> newAbsent,
      ) {
    final updated = Map<String, bool>.from(newAbsent);

    _attendanceByDate[_dateKey(date)] = updated;

    // 오늘 날짜인 경우 기존 홈 화면에도 반영
    if (_isSameDate(date, DateTime.now())) {
      absent.value = Map<String, bool>.from(updated);
    }
  }
}
