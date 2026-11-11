import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/errors/app_error_message.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/guardian_location.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class GuardianLocationScreen extends StatefulWidget {
  const GuardianLocationScreen({super.key});

  @override
  State<GuardianLocationScreen> createState() => _GuardianLocationScreenState();
}

class _GuardianLocationScreenState extends State<GuardianLocationScreen> {
  final _addressController = TextEditingController();
  GuardianLocation? _location;
  String? _coordinatesForAddress;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await ApiRepository.instance.getMyLocation();
      if (!mounted) return;
      setState(() {
        _location = location;
        _addressController.text = location.address ?? '';
        _coordinatesForAddress = location.address;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    return AppErrorMessage.from(
      error,
      fallback: '위치 정보를 불러오지 못했습니다. 다시 시도해 주세요.',
    );
  }

  Future<void> _chooseCoordinates() async {
    final latitude = _location?.latitude;
    final longitude = _location?.longitude;
    final selected = await Navigator.of(context).push<NLatLng>(
      MaterialPageRoute(
        builder: (_) => _GuardianLocationPickerScreen(
          initialPosition: latitude != null && longitude != null
              ? NLatLng(latitude, longitude)
              : null,
          initialAddress: _addressController.text.trim(),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _location = GuardianLocation(
        address: _location?.address,
        latitude: selected.latitude,
        longitude: selected.longitude,
      );
      _coordinatesForAddress = _addressController.text.trim();
    });
  }

  Future<void> _save() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = '주소를 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final shouldUseCoordinates =
        _coordinatesForAddress == address && _location?.hasCoordinates == true;
    try {
      final location = await ApiRepository.instance.saveMyLocation(
        address: address,
        latitude: shouldUseCoordinates ? _location!.latitude : null,
        longitude: shouldUseCoordinates ? _location!.longitude : null,
      );
      if (!mounted) return;
      setState(() {
        _location = location;
        _coordinatesForAddress = location.address;
        _saving = false;
      });
      InAppNotificationBanner.showMessage('주소와 위치를 저장했습니다.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 삭제'),
        content: const Text('저장된 주소와 좌표를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ApiRepository.instance.clearMyLocation();
      if (!mounted) return;
      setState(() {
        _location = const GuardianLocation();
        _addressController.clear();
        _coordinatesForAddress = null;
        _deleting = false;
      });
      InAppNotificationBanner.showMessage('위치 정보를 삭제했습니다.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _location?.address?.isNotEmpty == true;
    final hasCoordinates = _location?.hasCoordinates == true;

    return Scaffold(
      appBar: AppBar(title: const Text('보호자 주소 및 위치')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '통학 관련 위치 확인을 위해 보호자 주소를 등록합니다.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '주소는 관리자 화면에서 확인할 수 있습니다. 주소를 저장하면 서버에서 좌표를 검색하며, 지도를 눌러 위치를 직접 보정할 수 있습니다.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _addressController,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '주소',
                    hintText: '도로명 주소를 입력해 주세요.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving || _deleting ? null : _chooseCoordinates,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('지도에서 위치 지정 / 보정'),
                ),
                if (hasCoordinates) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('선택한 좌표'),
                      subtitle: Text(
                        '${_location!.latitude!.toStringAsFixed(7)}, '
                        '${_location!.longitude!.toStringAsFixed(7)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => setState(() {
                          _location = GuardianLocation(
                            address: _location?.address,
                          );
                          _coordinatesForAddress = null;
                        }),
                        icon: const Icon(Icons.close),
                        tooltip: '지도 좌표 지우기',
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '지도를 선택하지 않으면 주소를 기준으로 좌표를 자동 검색합니다.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_location == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLocation,
                        child: const Text('다시 시도'),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving || _deleting ? null : _save,
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    child: _saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('주소 저장'),
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving || _deleting ? null : _delete,
                    child: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장된 주소 삭제'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _GuardianLocationPickerScreen extends StatefulWidget {
  const _GuardianLocationPickerScreen({
    this.initialPosition,
    this.initialAddress,
  });

  final NLatLng? initialPosition;
  final String? initialAddress;

  @override
  State<_GuardianLocationPickerScreen> createState() =>
      _GuardianLocationPickerScreenState();
}

class _GuardianLocationPickerScreenState
    extends State<_GuardianLocationPickerScreen> {
  static const _defaultPosition = NLatLng(37.5665, 126.9780);

  NaverMapController? _controller;
  NMarker? _marker;
  NLatLng? _selectedPosition;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialAddress,
  );
  bool _searching = false;
  bool _locating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    InAppNotificationBanner.showMessage(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  Future<void> _searchAddress() async {
    final address = _searchController.text.trim();
    if (address.isEmpty) {
      _showMessage('검색할 주소나 장소명을 입력해 주세요.');
      return;
    }

    setState(() => _searching = true);
    try {
      final result = await ApiRepository.instance.searchLocationAddress(
        address,
      );
      if (!mounted || !result.hasCoordinates) return;
      final position = NLatLng(result.latitude!, result.longitude!);
      await _setPosition(position);
      await _controller?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: position, zoom: 16),
      );
    } on DioException catch (error) {
      _showMessage(
        AppErrorMessage.from(
          error,
          fallback: '주소 검색에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } catch (error) {
      _showMessage(
        AppErrorMessage.from(
          error,
          fallback: '주소 검색에 실패했습니다. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _findCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage(
          '기기의 위치 서비스를 켜 주세요.',
          actionLabel: '설정',
          onAction: () async {
            await Geolocator.openLocationSettings();
          },
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage('위치 권한이 없어 현재 위치를 찾을 수 없습니다. 지도에서 직접 선택해 주세요.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          '위치 권한이 차단되어 있습니다. 설정에서 권한을 허용해 주세요.',
          actionLabel: '앱 설정',
          onAction: () async {
            await Geolocator.openAppSettings();
          },
        );
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final position = NLatLng(current.latitude, current.longitude);
      await _setPosition(position);
      await _controller?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: position, zoom: 16),
      );
    } on TimeoutException {
      _showMessage('현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요.');
    } on LocationServiceDisabledException {
      _showMessage('기기의 위치 서비스가 꺼져 있습니다.');
    } on PermissionDeniedException {
      _showMessage('위치 권한이 없어 현재 위치를 찾을 수 없습니다. 지도에서 직접 선택해 주세요.');
    } catch (_) {
      _showMessage('현재 위치를 찾지 못했습니다. 지도에서 직접 선택해 주세요.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setPosition(NLatLng position) async {
    setState(() => _selectedPosition = position);
    final controller = _controller;
    if (controller == null) return;
    final marker = _marker;
    if (marker == null) {
      final newMarker = NMarker(
        id: 'guardian_location_selection',
        position: position,
        caption: const NOverlayCaption(text: '보호자 위치'),
      );
      _marker = newMarker;
      await controller.addOverlay(newMarker);
    } else {
      marker.setPosition(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraPosition = widget.initialPosition ?? _defaultPosition;

    return Scaffold(
      appBar: AppBar(title: const Text('지도에서 위치 지정')),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: cameraPosition,
                zoom: 16,
              ),
              nightModeEnable: Theme.of(context).brightness == Brightness.dark,
            ),
            onMapReady: (controller) async {
              _controller = controller;
              final initialPosition = widget.initialPosition;
              if (initialPosition != null) {
                await _setPosition(initialPosition);
              }
            },
            onMapTapped: (_, position) => _setPosition(position),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAddress(),
                      decoration: InputDecoration(
                        hintText: '도로명 주소 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: '주소 검색',
                          onPressed: _searching ? null : _searchAddress,
                          icon: _searching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _locating ? null : _findCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('현재 위치로 이동'),
                      ),
                    ),
                    Text(
                      _selectedPosition == null
                          ? '지도를 눌러 주소 위치를 선택해 주세요.'
                          : '위도 ${_selectedPosition!.latitude.toStringAsFixed(7)} · '
                                '경도 ${_selectedPosition!.longitude.toStringAsFixed(7)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _selectedPosition == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedPosition),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: const Text('이 위치 선택'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
