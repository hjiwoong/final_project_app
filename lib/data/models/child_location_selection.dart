import 'child_location.dart';

/// 주소 확정과 지도 좌표 보정에 사용하는 편집 상태.
class ChildLocationSelection {
  String addressText = '';
  double? latitude;
  double? longitude;
  bool isConfirmed = false;
  bool isAdjusted = false;

  void load(ChildLocation location) {
    addressText = location.address ?? '';
    latitude = location.latitude;
    longitude = location.longitude;
    isConfirmed =
        addressText.trim().isNotEmpty && latitude != null && longitude != null;
    isAdjusted = false;
  }

  void confirmAddress(AddressCandidate candidate) {
    addressText = candidate.address;
    latitude = candidate.latitude;
    longitude = candidate.longitude;
    isConfirmed = true;
    isAdjusted = false;
  }

  void editAddress(String value) {
    addressText = value;
    latitude = null;
    longitude = null;
    isConfirmed = false;
    isAdjusted = false;
  }

  void setMapPosition(double nextLatitude, double nextLongitude) {
    final wasConfirmed = isConfirmed;
    final positionChanged =
        latitude != null &&
        longitude != null &&
        (latitude != nextLatitude || longitude != nextLongitude);

    latitude = nextLatitude;
    longitude = nextLongitude;
    isConfirmed = addressText.trim().isNotEmpty;
    isAdjusted = wasConfirmed && (isAdjusted || positionChanged);
  }

  void clear() {
    addressText = '';
    latitude = null;
    longitude = null;
    isConfirmed = false;
    isAdjusted = false;
  }
}
