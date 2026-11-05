/// 종점 판정 결과: 하차 수 = 승차 수 - 잔류 수
class JudgeResult {
  final int boardingCount;
  final int remainingCount;
  final String? imagePath;
  final String? imageUrl;

  const JudgeResult({
    required this.boardingCount,
    required this.remainingCount,
    this.imagePath,
    this.imageUrl,
  });

  int get alightedCount => boardingCount - remainingCount;

  /// 잔류 0명이면 정상, 1명 이상이면 미하차 의심
  bool get isOk => remainingCount == 0;

  JudgeResult copyWith({
    int? boardingCount,
    int? remainingCount,
    String? imagePath,
    String? imageUrl,
  }) {
    return JudgeResult(
      boardingCount: boardingCount ?? this.boardingCount,
      remainingCount: remainingCount ?? this.remainingCount,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory JudgeResult.fromJson(
    Map<String, dynamic> json, {
    int? fallbackBoardingCount,
  }) {
    final root = Map<String, dynamic>.from(json);
    final nestedResult = json['result'];
    if (nestedResult is Map) {
      root.addAll(Map<String, dynamic>.from(nestedResult));
    }

    final boarding =
        _readInt(root, ['boarding_count', 'boardingCount', '승차인원']) ??
        fallbackBoardingCount ??
        0;
    final remaining =
        _readInt(root, ['remaining_count', 'remainingCount', '잔류인원']) ?? 0;

    return JudgeResult(
      boardingCount: boarding,
      remainingCount: remaining,
      imagePath: _readString(root, [
        'image_path',
        'imagePath',
        'local_path',
        'localPath',
        'file_path',
        'filePath',
      ]),
      imageUrl: _readString(root, [
        'image_url',
        'imageUrl',
        'photo_url',
        'photoUrl',
        'dropoff_photo_url',
        'dropoffPhotoUrl',
        'result_image_url',
        'resultImageUrl',
      ]),
    );
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }
}
