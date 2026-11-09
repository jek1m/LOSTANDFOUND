import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as geo;
import 'package:geolocator/geolocator.dart';
import 'package:map_test/pages/lost_search_page.dart';

class _TestLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 37.478,
    longitude: 126.952,
    timestamp: DateTime(2026),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _TestGeocoding extends geo.Geocoding {
  _TestGeocoding() : super.implementation(geo.GeocodingCreationParams());

  List<geo.Placemark> results = [];
  Locale? requestedLocale;
  bool fail = false;

  @override
  Future<List<geo.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async {
    requestedLocale = locale;
    if (fail) {
      throw StateError('Address lookup failed');
    }
    return results;
  }
}

class _TestGeocodingFactory extends geo.GeocodingPlatformFactory {
  _TestGeocodingFactory(this.geocoder);
  final _TestGeocoding geocoder;

  @override
  geo.Geocoding createGeocoding(geo.GeocodingCreationParams params) => geocoder;
}

void main() {
  late _TestGeocoding geocoder;
  final originalLocation = GeolocatorPlatform.instance;
  final originalGeocoding = geo.GeocodingPlatformFactory.instance;

  setUp(() {
    geocoder = _TestGeocoding();
    GeolocatorPlatform.instance = _TestLocation();
    geo.GeocodingPlatformFactory.instance = _TestGeocodingFactory(geocoder);
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalLocation;
    // The plugin's setter does not accept null; this test file uses an isolated runner.
    if (originalGeocoding != null) {
      geo.GeocodingPlatformFactory.instance = originalGeocoding;
    }
  });

  Future<void> openPage(
    WidgetTester tester, {
    SearchRegionDetector? detector,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: LostSearchPage(regionDetector: detector)),
    );
    await tester.pumpAndSettle();
  }

  void expectGwanakSelected() {
    expect(find.widgetWithText(ExpansionTile, '서울특별시'), findsOneWidget);
    expect(find.widgetWithText(ExpansionTile, '관악구'), findsOneWidget);
    expect(find.text('시·군·구를 선택하세요'), findsNothing);
  }

  testWidgets('한국어를 조회 함수에 전달하고 두 번째 주소의 관악구를 선택한다', (tester) async {
    geocoder.results = const [
      geo.Placemark(administrativeArea: '서울시'),
      geo.Placemark(administrativeArea: '서울시', subLocality: '관악구'),
    ];
    await openPage(tester);
    expect(geocoder.requestedLocale, const Locale('ko', 'KR'));
    expectGwanakSelected();
  });

  testWidgets('카카오에서 서울만 받으면 도로명 주소로 관악구를 보완한다', (tester) async {
    geocoder.results = const [geo.Placemark(street: '서울시 관악구 관악로 1')];
    await openPage(
      tester,
      detector: ({required requestPermission}) async =>
          const DetectedSearchRegion(region: '서울시'),
    );
    expectGwanakSelected();
  });

  testWidgets('보완 조회가 실패해도 확인한 서울은 유지하고 직접 선택을 안내한다', (tester) async {
    geocoder.fail = true;
    await openPage(
      tester,
      detector: ({required requestPermission}) async =>
          const DetectedSearchRegion(region: '서울시'),
    );
    expect(find.widgetWithText(ExpansionTile, '서울특별시'), findsOneWidget);
    expect(find.text('시·군·구를 선택하세요'), findsOneWidget);
    expect(find.textContaining('시·군·구는 확인하지 못해'), findsOneWidget);
  });

  testWidgets('카카오에서 서울 관악구를 모두 받으면 기기 주소를 추가 조회하지 않는다', (tester) async {
    await openPage(
      tester,
      detector: ({required requestPermission}) async =>
          const DetectedSearchRegion(region: '서울시', subregion: '관악구'),
    );
    expectGwanakSelected();
    expect(geocoder.requestedLocale, isNull);
  });
}
