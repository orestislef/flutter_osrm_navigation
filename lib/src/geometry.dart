import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Metres in one degree of latitude (and of longitude at the equator).
const double _metresPerDegree = 111319.49;

/// Where a position falls on a [RouteLine]: the nearest point of the line,
/// how far the position is from it, and how far along the line that point is.
class RouteMatch {
  /// Creates a match. You normally get one from [RouteLine.match].
  const RouteMatch({
    required this.distanceM,
    required this.alongM,
    required this.segment,
    required this.point,
    required this.bearing,
  });

  /// From the position to the line, in metres.
  final double distanceM;

  /// From the start of the line to [point], in metres.
  final double alongM;

  /// Index of the segment [point] is on, `points[segment]` to
  /// `points[segment + 1]`.
  final int segment;

  /// The nearest point of the line.
  final LatLng point;

  /// Direction of that segment, degrees clockwise from north (0 to 360).
  final double bearing;
}

/// A route as a line on the map, measured once.
///
/// Progress, off-route checks and the remaining line all work on the line
/// itself rather than on the maneuver points, so a long straight road with
/// no turns still tracks properly.
class RouteLine {
  RouteLine._(this.points, this._cumulative);

  /// Builds the line through [points]. A point repeated right after itself
  /// is kept once, since a zero length segment has no direction.
  factory RouteLine(List<LatLng> points) {
    final kept = <LatLng>[];
    for (final p in points) {
      if (kept.isEmpty ||
          kept.last.latitude != p.latitude ||
          kept.last.longitude != p.longitude) {
        kept.add(p);
      }
    }
    final cumulative = <double>[];
    var total = 0.0;
    for (var i = 0; i < kept.length; i++) {
      if (i > 0) total += metresBetween(kept[i - 1], kept[i]);
      cumulative.add(total);
    }
    return RouteLine._(List.unmodifiable(kept), cumulative);
  }

  /// The points of the line, without consecutive duplicates.
  final List<LatLng> points;
  final List<double> _cumulative;

  /// True when there is nothing to follow (fewer than two points).
  bool get isEmpty => points.length < 2;

  /// Total length in metres.
  double get lengthM => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Distance from the start to point [i], in metres.
  double alongAt(int i) => _cumulative[i];

  /// The first segment that ends at or after [alongM].
  int _segmentAt(double alongM) {
    if (points.length < 2) return 0;
    var lo = 0;
    var hi = points.length - 2;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulative[mid + 1] < alongM) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The point of the line nearest to [p].
  ///
  /// Only the part between [fromM] and [toM] along the line is searched when
  /// they are given. With [headingDeg], a segment running against it by more
  /// than 100 degrees counts [againstPenaltyM] farther away, so where a route
  /// uses the same street twice (there and back) the direction of travel
  /// picks the right pass.
  RouteMatch? match(
    LatLng p, {
    double? fromM,
    double? toM,
    double? headingDeg,
    double againstPenaltyM = 0,
  }) {
    if (isEmpty) return null;
    final first = fromM == null ? 0 : _segmentAt(fromM);
    final last = toM == null ? points.length - 2 : _segmentAt(toM);
    final cosLat = math.cos(p.latitude * math.pi / 180);
    RouteMatch? best;
    var bestScore = double.infinity;
    for (var i = first; i <= last; i++) {
      final a = points[i];
      final b = points[i + 1];
      // Flat metres around p, fine for the few kilometres one segment spans.
      final ax = (a.longitude - p.longitude) * cosLat * _metresPerDegree;
      final ay = (a.latitude - p.latitude) * _metresPerDegree;
      final bx = (b.longitude - p.longitude) * cosLat * _metresPerDegree;
      final by = (b.latitude - p.latitude) * _metresPerDegree;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);
      final bearing = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
      var score = d;
      if (headingDeg != null &&
          againstPenaltyM > 0 &&
          angleBetween(bearing, headingDeg) > 100) {
        score += againstPenaltyM;
      }
      if (score < bestScore) {
        bestScore = score;
        final along =
            _cumulative[i] + t * (_cumulative[i + 1] - _cumulative[i]);
        best = RouteMatch(
          distanceM: d,
          alongM: along,
          segment: i,
          point: LatLng(
            a.latitude + t * (b.latitude - a.latitude),
            a.longitude + t * (b.longitude - a.longitude),
          ),
          bearing: bearing,
        );
      }
    }
    return best;
  }

  /// The point [alongM] metres from the start, clamped to the ends.
  LatLng pointAt(double alongM) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1 || alongM <= 0) return points.first;
    if (alongM >= lengthM) return points.last;
    final i = _segmentAt(alongM);
    final span = _cumulative[i + 1] - _cumulative[i];
    final t = span <= 0 ? 0.0 : (alongM - _cumulative[i]) / span;
    final a = points[i];
    final b = points[i + 1];
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  /// Direction of the line at [alongM], degrees clockwise from north.
  double bearingAt(double alongM) {
    if (isEmpty) return 0;
    final i = _segmentAt(alongM.clamp(0, lengthM));
    return bearingBetween(points[i], points[i + 1]);
  }

  /// What is left of the line from [alongM] on, starting at that exact point.
  List<LatLng> remainingFrom(double alongM) {
    if (isEmpty || alongM <= 0) return points;
    if (alongM >= lengthM) return [points.last];
    final i = _segmentAt(alongM);
    return [pointAt(alongM), ...points.sublist(i + 1)];
  }

  /// The part of the line up to [alongM], ending at that exact point.
  List<LatLng> traveledTo(double alongM) {
    if (isEmpty || alongM <= 0) return const [];
    if (alongM >= lengthM) return points;
    final i = _segmentAt(alongM);
    return [...points.sublist(0, i + 1), pointAt(alongM)];
  }
}

/// Metres between two points on the earth (haversine).
double metresBetween(LatLng a, LatLng b) {
  const r = 6371008.8;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Direction from [a] to [b], degrees clockwise from north (0 to 360).
double bearingBetween(LatLng a, LatLng b) {
  final cosLat = math.cos(a.latitude * math.pi / 180);
  final dx = (b.longitude - a.longitude) * cosLat;
  final dy = b.latitude - a.latitude;
  return (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
}

/// The smaller angle between two directions, 0 to 180 degrees.
double angleBetween(double a, double b) {
  final d = ((a - b) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}

/// The point [metres] away from [from] towards [bearingDeg].
///
/// Flat earth math, meant for short distances like a look ahead or a test
/// track.
LatLng offsetBy(LatLng from, double bearingDeg, double metres) {
  final rad = bearingDeg * math.pi / 180;
  final dy = metres * math.cos(rad) / _metresPerDegree;
  final dx =
      metres *
      math.sin(rad) /
      (_metresPerDegree * math.cos(from.latitude * math.pi / 180));
  return LatLng(from.latitude + dy, from.longitude + dx);
}
