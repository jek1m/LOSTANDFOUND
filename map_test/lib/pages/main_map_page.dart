import 'package:flutter/material.dart';
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

  final LatLng center = LatLng(37.5665, 126.9780); // 임시 중심 좌표

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
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            // 지도 영역
            Expanded(
              child: Stack(
                children: [
                  // 실제 카카오맵
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: KakaoMap(
                      center: center,
                      onMapCreated: (controller) {
                        mapController = controller;
                      },
                    ),
                  ),

                  // 기능 연결 전 임시 마커 UI
                  const IgnorePointer(
                    child: Stack(
                      children: [
                        MapPin(top: 85, left: 135, color: Color(0xFFEF4444)),
                        MapPin(top: 120, left: 78, color: Color(0xFF14B8A6)),
                        MapPin(top: 140, right: 105, color: Color(0xFFFF7A00)),
                        MapPin(top: 180, left: 110, color: Color(0xFFFF9800)),
                        MapPin(top: 205, right: 145, color: Color(0xFF374151)),
                        MapPin(top: 240, left: 155, color: Color(0xFFFB7185)),
                        MapPin(top: 260, right: 100, color: Color(0xFF8B5CF6)),
                        MapPin(top: 315, left: 95, color: Color(0xFF10B981)),
                        MapPin(top: 350, right: 80, color: Color(0xFF06B6D4)),
                        MapPin(bottom: 135, left: 135, color: Color(0xFFE91E63)),
                        MapPin(bottom: 90, right: 120, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),

                  // 현재 위치 표시
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
                                color: Colors.black.withOpacity(0.18),
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
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            '내 위치',
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
                                  builder: (context) => const FoundRegisterPage(),
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

// 지도 위 임시 위치 마커
class MapPin extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Color color;

  const MapPin({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Icon(
        Icons.location_on,
        size: 38,
        color: color,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
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
              color: colors.last.withOpacity(0.35),
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