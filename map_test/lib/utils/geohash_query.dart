import 'dart:math' as math;

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const double _earthMeridionalCircumference = 40007860;
const double _metersPerDegreeLatitude = 110574;
const int _maximumBitsPrecision = 22;

class GeohashQueryRange {
  const GeohashQueryRange(this.start, this.end);

  final String start;
  final String end;

  @override
  bool operator ==(Object other) {
    return other is GeohashQueryRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

String encodeGeohash(
  double latitude,
  double longitude, {
  int precision = 12,
}) {
  if (latitude < -90 || latitude > 90) {
    throw ArgumentError.value(latitude, 'latitude');
  }
  if (longitude < -180 || longitude > 180) {
    throw ArgumentError.value(longitude, 'longitude');
  }
  if (precision < 1 || precision > 22) {
    throw ArgumentError.value(precision, 'precision');
  }

  final latitudeRange = [-90.0, 90.0];
  final longitudeRange = [-180.0, 180.0];
  final result = StringBuffer();
  var currentValue = 0;
  var currentBit = 0;
  var useLongitude = true;

  while (result.length < precision) {
    final range = useLongitude ? longitudeRange : latitudeRange;
    final value = useLongitude ? longitude : latitude;
    final midpoint = (range[0] + range[1]) / 2;

    currentValue <<= 1;
    if (value >= midpoint) {
      currentValue++;
      range[0] = midpoint;
    } else {
      range[1] = midpoint;
    }

    useLongitude = !useLongitude;
    currentBit++;

    if (currentBit == 5) {
      result.write(_base32[currentValue]);
      currentBit = 0;
      currentValue = 0;
    }
  }

  return result.toString();
}

List<GeohashQueryRange> geohashQueryRanges({
  required double latitude,
  required double longitude,
  required double radiusMeters,
}) {
  if (radiusMeters <= 0) {
    throw ArgumentError.value(radiusMeters, 'radiusMeters');
  }

  final queryBits = math.max(
    1,
    _boundingBoxBits(latitude, radiusMeters),
  );
  final precision = (queryBits / 5).ceil();
  final ranges = <GeohashQueryRange>{};

  for (final coordinate in _boundingBoxCoordinates(
    latitude,
    longitude,
    radiusMeters,
  )) {
    final geohash = encodeGeohash(
      coordinate.$1,
      coordinate.$2,
      precision: precision,
    );
    ranges.add(_geohashQueryRange(geohash, queryBits));
  }

  return ranges.toList(growable: false);
}

int _boundingBoxBits(double latitude, double radiusMeters) {
  final latitudeDelta = radiusMeters / _metersPerDegreeLatitude;
  final latitudeNorth = math.min(90.0, latitude + latitudeDelta);
  final latitudeSouth = math.max(-90.0, latitude - latitudeDelta);

  final latitudeBits = _latitudeBitsForResolution(radiusMeters) * 2;
  final northLongitudeBits =
      _longitudeBitsForResolution(radiusMeters, latitudeNorth) * 2 - 1;
  final southLongitudeBits =
      _longitudeBitsForResolution(radiusMeters, latitudeSouth) * 2 - 1;

  return math.min(
    latitudeBits,
    math.min(northLongitudeBits, southLongitudeBits),
  );
}

int _latitudeBitsForResolution(double resolutionMeters) {
  return math.min(
    (_log2(_earthMeridionalCircumference / 2 / resolutionMeters)).floor(),
    _maximumBitsPrecision,
  );
}

int _longitudeBitsForResolution(
  double resolutionMeters,
  double latitude,
) {
  final degrees = _metersToLongitudeDegrees(resolutionMeters, latitude);
  if (degrees.abs() <= 0.000001) {
    return 1;
  }

  return math.min(
    math.max(1, _log2(360 / degrees).floor()),
    _maximumBitsPrecision,
  );
}

double _metersToLongitudeDegrees(double distanceMeters, double latitude) {
  final radians = latitude * math.pi / 180;
  final numerator = math.cos(radians) * _earthMeridionalCircumference;
  final denominator = 2 * math.pi;
  final metersPerDegree = numerator / denominator * math.pi / 180;

  if (metersPerDegree.abs() <= 0.000001) {
    return 360;
  }
  return math.min(360, distanceMeters / metersPerDegree);
}

List<(double, double)> _boundingBoxCoordinates(
  double latitude,
  double longitude,
  double radiusMeters,
) {
  final latitudeDelta = radiusMeters / _metersPerDegreeLatitude;
  final latitudeNorth = math.min(90.0, latitude + latitudeDelta);
  final latitudeSouth = math.max(-90.0, latitude - latitudeDelta);
  final northLongitudeDelta = _metersToLongitudeDegrees(
    radiusMeters,
    latitudeNorth,
  );
  final southLongitudeDelta = _metersToLongitudeDegrees(
    radiusMeters,
    latitudeSouth,
  );
  final centerLongitudeDelta = _metersToLongitudeDegrees(
    radiusMeters,
    latitude,
  );

  return [
    (latitude, longitude),
    (latitudeNorth, longitude),
    (latitudeNorth, _wrapLongitude(longitude + northLongitudeDelta)),
    (latitude, _wrapLongitude(longitude + centerLongitudeDelta)),
    (latitudeSouth, _wrapLongitude(longitude + southLongitudeDelta)),
    (latitudeSouth, longitude),
    (latitudeSouth, _wrapLongitude(longitude - southLongitudeDelta)),
    (latitude, _wrapLongitude(longitude - centerLongitudeDelta)),
    (latitudeNorth, _wrapLongitude(longitude - northLongitudeDelta)),
  ];
}

GeohashQueryRange _geohashQueryRange(String geohash, int bits) {
  final precision = (bits / 5).ceil();
  if (geohash.length < precision) {
    return GeohashQueryRange(geohash, '$geohash~');
  }

  final hash = geohash.substring(0, precision);
  final base = hash.substring(0, hash.length - 1);
  final lastValue = _base32.indexOf(hash[hash.length - 1]);
  final significantBits = bits - (precision - 1) * 5;
  final unusedBits = 5 - significantBits;
  final startValue = (lastValue >> unusedBits) << unusedBits;
  final endValue = startValue + (1 << unusedBits);

  final start = '$base${_base32[startValue]}';
  final end = endValue > 31 ? '$base~' : '$base${_base32[endValue]}';
  return GeohashQueryRange(start, end);
}

double _wrapLongitude(double longitude) {
  if (longitude >= -180 && longitude <= 180) {
    return longitude;
  }
  return ((longitude + 180) % 360 + 360) % 360 - 180;
}

double _log2(double value) => math.log(value) / math.ln2;
