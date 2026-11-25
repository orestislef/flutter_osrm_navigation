import 'package:latlong2/latlong.dart';

import 'geometry.dart';
import 'polyline.dart';

/// One maneuver of a route, in the shape OSRM sends it.
///
/// Valhalla answers in the same shape when asked with `format: osrm`, so a
/// step from either router reads the same.
class NavStep {
  /// Creates a step. Most of the time you get these from
  /// [NavRoute.fromOsrmJson].
  const NavStep({
    required this.maneuverType,
    this.modifier,
    required this.location,
    this.distanceM = 0,
    this.durationS = 0,
    this.streetName = '',
    this.ref = '',
    this.exit,
    this.drivingSide = 'right',
    this.routerInstruction,
    this.bearingAfter,
    this.legIndex = 0,
  });

  /// Reads one OSRM step object.
  ///
  /// A missing or short location becomes 0, 0 instead of failing the whole
  /// route.
  factory NavStep.fromOsrmJson(Map<String, dynamic> json, {int legIndex = 0}) {
    final maneuver = json['maneuver'] is Map
        ? Map<String, dynamic>.from(json['maneuver'] as Map)
        : const <String, dynamic>{};
    final loc = maneuver['location'];
    double at(int i) => loc is List && loc.length > 1 && loc[i] is num
        ? (loc[i] as num).toDouble()
        : 0;
    String text(Object? v) => v is String ? v : '';
    return NavStep(
      maneuverType: text(maneuver['type']).isEmpty
          ? 'turn'
          : text(maneuver['type']),
      modifier: maneuver['modifier'] is String
          ? maneuver['modifier'] as String
          : null,
      location: LatLng(at(1), at(0)),
      distanceM: ((json['distance'] as num?) ?? 0).toDouble(),
      durationS: ((json['duration'] as num?) ?? 0).toDouble(),
      streetName: text(json['name']),
      ref: text(json['ref']),
      exit: (maneuver['exit'] as num?)?.toInt(),
      drivingSide: text(json['driving_side']).isEmpty
          ? 'right'
          : text(json['driving_side']),
      routerInstruction: text(maneuver['instruction']).isEmpty
          ? null
          : text(maneuver['instruction']),
      bearingAfter: (maneuver['bearing_after'] as num?)?.toDouble(),
      legIndex: legIndex,
    );
  }

  /// OSRM's maneuver type: `depart`, `arrive`, `turn`, `new name`,
  /// `continue`, `merge`, `on ramp`, `off ramp`, `fork`, `end of road`,
  /// `roundabout`, `rotary`, `roundabout turn`, `exit roundabout`,
  /// `exit rotary`, `notification`.
  final String maneuverType;

  /// Direction of the maneuver: `uturn`, `sharp right`, `right`,
  /// `slight right`, `straight`, `slight left`, `left`, `sharp left`.
  final String? modifier;

  /// Where the maneuver happens.
  final LatLng location;

  /// Length of the step, from this maneuver to the next, in metres.
  final double distanceM;

  /// Expected time for the step, in seconds.
  final double durationS;

  /// Name of the road the step is on, empty when it has none.
  final String streetName;

  /// Road reference such as "A1" or "E75", empty when there is none.
  final String ref;

  /// Roundabout exit number (1 based) when the router gives it.
  final int? exit;

  /// `right` or `left`, the side of the road traffic keeps to here.
  final String drivingSide;

  /// The instruction text the router wrote, when it sends one. Valhalla
  /// does, OSRM does not.
  final String? routerInstruction;

  /// Direction of travel right after the maneuver, degrees from north.
  final double? bearingAfter;

  /// Which leg of the route the step belongs to (0 for the first).
  final int legIndex;

  /// The road to name in an instruction: the street, else its reference.
  String get road => streetName.isNotEmpty ? streetName : ref;

  /// True for the arrival at a stop or at the end.
  bool get isArrive => maneuverType == 'arrive';

  /// True for steps that are not a real action for the driver: the
  /// departure and a road that only changes its name.
  bool get isPassive => maneuverType == 'depart' || maneuverType == 'new name';

  /// True for the roundabout family of maneuvers.
  bool get isRoundabout =>
      maneuverType == 'roundabout' ||
      maneuverType == 'rotary' ||
      maneuverType == 'roundabout turn';

  /// True when the step turns the car around.
  bool get isUturn => modifier == 'uturn';
}

/// A route to drive: its line, its steps, its length and time.
class NavRoute {
  /// Creates a route from parts you already have.
  const NavRoute({
    required this.points,
    required this.steps,
    this.distanceM = 0,
    this.durationS = 0,
    this.waypoints = const [],
    this.speedLimitsKmh = const [],
  });

  /// Reads an OSRM shaped route.
  ///
  /// [json] can be the whole response (`{"code": "Ok", "routes": [...]}`)
  /// or a single route object. The geometry can be an encoded polyline or a
  /// GeoJSON LineString. With [precision] null the polyline precision (5 or
  /// 6) is worked out from where the first step starts.
  ///
  /// Steps of every leg are kept in order, so a route through stops
  /// navigates through all of them. The stops themselves are read from the
  /// response's `waypoints` when present, else from the arrivals of each leg
  /// but the last.
  ///
  /// Throws a [FormatException] when there is no route in [json].
  factory NavRoute.fromOsrmJson(Map<String, dynamic> json, {int? precision}) {
    Map<String, dynamic>? route;
    if (json['routes'] is List) {
      final routes = json['routes'] as List;
      if (routes.isNotEmpty && routes.first is Map) {
        route = Map<String, dynamic>.from(routes.first as Map);
      }
    } else if (json.containsKey('geometry') || json.containsKey('legs')) {
      route = json;
    }
    if (route == null) {
      throw FormatException('No route in the response (code: ${json['code']})');
    }

    final steps = <NavStep>[];
    final legs = route['legs'];
    if (legs is List) {
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final legSteps = leg is Map ? leg['steps'] : null;
        if (legSteps is! List) continue;
        for (final s in legSteps) {
          if (s is Map) {
            steps.add(
              NavStep.fromOsrmJson(Map<String, dynamic>.from(s), legIndex: i),
            );
          }
        }
      }
    }

    final points = _readGeometry(route['geometry'], precision, steps);

    var waypoints = <LatLng>[];
    final wps = json['waypoints'];
    if (wps is List && wps.length > 2) {
      for (var i = 1; i < wps.length - 1; i++) {
        final w = wps[i];
        final loc = w is Map ? w['location'] : null;
        if (loc is List && loc.length > 1 && loc[0] is num && loc[1] is num) {
          waypoints.add(
            LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          );
        }
      }
    }
    if (waypoints.isEmpty) {
      waypoints = [
        for (var i = 0; i < steps.length - 1; i++)
          if (steps[i].isArrive) steps[i].location,
      ];
    }

    return NavRoute(
      points: points,
      steps: steps,
      distanceM: ((route['distance'] as num?) ?? 0).toDouble(),
      durationS: ((route['duration'] as num?) ?? 0).toDouble(),
      waypoints: waypoints,
      speedLimitsKmh: _readSpeedLimits(legs, points.length),
    );
  }

  /// The `maxspeed` annotation of every leg, one entry per segment of the
  /// line, in km/h. Empty when the router did not send it for every leg or
  /// it does not line up with the line.
  static List<double?> _readSpeedLimits(Object? legs, int pointCount) {
    if (legs is! List || legs.isEmpty || pointCount < 2) return const [];
    final out = <double?>[];
    for (final leg in legs) {
      final annotation = leg is Map ? leg['annotation'] : null;
      final maxspeed = annotation is Map ? annotation['maxspeed'] : null;
      if (maxspeed is! List) return const [];
      for (final m in maxspeed) {
        out.add(m is Map ? _kmh(m) : null);
      }
    }
    if (out.length != pointCount - 1 || out.every((v) => v == null)) {
      return const [];
    }
    return List.unmodifiable(out);
  }

  /// `{"speed": 50, "unit": "km/h"}` in km/h. "unknown" and "none" (no
  /// limit, as on parts of the Autobahn) are null.
  static double? _kmh(Map m) {
    final speed = m['speed'];
    if (speed is! num || speed <= 0) return null;
    final unit = '${m['unit'] ?? 'km/h'}'.toLowerCase();
    return unit.startsWith('mph') ? speed * 1.609344 : speed.toDouble();
  }

  static List<LatLng> _readGeometry(
    Object? geometry,
    int? precision,
    List<NavStep> steps,
  ) {
    if (geometry is Map && geometry['coordinates'] is List) {
      return [
        for (final c in geometry['coordinates'] as List)
          if (c is List && c.length > 1 && c[0] is num && c[1] is num)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
    }
    if (geometry is! String) return const [];
    if (precision != null) {
      return decodePolyline(geometry, precision: precision);
    }
    // Read at the wrong precision a line lands ten times too far out (and
    // often off the world, so its points are dropped).
    final five = decodePolyline(geometry, precision: 5);
    final six = decodePolyline(geometry, precision: 6);
    if (six.isEmpty) return five;
    if (five.length < six.length) return six;
    if (steps.isEmpty) return five;
    final start = steps.first.location;
    return metresBetween(six.first, start) < metresBetween(five.first, start)
        ? six
        : five;
  }

  /// The line to draw and to follow.
  final List<LatLng> points;

  /// The maneuvers, every leg in order.
  final List<NavStep> steps;

  /// Total length in metres.
  final double distanceM;

  /// Expected total time in seconds.
  final double durationS;

  /// Stops between the start and the end, in order. Empty for a route
  /// with no stops.
  final List<LatLng> waypoints;

  /// The speed limit of each segment of [points] in km/h (segment `i` runs
  /// from `points[i]` to `points[i + 1]`), null where it is not known or
  /// there is none. Empty when the router sent no limits: OSRM sends them
  /// with `annotations=maxspeed` when its map data has them.
  final List<double?> speedLimitsKmh;

  /// Shorter than this, in metres, a route has no length to drive.
  static const double minLengthM = 1;

  /// Whether the line has any length to drive: at least [minLengthM] once
  /// points repeated right after themselves are merged. A route to the spot
  /// the car is already on comes back as the same point twice, and has none.
  bool get hasLength {
    final line = RouteLine(points);
    return !line.isEmpty && line.lengthM >= minLengthM;
  }

  /// True when there is a line with length and at least one step to follow.
  /// A route with no length ([hasLength] false) is not usable: there is
  /// nothing to drive.
  bool get usable => steps.isNotEmpty && hasLength;

  /// The end of the route.
  LatLng? get end => points.isNotEmpty
      ? points.last
      : (steps.isNotEmpty ? steps.last.location : null);
}
