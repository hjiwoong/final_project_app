class TripProgress {
  const TripProgress({
    required this.tripId,
    required this.busId,
    required this.busName,
    required this.busNumber,
    required this.isMock,
    required this.currentStopIndex,
    this.simulationMode = false,
    this.boardingCount,
    this.boardingPhotoGuidance,
  });

  final int tripId;
  final int busId;
  final String busName;
  final String busNumber;
  final bool isMock;
  final int currentStopIndex;
  final bool simulationMode;
  final int? boardingCount;
  final String? boardingPhotoGuidance;

  TripProgress copyWith({
    int? currentStopIndex,
    bool? simulationMode,
    int? boardingCount,
    String? boardingPhotoGuidance,
    bool clearBoardingCount = false,
    bool clearBoardingPhotoGuidance = false,
  }) => TripProgress(
    tripId: tripId,
    busId: busId,
    busName: busName,
    busNumber: busNumber,
    isMock: isMock,
    currentStopIndex: currentStopIndex ?? this.currentStopIndex,
    simulationMode: simulationMode ?? this.simulationMode,
    boardingCount: clearBoardingCount
        ? null
        : boardingCount ?? this.boardingCount,
    boardingPhotoGuidance: clearBoardingCount || clearBoardingPhotoGuidance
        ? null
        : boardingPhotoGuidance ?? this.boardingPhotoGuidance,
  );

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'bus_id': busId,
    'bus_name': busName,
    'bus_number': busNumber,
    'is_mock': isMock,
    'current_stop_index': currentStopIndex,
    'simulation_mode': simulationMode,
    'boarding_count': boardingCount,
    'boarding_photo_guidance': boardingPhotoGuidance,
  };

  factory TripProgress.fromJson(Map<String, dynamic> json) => TripProgress(
    tripId: json['trip_id'] as int,
    busId: json['bus_id'] as int,
    busName: json['bus_name'] as String,
    busNumber: json['bus_number'] as String,
    isMock: json['is_mock'] as bool,
    currentStopIndex: json['current_stop_index'] as int,
    simulationMode: json['simulation_mode'] as bool? ?? false,
    boardingCount: json['boarding_count'] as int?,
    boardingPhotoGuidance: json['boarding_photo_guidance'] as String?,
  );
}
