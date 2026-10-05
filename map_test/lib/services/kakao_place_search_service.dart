import 'dart:async';
import 'dart:convert';

import 'package:kakao_map_plugin/kakao_map_plugin.dart';

class KakaoPlaceSearchResult {
  const KakaoPlaceSearchResult({required this.places, required this.hasNext});

  final List<KeywordAddress> places;
  final bool hasNext;
}

class KakaoPlaceSearchService {
  KakaoPlaceSearchService.withJavaScript({
    required Future<void> Function(String) run,
    required Future<Object> Function(String) evaluate,
  }) : _run = run,
       _evaluate = evaluate;

  final Future<void> Function(String) _run;
  final Future<Object> Function(String) _evaluate;
  int _requestId = 0;
  bool _disposed = false;

  Future<void> initialize() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      final ready = await _evaluate('window.foundPlaceSearchReady === true');
      if (ready == true || ready.toString() == 'true') {
        await _run('window.foundPlaceSearchResults = {};');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_disposed) throw StateError('검색 화면이 닫혔습니다.');
    throw TimeoutException('카카오 장소 검색 SDK 초기화 시간이 초과되었습니다.');
  }

  Future<KakaoPlaceSearchResult> search(String keyword, {int page = 1}) async {
    if (_disposed) throw StateError('검색 화면이 닫혔습니다.');
    final id = ++_requestId;
    await _run('''
        window.foundPlaceSearchResults[$id] = null;
        new kakao.maps.services.Places().keywordSearch(
          ${jsonEncode(keyword)},
          function(result, status, pagination) {
            if (!Object.prototype.hasOwnProperty.call(window.foundPlaceSearchResults, $id)) return;
            window.foundPlaceSearchResults[$id] = {
              status: status || 'ERROR',
              places: status === kakao.maps.services.Status.OK ? result : [],
              hasNext: !!(pagination && pagination.hasNext)
            };
          },
          {page: $page, size: 15}
        );
      ''');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    try {
      while (!_disposed && DateTime.now().isBefore(deadline)) {
        final raw = await _evaluate(
          'JSON.stringify(window.foundPlaceSearchResults[$id] || null)',
        );
        dynamic data = raw is String ? jsonDecode(raw) : raw;
        // Android may return a JSON-encoded string; iOS returns its contents.
        if (data is String) data = jsonDecode(data);
        if (data is Map) {
          if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULT') {
            throw StateError('카카오 장소 검색에 실패했습니다 (${data['status']}).');
          }
          return KakaoPlaceSearchResult(
            places: (data['places'] as List)
                .map(
                  (place) => KeywordAddress.fromJson(
                    Map<String, dynamic>.from(place as Map),
                  ),
                )
                .toList(),
            hasNext: data['hasNext'] == true,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      throw TimeoutException('장소 검색 시간이 초과되었습니다.');
    } finally {
      if (!_disposed) {
        try {
          await _run('delete window.foundPlaceSearchResults[$id];');
        } catch (_) {
          // Do not replace the original result if the map has been closed.
        }
      }
    }
  }

  void dispose() {
    _disposed = true;
  }
}
