part of 'found_register_page.dart';

mixin _LocationRegionResolver {
  KakaoMapController? get _mapController;

  String _canonicalSido(String value) {
    const sidoMap = {
      '서울': '서울특별시',
      '서울특별시': '서울특별시',
      '부산': '부산광역시',
      '부산광역시': '부산광역시',
      '대구': '대구광역시',
      '대구광역시': '대구광역시',
      '인천': '인천광역시',
      '인천광역시': '인천광역시',
      '광주': '광주광역시',
      '광주광역시': '광주광역시',
      '대전': '대전광역시',
      '대전광역시': '대전광역시',
      '울산': '울산광역시',
      '울산광역시': '울산광역시',
      '세종': '세종특별자치시',
      '세종특별자치시': '세종특별자치시',
      '경기': '경기도',
      '경기도': '경기도',
      '강원': '강원특별자치도',
      '강원도': '강원특별자치도',
      '강원특별자치도': '강원특별자치도',
      '충북': '충청북도',
      '충청북도': '충청북도',
      '충남': '충청남도',
      '충청남도': '충청남도',
      '전북': '전북특별자치도',
      '전라북도': '전북특별자치도',
      '전북특별자치도': '전북특별자치도',
      '전남': '전라남도',
      '전라남도': '전라남도',
      '경북': '경상북도',
      '경상북도': '경상북도',
      '경남': '경상남도',
      '경상남도': '경상남도',
      '제주': '제주특별자치도',
      '제주도': '제주특별자치도',
      '제주특별자치도': '제주특별자치도',
    };

    return sidoMap[value.trim()] ?? value.trim();
  }

  Future<_RegionSelection> _resolveRegion(LatLng latLng) async {
    // 1차: Kakao Map SDK 자체 좌표 -> 행정구역 변환
    final controller = _mapController;
    if (controller != null) {
      try {
        final response = await controller
            .coord2RegionCode(
              Coord2RegionCodeRequest(x: latLng.longitude, y: latLng.latitude),
            )
            .timeout(const Duration(seconds: 3));

        Coord2RegionCode? selectedRegion;

        for (final region in response.list) {
          if (region.regionType == 'H') {
            selectedRegion = region;
            break;
          }
        }

        if (selectedRegion == null && response.list.isNotEmpty) {
          selectedRegion = response.list.first;
        }

        if (selectedRegion != null) {
          final result = _normalizeResolvedRegion(
            sidoRaw: selectedRegion.region1DepthName?.trim() ?? '',
            sigunguRaw: selectedRegion.region2DepthName?.trim() ?? '',
            eupmyeondongRaw: selectedRegion.region3DepthName?.trim() ?? '',
          );

          if (result.sido.isNotEmpty && result.sigungu.isNotEmpty) {
            return result;
          }
        }
      } catch (e) {
        debugPrint('Kakao coord2RegionCode 실패: $e');
      }
    }

    // 2차: 기기 reverse geocoding으로 재시도.
    // lost_search_page에서도 이미 geocoding 패키지를 사용하고 있으므로
    // REST API 키를 앱에 넣지 않고 지역명을 얻을 수 있다.
    try {
      final placemarks = await Geocoding(locale: const Locale('ko', 'KR'))
          .placemarkFromCoordinates(latLng.latitude, latLng.longitude)
          .timeout(const Duration(seconds: 6));

      for (final placemark in placemarks) {
        final sidoCandidates = <String>[
          placemark.administrativeArea ?? '',
          placemark.locality ?? '',
        ];

        String sido = '';
        for (final candidate in sidoCandidates) {
          final normalized = _canonicalSido(candidate);
          if (_isSupportedSido(normalized)) {
            sido = normalized;
            break;
          }
        }

        if (sido.isEmpty) {
          continue;
        }

        final sigunguCandidates = <String>[
          placemark.subAdministrativeArea ?? '',
          placemark.locality ?? '',
          placemark.subLocality ?? '',
          placemark.name ?? '',
        ];

        String sigungu = '';
        for (final candidate in sigunguCandidates) {
          sigungu = _normalizeSigunguForSearch(sido, candidate);
          if (sigungu.isNotEmpty) {
            break;
          }
        }

        String eupmyeondong = '';
        for (final candidate in <String>[
          placemark.subLocality ?? '',
          placemark.thoroughfare ?? '',
          placemark.name ?? '',
        ]) {
          final value = candidate.trim();
          if (_looksLikeEupmyeondong(value)) {
            eupmyeondong = value.split(' ').last;
            break;
          }
        }

        // 세종은 일반적인 시/군/구 2단계가 없어서 앱의 대표 지역 키를 세종시로 통일
        if (sido == '세종특별자치시' && sigungu.isEmpty) {
          sigungu = '세종시';
        }

        if (sigungu.isNotEmpty) {
          return _RegionSelection(
            sido: sido,
            sigungu: sigungu,
            eupmyeondong: eupmyeondong,
          );
        }
      }
    } catch (e) {
      debugPrint('reverse geocoding 실패: $e');
    }

    return _RegionSelection.empty;
  }

  _RegionSelection _normalizeResolvedRegion({
    required String sidoRaw,
    required String sigunguRaw,
    required String eupmyeondongRaw,
  }) {
    final sido = _canonicalSido(sidoRaw);

    if (!_isSupportedSido(sido)) {
      return _RegionSelection.empty;
    }

    var sigungu = _normalizeSigunguForSearch(sido, sigunguRaw);
    var eupmyeondong = eupmyeondongRaw.trim();

    if (sido == '세종특별자치시') {
      sigungu = '세종시';
      if (eupmyeondong.isEmpty && _looksLikeEupmyeondong(sigunguRaw)) {
        eupmyeondong = sigunguRaw.trim().split(' ').last;
      }
    }

    return _RegionSelection(
      sido: sido,
      sigungu: sigungu,
      eupmyeondong: eupmyeondong,
    );
  }

  bool _isSupportedSido(String value) {
    return const {
      '서울특별시',
      '부산광역시',
      '대구광역시',
      '인천광역시',
      '광주광역시',
      '대전광역시',
      '울산광역시',
      '세종특별자치시',
      '경기도',
      '강원특별자치도',
      '충청북도',
      '충청남도',
      '전북특별자치도',
      '전라남도',
      '경상북도',
      '경상남도',
      '제주특별자치도',
    }.contains(value);
  }

  String _normalizeSigunguForSearch(String sido, String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      return '';
    }

    if (sido == '세종특별자치시') {
      return '세종시';
    }

    final tokens = value.split(' ');

    final isMetro = const {
      '서울특별시',
      '부산광역시',
      '대구광역시',
      '인천광역시',
      '광주광역시',
      '대전광역시',
      '울산광역시',
    }.contains(sido);

    if (isMetro) {
      for (final token in tokens) {
        if (token.endsWith('구') || token.endsWith('군')) {
          return token;
        }
      }
    } else {
      // 도 단위 지역은 수원시 팔달구처럼 들어와도 검색 필터 기준은 수원시.
      for (final token in tokens) {
        if (token.endsWith('시') || token.endsWith('군')) {
          return token;
        }
      }

      // 제주도는 제주시/서귀포시가 locality 쪽에만 잡히는 경우가 있다.
      if (sido == '제주특별자치도') {
        for (final token in tokens) {
          if (token == '제주시' || token == '서귀포시') {
            return token;
          }
        }
      }
    }

    return '';
  }

  bool _looksLikeEupmyeondong(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return false;
    }

    final last = value.split(RegExp(r'\s+')).last;
    return last.endsWith('읍') ||
        last.endsWith('면') ||
        last.endsWith('동') ||
        last.endsWith('가') ||
        last.endsWith('리');
  }
}
