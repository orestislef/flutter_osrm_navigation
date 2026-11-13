import 'package:latlong2/latlong.dart';

/// Decodes an encoded polyline into points.
///
/// [precision] is 5 for OSRM's `polyline` and 6 for `polyline6` (Valhalla's
/// native shape uses 6 as well).
///
/// The decoder only uses arithmetic, no bitwise not. On the web ints are
/// JavaScript numbers and `~x` comes out as an unsigned 32 bit value, which
/// turns every step south or west into a jump of thousands of degrees.
///
/// Points outside the world are dropped, and a truncated string keeps
/// whatever was decoded before the cut.
List<LatLng> decodePolyline(String? encoded, {int precision = 5}) {
  final points = <LatLng>[];
  if (encoded == null || encoded.isEmpty) return points;
  var factor = 1.0;
  for (var i = 0; i < precision; i++) {
    factor *= 10;
  }
  var index = 0;
  var lat = 0;
  var lng = 0;

  // The next signed value, or null at the end or in a cut string.
  int? next() {
    var shift = 0;
    var result = 0;
    while (true) {
      if (index >= encoded.length) return null;
      final b = encoded.codeUnitAt(index++) - 63;
      if (b < 0) return null;
      result += (b % 32) * (1 << shift);
      shift += 5;
      if (b < 32) break;
      if (shift > 30) return null;
    }
    // Zigzag: odd values are negative.
    return result.isOdd ? -((result + 1) ~/ 2) : result ~/ 2;
  }

  while (index < encoded.length) {
    final dLat = next();
    final dLng = dLat == null ? null : next();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    final la = lat / factor;
    final lo = lng / factor;
    if (la >= -90 && la <= 90 && lo >= -180 && lo <= 180) {
      points.add(LatLng(la, lo));
    }
  }
  return points;
}

/// Encodes [points] as a polyline with [precision] decimals (5 or 6).
String encodePolyline(List<LatLng> points, {int precision = 5}) {
  var factor = 1.0;
  for (var i = 0; i < precision; i++) {
    factor *= 10;
  }
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;

  void put(int v) {
    var value = v < 0 ? (-v * 2) - 1 : v * 2;
    while (value >= 32) {
      out.writeCharCode((32 + value % 32) + 63);
      value ~/= 32;
    }
    out.writeCharCode(value + 63);
  }

  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    put(lat - lastLat);
    put(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}
