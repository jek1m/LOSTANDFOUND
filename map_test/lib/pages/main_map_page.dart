import 'dart:async';

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

class _ItemLocationGroup {
  const _ItemLocationGroup({required this.location, required this.items});

  final LatLng location;
  final List<LostItem> items;
}

class _MainMapPageState extends State<MainMapPage> {
  static const int _mapQueryReadLimit = 100;
  static const int _mapDisplayLimit = 50;
  static const String _currentLocationMarkerId = '__current_location__';
  static const double _mapControlWidth = 48;
  static const String _currentLocationMarkerImage =
      'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%2232%22%20height=%2240%22%20viewBox=%220%200%2032%2040%22%3E%3Cpath%20d=%22M16%201C7.72%201%201%207.72%201%2016c0%2010.8%2015%2023%2015%2023s15-12.2%2015-23C31%207.72%2024.28%201%2016%201z%22%20fill=%22%232563EB%22%20stroke=%22%231D4ED8%22%20stroke-width=%222%22/%3E%3Ccircle%20cx=%2216%22%20cy=%2216%22%20r=%226%22%20fill=%22%23DBEAFE%22/%3E%3C/svg%3E';
  static const String _policeMarkerImage =
      'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%2232%22%20height=%2240%22%20viewBox=%220%200%2032%2040%22%3E%3Cpath%20d=%22M16%201C7.72%201%201%207.72%201%2016c0%2010.8%2015%2023%2015%2023s15-12.2%2015-23C31%207.72%2024.28%201%2016%201z%22%20fill=%22%230F766E%22%20stroke=%22%23FFFFFF%22%20stroke-width=%222%22/%3E%3Ccircle%20cx=%2216%22%20cy=%2216%22%20r=%225%22%20fill=%22%23FFFFFF%22/%3E%3C/svg%3E';
  static const String _appMarkerImage =
      'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22%20width=%2232%22%20height=%2240%22%20viewBox=%220%200%2032%2040%22%3E%3Cpath%20d=%22M16%201C7.72%201%201%207.72%201%2016c0%2010.8%2015%2023%2015%2023s15-12.2%2015-23C31%207.72%2024.28%201%2016%201z%22%20fill=%22%23F97316%22%20stroke=%22%23FFFFFF%22%20stroke-width=%222%22/%3E%3Ccircle%20cx=%2216%22%20cy=%2216%22%20r=%225%22%20fill=%22%23FFFFFF%22/%3E%3C/svg%3E';

  KakaoMapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isLoadingItems = false;
  String? _locationMessage;
  String? _itemsMessage;
  List<LostItem> _nearbyItems = const [];
  int _nearbyRequestId = 0;
  int _mapInstanceId = 0;
  Timer? _viewportDebounce;

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
  }

  Future<void> _restoreMapAfterNavigation() async {
    if (!mounted) {
      return;
    }

    // KakaoMap의 웹뷰 컨트롤러는 다른 페이지를 다녀온 뒤 유효하지 않을 수 있다.
    // 새 지도 인스턴스를 만들고, 위치와 마커 데이터를 다시 적용한다.
    setState(() {
      _mapController = null;
      _mapInstanceId++;
    });
    await _loadCurrentLocation();
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

  void _onCameraIdle() {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 400), () async {
      final controller = _mapController;
      if (controller == null) {
        return;
      }
      await _loadVisibleItems(await controller.getBounds());
    });
  }

  Future<void> _refreshVisibleItems() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    await _loadVisibleItems(await controller.getBounds());
  }

  Future<void> _loadVisibleItems(LatLngBounds bounds) async {
    final requestId = ++_nearbyRequestId;
    setState(() {
      _isLoadingItems = true;
      _itemsMessage = null;
    });

    try {
      final southWest = bounds.getSouthWest();
      final northEast = bounds.getNorthEast();
      final centerLatitude = (southWest.latitude + northEast.latitude) / 2;
      final centerLongitude = (southWest.longitude + northEast.longitude) / 2;
      final radiusMeters = Geolocator.distanceBetween(
        centerLatitude,
        centerLongitude,
        northEast.latitude,
        northEast.longitude,
      );
      final ranges = geohashQueryRanges(
        latitude: centerLatitude,
        longitude: centerLongitude,
        radiusMeters: radiusMeters,
      );
      final snapshots = await Future.wait(
        ranges.map(
          (range) => FirebaseFirestore.instance
              .collection('found_items')
              .orderBy('geohash')
              .startAt([range.start])
              .endBefore([range.end])
              .limit(_mapQueryReadLimit)
              .get(),
        ),
      );
      final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final snapshot in snapshots)
          for (final document in snapshot.docs) document.id: document,
      };
      final items =
          documents.values
              .map(LostItem.fromDoc)
              .where((item) => _isWithinBounds(item, bounds))
              .toList(growable: false)
            ..sort((a, b) {
              final aDate = a.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

      if (!mounted || requestId != _nearbyRequestId) {
        return;
      }

      // 플러그인은 빈 마커 목록으로 갱신될 때 이전 마커를 자동 제거하지 않는다.
      _mapController?.clearMarker();
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

  Marker? _currentLocationMarker() {
    final location = _currentLocation;
    if (location == null) {
      return null;
    }

    return Marker(
      markerId: _currentLocationMarkerId,
      latLng: location,
      width: 32,
      height: 40,
      markerImageSrc: _currentLocationMarkerImage,
      zIndex: 100,
    );
  }

  List<Marker> _markersFromItems(List<LostItem> items) {
    final groups = _itemLocationGroups(items);
    return groups
        .asMap()
        .entries
        .map(
          (entry) => Marker(
            markerId: '__lost_location_${entry.key}',
            latLng: entry.value.location,
            width: 32,
            height: 40,
            markerImageSrc: entry.value.items.first.isAppRegistered
                ? _appMarkerImage
                : _policeMarkerImage,
            zIndex: 50,
          ),
        )
        .toList(growable: false);
  }

  List<_ItemLocationGroup> _itemLocationGroups(List<LostItem> items) {
    final groupedItems = <String, List<LostItem>>{};
    for (final item in items) {
      final key =
          '${item.latitude!.toStringAsFixed(6)},'
          '${item.longitude!.toStringAsFixed(6)}';
      groupedItems.putIfAbsent(key, () => []).add(item);
    }
    return groupedItems.values
        .map(
          (group) => _ItemLocationGroup(
            location: LatLng(group.first.latitude!, group.first.longitude!),
            items: group,
          ),
        )
        .toList(growable: false);
  }

  void _openItemLocationGroup(List<LostItem> items, String markerId) {
    const markerPrefix = '__lost_location_';
    if (!markerId.startsWith(markerPrefix)) {
      return;
    }
    final index = int.tryParse(markerId.substring(markerPrefix.length));
    final groups = _itemLocationGroups(items);
    if (index == null || index < 0 || index >= groups.length) {
      return;
    }

    final group = groups[index];
    if (group.items.length == 1) {
      _openItemDetail(group.items.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: group.items.length + 1,
          itemBuilder: (context, itemIndex) {
            if (itemIndex == 0) {
              return ListTile(title: Text('이 위치의 습득물 ${group.items.length}개'));
            }
            final item = group.items[itemIndex - 1];
            return ListTile(
              title: Text(item.fdPrdtNm),
              subtitle: Text(item.fndPlace ?? ''),
              onTap: () {
                Navigator.pop(context);
                _openItemDetail(item);
              },
            );
          },
        ),
      ),
    );
  }

  void _openItemDetail(LostItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LostItemDetailPage(item: item)),
    );
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

  bool _isWithinBounds(LostItem item, LatLngBounds bounds) {
    if (!_hasValidLocation(item)) {
      return false;
    }
    final southWest = bounds.getSouthWest();
    final northEast = bounds.getNorthEast();
    return item.latitude! >= southWest.latitude &&
        item.latitude! <= northEast.latitude &&
        item.longitude! >= southWest.longitude &&
        item.longitude! <= northEast.longitude;
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    super.dispose();
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
                      key: ValueKey('main-kakao-map-$_mapInstanceId'),
                      center: _currentLocation ?? _fallbackCenter,
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
                        _openItemLocationGroup(_nearbyItems, markerId);
                      },
                      onCameraIdle: (_, _) => _onCameraIdle(),
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
                            onPressed:
                                _isLoadingLocation || _currentLocation == null
                                ? null
                                : _moveToCurrentLocation,
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
                            onTap: () async {
                              DetectedSearchRegion? initialRegion;
                              try {
                                initialRegion =
                                    await _detectSearchRegionWithKakaoMap(
                                      requestPermission: false,
                                    );
                              } catch (_) {
                                // 검색 화면에서 기기 위치 기반 자동 설정을 한 번 더 시도한다.
                              }
                              if (!mounted) {
                                return;
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LostSearchPage(
                                    initialDetectedRegion: initialRegion,
                                    autoDetectLocation: initialRegion == null,
                                    regionDetector:
                                        _detectSearchRegionWithKakaoMap,
                                  ),
                                ),
                              );
                              await _restoreMapAfterNavigation();
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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FoundRegisterPage(),
                                ),
                              );
                              await _restoreMapAfterNavigation();
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
              onPressed: _refreshVisibleItems,
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapStatusCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 7),
                Text(
                  '현재 지도 영역 · ${_nearbyItems.length}개',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _mapStatusCard(
            child: InkWell(
              onTap: _isLoadingItems || _isLoadingLocation
                  ? null
                  : _refreshVisibleItems,
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

  /*
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

  */
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
