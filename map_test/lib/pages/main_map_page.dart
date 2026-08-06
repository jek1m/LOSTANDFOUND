import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../lost_models/lost_item.dart';
import '../utils/current_position.dart';
import '../utils/geohash_query.dart';
import 'found_register_page.dart';
import 'lost_item_detail_page.dart';
import 'lost_search_page.dart';

class MainMapPage extends StatefulWidget {
  const MainMapPage({super.key});

  @override
  State<MainMapPage> createState() => _MainMapPageState();
}

class _MainMapPageState extends State<MainMapPage> {
  static const int _mapQueryReadLimit = 80;
  static const int _mapDisplayLimit = 50;
  static const List<double> _nearbyRadiusOptions = [3000, 5000];
  static const String _nearbyRadiusCircleId = '__nearby_radius__';
  static const String _currentLocationMarkerId = '__current_location__';
  static const double _mapControlWidth = 48;
  static const String _lostItemMarkerImage =
      'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%2232%22%20height=%2240%22%20viewBox=%220%200%2032%2040%22%3E%3Cpath%20d=%22M16%201C7.72%201%201%207.72%201%2016c0%2010.8%2015%2023%2015%2023s15-12.2%2015-23C31%207.72%2024.28%201%2016%201z%22%20fill=%22%23FACC15%22%20stroke=%22%23A16207%22%20stroke-width=%222%22/%3E%3Ccircle%20cx=%2216%22%20cy=%2216%22%20r=%226%22%20fill=%22%23FFF7CC%22/%3E%3C/svg%3E';

  KakaoMapController? _mapController;
  LatLng? _currentLocation;
  double _nearbyRadiusMeters = _nearbyRadiusOptions.first;
  bool _isLoadingLocation = true;
  bool _isLoadingItems = false;
  String? _locationMessage;
  String? _itemsMessage;
  List<LostItem> _nearbyItems = const [];
  int _nearbyRequestId = 0;

  final LatLng _fallbackCenter = LatLng(37.5665, 126.9780);

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationMessage = null;
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLocationFailure('위치 서비스가 꺼져 있습니다. 기기 위치를 켜주세요.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationFailure('주변 습득물을 보려면 위치 권한을 허용해 주세요.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationFailure('앱 설정에서 위치 권한을 허용해 주세요.');
        return;
      }

      final position = await getReliableCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
        _isLoadingLocation = false;
        _locationMessage = null;
      });
      _moveToCurrentLocation();
      await _loadNearbyItems();
    } catch (_) {
      _setLocationFailure('현재 위치를 가져오지 못했습니다. 다시 시도해 주세요.');
    }
  }

  void _setLocationFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingLocation = false;
      _locationMessage = message;
    });
  }

  void _moveToCurrentLocation() {
    final location = _currentLocation;
    if (location == null) {
      _loadCurrentLocation();
      return;
    }
    _mapController?.setCenter(location);
    _mapController?.fitBounds(_nearbyRadiusBounds(location));
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final level = await controller.getLevel();
    if (level > 1) {
      controller.setLevel(level - 1);
    }
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final level = await controller.getLevel();
    if (level < 14) {
      controller.setLevel(level + 1);
    }
  }

  Future<void> _changeNearbyRadius(double radius) async {
    if (_nearbyRadiusMeters == radius) {
      return;
    }
    setState(() {
      _nearbyRadiusMeters = radius;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveToCurrentLocation();
    });
    await _loadNearbyItems();
  }

  Future<void> _loadNearbyItems() async {
    final location = _currentLocation;
    if (location == null) {
      return;
    }

    final requestId = ++_nearbyRequestId;
    setState(() {
      _isLoadingItems = true;
      _itemsMessage = null;
    });

    try {
      final ranges = geohashQueryRanges(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusMeters: _nearbyRadiusMeters,
      );
      final documents =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      var remainingReadLimit = _mapQueryReadLimit;

      for (var index = 0;
          index < ranges.length && remainingReadLimit > 0;
          index++) {
        final remainingRanges = ranges.length - index;
        final rangeReadLimit = (remainingReadLimit / remainingRanges).ceil();
        final range = ranges[index];
        final snapshot = await FirebaseFirestore.instance
            .collection('found_items')
            .orderBy('geohash')
            .startAt([range.start])
            .endBefore([range.end])
            .limit(rangeReadLimit)
            .get();

        for (final document in snapshot.docs) {
          documents[document.id] = document;
        }
        remainingReadLimit -= snapshot.docs.length;
      }

      final items = documents.values
          .map(LostItem.fromDoc)
          .where(_isNearby)
          .toList(growable: false)
        ..sort((a, b) {
          final aDate = a.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      if (!mounted || requestId != _nearbyRequestId) {
        return;
      }

      setState(() {
        _nearbyItems = items.take(_mapDisplayLimit).toList(growable: false);
        _isLoadingItems = false;
        _itemsMessage = null;
      });
    } on FirebaseException catch (error) {
      _setItemsFailure(
        requestId,
        error.code == 'failed-precondition'
            ? '주변 조회에 필요한 Firestore 인덱스를 확인해 주세요.'
            : '주변 습득물을 불러오지 못했습니다.',
      );
    } catch (_) {
      _setItemsFailure(requestId, '주변 습득물을 불러오지 못했습니다.');
    }
  }

  void _setItemsFailure(int requestId, String message) {
    if (!mounted || requestId != _nearbyRequestId) {
      return;
    }
    setState(() {
      _isLoadingItems = false;
      _itemsMessage = message;
    });
  }

  Future<DetectedSearchRegion?> _detectSearchRegionWithKakaoMap({
    required bool requestPermission,
  }) async {
    final controller = _mapController;
    final location = _currentLocation;
    if (controller == null || location == null) {
      return null;
    }

    final response = await controller
        .coord2RegionCode(
          Coord2RegionCodeRequest(x: location.longitude, y: location.latitude),
        )
        .timeout(const Duration(seconds: 10));
    if (response.list.isEmpty) {
      return null;
    }

    final administrative = response.list.where(
      (result) => result.regionType == 'H',
    );
    final result = administrative.isNotEmpty
        ? administrative.first
        : response.list.first;
    final region = _normalizeSearchRegion(result.region1DepthName);
    if (region == null) {
      return null;
    }

    final subregion = region == '세종특별자치시'
        ? result.region3DepthName
        : result.region2DepthName;
    return DetectedSearchRegion(
      region: region,
      subregion: (subregion?.trim().isEmpty ?? true) ? null : subregion!.trim(),
    );
  }

  String? _normalizeSearchRegion(String? value) {
    final region = value?.trim();
    if (region == null || region.isEmpty) {
      return null;
    }
    const aliases = {'강원특별자치도': '강원도', '전라북도': '전북특별자치도'};
    return aliases[region] ?? region;
  }

  List<LatLng> _nearbyRadiusBounds(LatLng center) {
    const metersPerLatitudeDegree = 111320.0;
    final latitudeDelta = _nearbyRadiusMeters / metersPerLatitudeDegree;
    final latitudeRadians = center.latitude * math.pi / 180;
    final longitudeDelta =
        _nearbyRadiusMeters /
        (metersPerLatitudeDegree * math.cos(latitudeRadians));

    return [
      LatLng(center.latitude + latitudeDelta, center.longitude),
      LatLng(center.latitude - latitudeDelta, center.longitude),
      LatLng(center.latitude, center.longitude + longitudeDelta),
      LatLng(center.latitude, center.longitude - longitudeDelta),
    ];
  }

  List<Circle> _nearbyRadiusCircle() {
    final location = _currentLocation;
    if (location == null) {
      return const [];
    }

    return [
      Circle(
        circleId: _nearbyRadiusCircleId,
        center: location,
        radius: _nearbyRadiusMeters,
        strokeWidth: 2,
        strokeColor: const Color(0xFF2563EB),
        strokeOpacity: 0.75,
        fillColor: const Color(0xFF60A5FA),
        fillOpacity: 0.13,
        zIndex: 1,
      ),
    ];
  }

  Marker? _currentLocationMarker() {
    final location = _currentLocation;
    if (location == null) {
      return null;
    }

    return Marker(
      markerId: _currentLocationMarkerId,
      latLng: location,
      zIndex: 100,
    );
  }

  List<Marker> _markersFromItems(List<LostItem> items) {
    return items
        .map(
          (item) => Marker(
            markerId: item.atcId,
            latLng: LatLng(item.latitude!, item.longitude!),
            width: 32,
            height: 40,
            markerImageSrc: _lostItemMarkerImage,
            zIndex: 50,
            infoWindowContent:
                '<div style="padding:8px 12px;white-space:nowrap;">'
                '${_escapeHtml(item.fdPrdtNm)}</div>',
          ),
        )
        .toList(growable: false);
  }

  void _openItemDetail(List<LostItem> items, String markerId) {
    for (final item in items) {
      if (item.atcId == markerId) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LostItemDetailPage(item: item),
          ),
        );
        return;
      }
    }
  }

  bool _hasValidLocation(LostItem item) {
    final latitude = item.latitude;
    final longitude = item.longitude;
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  bool _isNearby(LostItem item) {
    final location = _currentLocation;
    if (location == null || !_hasValidLocation(item)) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      item.latitude!,
      item.longitude!,
    );
    return distance <= _nearbyRadiusMeters;
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 제목 영역
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
                    '앱이름',
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

            // 지도 영역
            Expanded(
              child: Stack(
                children: [
                  // 실제 카카오맵
                  Positioned.fill(
                    child: KakaoMap(
                      center: _currentLocation ?? _fallbackCenter,
                      circles: _nearbyRadiusCircle(),
                      markers: [
                        ?_currentLocationMarker(),
                        ..._markersFromItems(_nearbyItems),
                      ],
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_currentLocation != null) {
                          _moveToCurrentLocation();
                        }
                      },
                      onMarkerTap: (markerId, _, _) {
                        _openItemDetail(_nearbyItems, markerId);
                      },
                    ),
                  ),

                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _locationStatusCard(),
                  ),

                  Positioned(
                    right: 18,
                    bottom: 92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.white,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: _mapControlWidth,
                            child: Column(
                              children: [
                                IconButton(
                                  onPressed: _zoomIn,
                                  tooltip: '확대',
                                  icon: const Icon(Icons.add),
                                ),
                                const SizedBox(
                                  width: 28,
                                  child: Divider(height: 1),
                                ),
                                IconButton(
                                  onPressed: _zoomOut,
                                  tooltip: '축소',
                                  icon: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox.square(
                          dimension: _mapControlWidth,
                          child: FloatingActionButton(
                            heroTag: 'move_to_current_location',
                            onPressed: _isLoadingLocation
                                ? null
                                : _loadCurrentLocation,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2563EB),
                            tooltip: '내 위치로 이동',
                            child: _isLoadingLocation
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 하단 버튼 영역
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
                                  builder: (context) => LostSearchPage(
                                    regionDetector:
                                        _detectSearchRegionWithKakaoMap,
                                  ),
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

  Widget _locationStatusCard() {
    if (_isLoadingLocation) {
      return _mapStatusCard(
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('현재 위치를 확인하고 있습니다.'),
          ],
        ),
      );
    }

    final message = _locationMessage;
    if (message != null) {
      return _mapStatusCard(
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: _loadCurrentLocation,
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    final itemsMessage = _itemsMessage;
    if (itemsMessage != null) {
      return _mapStatusCard(
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(child: Text(itemsMessage)),
            TextButton(
              onPressed: _loadNearbyItems,
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    final radiusKm = (_nearbyRadiusMeters / 1000).round();
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<double>(
            tooltip: '주변 범위 선택',
            onSelected: _changeNearbyRadius,
            itemBuilder: (context) => _nearbyRadiusOptions.map((radius) {
              final optionKm = (radius / 1000).round();
              return PopupMenuItem<double>(
                value: radius,
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: radius == _nearbyRadiusMeters
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Color(0xFF2563EB),
                            )
                          : null,
                    ),
                    Text('반경 $optionKm km'),
                  ],
                ),
              );
            }).toList(),
            child: _mapStatusCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 7),
                  Text(
                    '내 주변 ${radiusKm}km · ${_nearbyItems.length}개',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _mapStatusCard(
            child: InkWell(
              onTap: _isLoadingItems || _isLoadingLocation
                  ? null
                  : _loadCurrentLocation,
              child: _isLoadingItems
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapStatusCard({required Widget child}) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: child,
      ),
    );
  }
}

// 하단 메인 버튼
class MainBottomButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const MainBottomButton({
    super.key,
    required this.text,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

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
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
