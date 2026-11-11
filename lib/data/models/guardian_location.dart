class GuardianLocation {
  const GuardianLocation({this.address, this.latitude, this.longitude});

  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory GuardianLocation.fromJson(Map<String, dynamic> json) =>
      GuardianLocation(
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
}
