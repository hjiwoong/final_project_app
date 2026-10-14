/// 종점 판정 결과: 하차 수 = 승차 수 - 잔류 수
class JudgeResult {
  final int boardingCount;
  final int remainingCount;

  const JudgeResult({required this.boardingCount, required this.remainingCount});

  int get alightedCount => boardingCount - remainingCount;

  /// 잔류 0명이면 정상, 1명 이상이면 미하차 의심
  bool get isOk => remainingCount == 0;
}
