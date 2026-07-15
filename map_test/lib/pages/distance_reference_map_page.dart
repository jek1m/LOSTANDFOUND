import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

class DistanceReference {
  const DistanceReference({required this.location, required this.label});

  final LatLng location;
  final String label;
}

class DistanceReferenceMapPage extends StatefulWidget {
  const DistanceReferenceMapPage({super.key, this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<DistanceReferenceMapPage> createState() =>
      _DistanceReferenceMapPageState();
}

class _DistanceReferenceMapPageState extends State<DistanceReferenceMapPage> {
  static final LatLng _defaultCenter = LatLng(37.5665, 126.9780);

  KakaoMapController? _mapController;
  late LatLng _selectedLocation;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultCenter;
  }

  Future<void> _confirm() async {
    if (_isConfirming) {
      return;
    }

    setState(() => _isConfirming = true);

    final controller = _mapController;
    LatLng location = _selectedLocation;
    if (controller != null) {
      location = await controller.getCenter().catchError((_) => location);
    }

    String label = _coordinateLabel(location);
    if (controller != null) {
      try {
        final response = await controller.coord2Address(
          Coord2AddressRequest(x: location.longitude, y: location.latitude),
        );
        if (response.list.isNotEmpty) {
          final address = response.list.first;
          label =
              address.roadAddress?.addressName ??
              address.address?.addressName ??
              label;
        }
      } catch (_) {
        // 주소 변환이 실패해도 선택한 좌표는 기준 위치로 사용할 수 있다.
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context, DistanceReference(location: location, label: label));
  }

  String _coordinateLabel(LatLng location) {
    return '${location.latitude.toStringAsFixed(5)}, '
        '${location.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '기준 위치 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: kIsWeb
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '웹에서는 지도 위치 선택을 지원하지 않습니다.\n현재 위치를 사용해 주세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: KakaoMap(
                    center: _selectedLocation,
                    currentLevel: 4,
                    zoomControl: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      controller.setCenter(_selectedLocation);
                    },
                    onCameraIdle: (location, _) {
                      setState(() => _selectedLocation = location);
                    },
                  ),
                ),
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 42),
                      child: Icon(
                        Icons.location_pin,
                        color: Color(0xFFE5484D),
                        size: 48,
                        shadows: [
                          Shadow(
                            color: Color(0x44000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 12),
                      ],
                    ),
                    child: const Text(
                      '지도를 움직여 거리 계산의 기준 위치를 맞춰 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isConfirming ? null : _confirm,
                        icon: _isConfirming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isConfirming ? '위치를 확인하는 중...' : '이 위치를 기준으로 선택',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
