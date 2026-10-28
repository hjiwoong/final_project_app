class TripProgress {
  const TripProgress({
    required this.tripId,
    required this.busId,
    required this.busName,
    required this.busNumber,
    required this.isMock,
    required this.currentStopIndex,
    this.simulationMode = false,
  });

  final int tripId;
  final int busId;
  final String busName;
  final String busNumber;
  final bool isMock;
  final int currentStopIndex;
  final bool simulationMode;

  TripProgress copyWith({int? currentStopIndex, bool? simulationMode}) =>
      TripProgress(
        tripId: tripId,
        busId: busId,
        busName: busName,
        busNumber: busNumber,
        isMock: isMock,
        currentStopIndex: currentStopIndex ?? this.currentStopIndex,
        simulationMode: simulationMode ?? this.simulationMode,
      );

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'bus_id': busId,
    'bus_name': busName,
    'bus_number': busNumber,
    'is_mock': isMock,
    'current_stop_index': currentStopIndex,
    'simulation_mode': simulationMode,
  };

  factory TripProgress.fromJson(Map<String, dynamic> json) => TripProgress(
    tripId: json['trip_id'] as int,
    busId: json['bus_id'] as int,
    busName: json['bus_name'] as String,
    busNumber: json['bus_number'] as String,
    isMock: json['is_mock'] as bool,
    currentStopIndex: json['current_stop_index'] as int,
    simulationMode: json['simulation_mode'] as bool? ?? false,
  );
}
