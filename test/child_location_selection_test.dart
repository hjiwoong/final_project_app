import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/data/models/child_location.dart';
import 'package:final_project_app/data/models/child_location_selection.dart';

void main() {
  const candidate = AddressCandidate(
    name: '테스트 장소',
    address: '서울특별시 중구 세종대로 110',
    roadAddress: '서울특별시 중구 세종대로 110',
    latitude: 37.5665,
    longitude: 126.978,
  );

  test('주소 후보를 선택하면 주소와 좌표가 확정된다', () {
    final selection = ChildLocationSelection();

    selection.confirmAddress(candidate);

    expect(selection.addressText, candidate.address);
    expect(selection.latitude, candidate.latitude);
    expect(selection.longitude, candidate.longitude);
    expect(selection.isConfirmed, isTrue);
    expect(selection.isAdjusted, isFalse);
  });

  test('지도 보정은 주소를 유지하고 좌표만 갱신한다', () {
    final selection = ChildLocationSelection()..confirmAddress(candidate);

    selection.setMapPosition(37.567, 126.979);

    expect(selection.addressText, candidate.address);
    expect(selection.latitude, 37.567);
    expect(selection.longitude, 126.979);
    expect(selection.isConfirmed, isTrue);
    expect(selection.isAdjusted, isTrue);
  });

  test('확정 주소를 수정하면 기존 좌표와 보정 상태를 초기화한다', () {
    final selection = ChildLocationSelection()
      ..confirmAddress(candidate)
      ..setMapPosition(37.567, 126.979);

    selection.editAddress('새 주소');

    expect(selection.addressText, '새 주소');
    expect(selection.latitude, isNull);
    expect(selection.longitude, isNull);
    expect(selection.isConfirmed, isFalse);
    expect(selection.isAdjusted, isFalse);
  });

  test('X 초기화는 주소, 좌표, 확정 및 보정 상태를 모두 초기화한다', () {
    final selection = ChildLocationSelection()
      ..confirmAddress(candidate)
      ..setMapPosition(37.567, 126.979);

    selection.clear();

    expect(selection.addressText, isEmpty);
    expect(selection.latitude, isNull);
    expect(selection.longitude, isNull);
    expect(selection.isConfirmed, isFalse);
    expect(selection.isAdjusted, isFalse);
  });

  test('저장된 주소와 좌표는 확정 상태로 복원된다', () {
    final selection = ChildLocationSelection()
      ..load(
        ChildLocation(
          address: candidate.address,
          latitude: candidate.latitude,
          longitude: candidate.longitude,
        ),
      );

    expect(selection.addressText, candidate.address);
    expect(selection.latitude, candidate.latitude);
    expect(selection.longitude, candidate.longitude);
    expect(selection.isConfirmed, isTrue);
    expect(selection.isAdjusted, isFalse);
  });
}
