import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../lost_models/lost_item.dart';
import 'found_register_page.dart';
import 'lost_item_detail_page.dart';
import 'lost_search_page.dart';

class MainMapPage extends StatefulWidget {
  const MainMapPage({super.key});

  @override
  State<MainMapPage> createState() => _MainMapPageState();
}

class _MainMapPageState extends State<MainMapPage> {
  KakaoMapController? _mapController;
  bool _hasCenteredOnItems = false;

  final LatLng center = LatLng(37.5665, 126.9780); // 임시 중심 좌표

  Stream<QuerySnapshot<Map<String, dynamic>>> get _foundItemsStream =>
      FirebaseFirestore.instance.collection('found_items').snapshots();

  List<Marker> _markersFromItems(List<LostItem> items) {
    return items
        .map(
          (item) => Marker(
            markerId: item.atcId,
            latLng: LatLng(item.latitude!, item.longitude!),
            width: 30,
            height: 38,
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

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void _centerOnFirstItem(List<Marker> markers) {
    if (_hasCenteredOnItems || markers.isEmpty || _mapController == null) {
      return;
    }

    _hasCenteredOnItems = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController?.setCenter(markers.first.latLng);
      _mapController?.setLevel(5);
    });
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
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _foundItemsStream,
                      builder: (context, snapshot) {
                        final items = snapshot.hasData
                            ? snapshot.data!.docs
                                  .map(LostItem.fromDoc)
                                  .where(_hasValidLocation)
                                  .toList(growable: false)
                            : <LostItem>[];
                        final markers = _markersFromItems(items);
                        _centerOnFirstItem(markers);

                        return KakaoMap(
                          center: center,
                          markers: markers,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _centerOnFirstItem(markers);
                          },
                          onMarkerTap: (markerId, _, _) {
                            _openItemDetail(items, markerId);
                          },
                        );
                      },
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
