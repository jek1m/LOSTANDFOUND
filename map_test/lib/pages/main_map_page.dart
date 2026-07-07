import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import 'found_register_page.dart';
import 'lost_search_page.dart';

class MainMapPage extends StatefulWidget {
  const MainMapPage({super.key});

  @override
  State<MainMapPage> createState() => _MainMapPageState();
}

class _MainMapPageState extends State<MainMapPage> {
  KakaoMapController? mapController;

  LatLng? currentLocation;
  bool isLoadingLocation = true;
  String? locationMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationError('위치 서비스를 켜주세요');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationError('위치 권한이 필요합니다');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationError('설정에서 위치 권한을 허용해주세요');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        currentLocation = latLng;
        isLoadingLocation = false;
        locationMessage = null;
      });
      _moveMap(latLng);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _setLocationError('현재 위치를 불러오지 못했습니다');
    }
  }

  void _setLocationError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      currentLocation = null;
      isLoadingLocation = false;
      locationMessage = message;
    });
  }

  void _moveMap(LatLng latLng) {
    mapController?.setCenter(latLng);
    mapController?.setLevel(3);
  }

  @override
  Widget build(BuildContext context) {
    final location = currentLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 18, bottom: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE9EEF5), width: 1),
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    '찾아드림',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '잃어버린 물건을 찾아드립니다',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (location == null)
                    _LocationLoadingMap(
                      isLoading: isLoadingLocation,
                      message: locationMessage,
                      onRetry: _loadCurrentLocation,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: KakaoMap(
                        center: location,
                        currentLevel: 3,
                        onMapCreated: (controller) {
                          mapController = controller;
                          _moveMap(location);
                        },
                      ),
                    ),
                  if (location != null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              '현재 위치',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Row(
                      children: [
                        Expanded(
                          child: MainBottomButton(
                            text: '분실물 검색',
                            icon: Icons.search,
                            colors: const [
                              Color(0xFFB000F5),
                              Color(0xFF7C3AED),
                            ],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LostSearchPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MainBottomButton(
                            text: '습득물 등록',
                            icon: Icons.add,
                            colors: const [
                              Color(0xFF2563EB),
                              Color(0xFF1D4ED8),
                            ],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FoundRegisterPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationLoadingMap extends StatelessWidget {
  const _LocationLoadingMap({
    required this.isLoading,
    required this.message,
    required this.onRetry,
  });

  final bool isLoading;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 86),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF2563EB),
                ),
              )
            else
              const Icon(
                Icons.location_off,
                color: Color(0xFFEF4444),
                size: 38,
              ),
            const SizedBox(height: 14),
            Text(
              isLoading ? '현재 위치를 불러오는 중입니다' : message ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isLoading) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('재시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MainBottomButton extends StatelessWidget {
  const MainBottomButton({
    super.key,
    required this.text,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
