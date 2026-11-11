/// 종점 판정 결과: 하차 수 = 승차 수 - 잔류 수
class JudgeResult {
  final int boardingCount;
  final int remainingCount;
  final String? imagePath;
  final String? imageUrl;
  final String? result;
  final String? message;
  final String? guidance;
  final bool? retakeRecommended;
  final List<String> agentReasons;
  final int? alertId;

  const JudgeResult({
    required this.boardingCount,
    required this.remainingCount,
    this.imagePath,
    this.imageUrl,
    this.result,
    this.message,
    this.guidance,
    this.retakeRecommended,
    this.agentReasons = const [],
    this.alertId,
  });

  int get alightedCount => boardingCount - remainingCount;

  bool get isOk => result == null ? remainingCount == 0 : result == 'OK';
  bool get isNeedsCheck => result == 'NEEDS_CHECK';
  bool get shouldRetake => retakeRecommended ?? !isOk;

  JudgeResult copyWith({
    int? boardingCount,
    int? remainingCount,
    String? imagePath,
    String? imageUrl,
    String? result,
    String? message,
    String? guidance,
    bool? retakeRecommended,
    List<String>? agentReasons,
    int? alertId,
  }) {
    return JudgeResult(
      boardingCount: boardingCount ?? this.boardingCount,
      remainingCount: remainingCount ?? this.remainingCount,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      result: result ?? this.result,
      message: message ?? this.message,
      guidance: guidance ?? this.guidance,
      retakeRecommended: retakeRecommended ?? this.retakeRecommended,
      agentReasons: agentReasons ?? this.agentReasons,
      alertId: alertId ?? this.alertId,
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
      result: _readString(root, ['result', 'verdict']),
      message: _readString(root, ['message']),
      guidance: _readString(root, ['guidance']),
      retakeRecommended: root['retake_recommended'] is bool
          ? root['retake_recommended'] as bool
          : null,
      agentReasons: root['agent_reasons'] is List
          ? (root['agent_reasons'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
      alertId: _readInt(root, ['alert_id']),
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
