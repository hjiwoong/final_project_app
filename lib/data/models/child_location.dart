class ChildLocation {
  const ChildLocation({this.address, this.latitude, this.longitude});

  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory ChildLocation.fromJson(Map<String, dynamic> json) => ChildLocation(
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

/// 주소 자동완성 후보 한 건.
class AddressCandidate {
  const AddressCandidate({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.roadAddress,
    this.jibunAddress,
    this.name,
  });

  final String? name;
  final String address;
  final String? roadAddress;
  final String? jibunAddress;
  final double latitude;
  final double longitude;

  factory AddressCandidate.fromJson(Map<String, dynamic> json) =>
      AddressCandidate(
        name: json['name'] as String?,
        address: json['address'] as String,
        roadAddress: json['road_address'] as String?,
        jibunAddress: json['jibun_address'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}
