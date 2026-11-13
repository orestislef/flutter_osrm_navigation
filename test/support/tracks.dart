// Simulated routes and GPS tracks for the tests: straight streets around a
// start point, OSRM shaped steps for them, and drives along any path at a
// given speed, one fix a second, with optional GPS noise.
import 'dart:math' as math;

import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:latlong2/latlong.dart';

/// Where the test routes start.
const trackStart = LatLng(40.6300, 22.9400);

/// A path of straight legs from [from]. Each part is (bearing in degrees,
/// metres), with a point every [every] metres.
List<LatLng> legs(LatLng from, List<(double, double)> parts,
    {double every = 20}) {
  final out = <LatLng>[from];
  var here = from;
  for (final (bearing, metres) in parts) {
    final n = math.max(1, (metres / every).round());
    final end = offsetBy(here, bearing, metres);
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      out.add(LatLng(
        here.latitude + (end.latitude - here.latitude) * t,
        here.longitude + (end.longitude - here.longitude) * t,
      ));
    }
    here = end;
  }
  return out;
}

/// The test path: 600 m east, 500 m north, 400 m east.
List<LatLng> testPath() => legs(trackStart, [(90, 600), (0, 500), (90, 400)]);
