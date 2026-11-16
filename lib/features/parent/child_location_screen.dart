import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/theme/app_theme.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_location.dart';
import '../../data/models/child_location_selection.dart';
import '../../data/models/child_student.dart';
import '../../widgets/address_search_field.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ChildLocationScreen extends StatefulWidget {
  const ChildLocationScreen({super.key, this.initialChildId});

  final int? initialChildId;

  @override
  State<ChildLocationScreen> createState() => _ChildLocationScreenState();
}

class _ChildLocationScreenState extends State<ChildLocationScreen> {
  final _addressController = TextEditingController();
  final _selection = ChildLocationSelection();
  List<ChildStudent> _children = const [];
  ChildStudent? _child;
  ChildLocation? _savedLocation;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  int _loadId = 0;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await ApiRepository.instance.getChildren();
      if (!mounted) return;
      if (children.isEmpty) {
        setState(() {
          _children = children;
          _child = null;
          _loading = false;
        });
        return;
      }
      final initial = children.firstWhere(
        (child) => child.id == widget.initialChildId,
        orElse: () => children.first,
      );
      _children = children;
      await _selectChild(initial);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _selectChild(ChildStudent child) async {
    final loadId = ++_loadId;
    setState(() {
      _child = child;
      _savedLocation = null;
      _selection.clear();
      _addressController.clear();
      _loading = true;
      _error = null;
    });
    try {
      final location = await ApiRepository.instance.getChildLocation(child.id);
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _savedLocation = location;
        _addressController.text = location.address ?? '';
        _selection.load(location);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || loadId != _loadId) return;
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

  void _onCandidateSelected(AddressCandidate candidate) {
    setState(() {
      _selection.confirmAddress(candidate);
      _error = null;
    });
  }

  void _onAddressEdited() {
    setState(() => _selection.editAddress(_addressController.text));
  }

  void _clearAddress() {
    setState(() {
      _selection.clear();
      _addressController.clear();
      _error = null;
    });
  }

  Future<void> _chooseCoordinates() async {
    final selected = await Navigator.of(context).push<NLatLng>(
      MaterialPageRoute(
        builder: (_) => _ChildLocationPickerScreen(
          initialPosition:
              _selection.latitude != null && _selection.longitude != null
              ? NLatLng(_selection.latitude!, _selection.longitude!)
              : null,
          initialAddress: _addressController.text.trim(),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selection.setMapPosition(selected.latitude, selected.longitude);
    });
  }

  Future<void> _save() async {
    final child = _child;
    if (child == null) return;
    if (!_selection.isConfirmed ||
        _selection.latitude == null ||
        _selection.longitude == null) {
      return;
    }
    final address = _selection.addressText.trim();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final location = await ApiRepository.instance.saveChildLocation(
        child.id,
        address: address,
        latitude: _selection.latitude,
        longitude: _selection.longitude,
      );
      if (!mounted || _child?.id != child.id) return;
      setState(() {
        _savedLocation = location;
        _saving = false;
      });
      InAppNotificationBanner.showMessage('${child.name}의 주소와 위치를 저장했습니다.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    final child = _child;
    if (child == null) return;
    final colorScheme = Theme.of(context).colorScheme;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: AppTheme.sheetDecoration(sheetContext),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '위치 정보 삭제',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${child.name}의 저장된 주소와 좌표를 삭제할까요?',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('삭제'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ApiRepository.instance.clearChildLocation(child.id);
      if (!mounted || _child?.id != child.id) return;
      setState(() {
        _savedLocation = const ChildLocation();
        _selection.clear();
        _addressController.clear();
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
    final colors = Theme.of(context).colorScheme;
    final hasSavedLocation =
        _savedLocation?.address?.isNotEmpty == true ||
        _savedLocation?.hasCoordinates == true;
    final hasPreview =
        _selection.isConfirmed &&
        _selection.latitude != null &&
        _selection.longitude != null;

    Widget body;
    if (_loading && _child == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_child == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? '연결된 자녀가 없습니다. 자녀를 먼저 연결해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _error != null ? colors.error : null),
              ),
              if (_error != null)
                TextButton(
                  onPressed: _loadChildren,
                  child: const Text('다시 시도'),
                ),
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '자녀의 승하차 위치를 확인하기 위해 자녀 주소를 등록합니다.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '도로명·지번 주소 또는 장소명을 검색해 후보를 선택해 주세요. 선택한 주소는 지도에서 위치를 보정할 수 있습니다.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_children.length > 1) ...[
            DropdownButtonFormField<int>(
              initialValue: _child!.id,
              decoration: const InputDecoration(
                labelText: '자녀',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final child in _children)
                  DropdownMenuItem(value: child.id, child: Text(child.name)),
              ],
              onChanged: _busy
                  ? null
                  : (id) {
                      final next = _children.firstWhere((c) => c.id == id);
                      if (next.id != _child!.id) _selectChild(next);
                    },
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(_child!.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AddressSearchField(
              controller: _addressController,
              maxLines: 2,
              isConfirmed: _selection.isConfirmed,
              readOnly: _selection.isConfirmed,
              onClear: _clearAddress,
              trailing: IconButton(
                tooltip: '지도에서 위치 지정 / 보정',
                onPressed: _busy ? null : _chooseCoordinates,
                icon: const Icon(Icons.map_outlined),
              ),
              onSelected: _onCandidateSelected,
              onEdited: _onAddressEdited,
            ),
            if (hasPreview) ...[
              const SizedBox(height: 12),
              _LocationMapPreview(
                latitude: _selection.latitude!,
                longitude: _selection.longitude!,
                onTap: _busy ? null : _chooseCoordinates,
              ),
              if (_selection.isAdjusted) ...[
                const SizedBox(height: 6),
                Text(
                  '위치 보정됨',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy || _loading || !_selection.isConfirmed
                  ? null
                  : _save,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text('주소 저장'),
            ),
          ),
          if (hasSavedLocation) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || _loading ? null : _delete,
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
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('자녀 주소 및 위치')),
      body: body,
    );
  }
}

class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview({
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  final double latitude;
  final double longitude;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final position = NLatLng(latitude, longitude);
    return Semantics(
      button: true,
      label: '지도 미리보기, 탭하여 위치 보정',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            child: IgnorePointer(
              child: NaverMap(
                key: ValueKey('$latitude,$longitude'),
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: position,
                    zoom: 16,
                  ),
                  locationButtonEnable: false,
                  nightModeEnable:
                      Theme.of(context).brightness == Brightness.dark,
                ),
                onMapReady: (controller) async {
                  await controller.addOverlay(
                    NMarker(id: 'child_location_preview', position: position),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildLocationPickerScreen extends StatefulWidget {
  const _ChildLocationPickerScreen({this.initialPosition, this.initialAddress});

  final NLatLng? initialPosition;
  final String? initialAddress;

  @override
  State<_ChildLocationPickerScreen> createState() =>
      _ChildLocationPickerScreenState();
}

class _ChildLocationPickerScreenState
    extends State<_ChildLocationPickerScreen> {
  static const _defaultPosition = NLatLng(37.5665, 126.9780);

  NaverMapController? _controller;
  NMarker? _marker;
  NLatLng? _selectedPosition;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialAddress,
  );
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

  Future<void> _onCandidateSelected(AddressCandidate candidate) async {
    final position = NLatLng(candidate.latitude, candidate.longitude);
    await _setPosition(position);
    await _controller?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: position, zoom: 16),
    );
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
        id: 'child_location_selection',
        position: position,
        caption: const NOverlayCaption(text: '자녀 위치'),
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
                    AddressSearchField(
                      controller: _searchController,
                      labelText: '주소 검색',
                      hintText: '도로명 주소를 입력하세요',
                      onSelected: _onCandidateSelected,
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
