// A navigation on a test clock with a router that answers as the test says,
// and the simulated routes and drives the tests run on. No network, no
// timers: the clock moves one second per fix.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:latlong2/latlong.dart';

import 'tracks.dart';

export 'tracks.dart';

/// A voice that writes down what it says, in a state the test sets.
class RecordingVoice implements NavigationVoice {
  final said = <String>[];
  VoiceState current = VoiceState.ready;

  @override
  VoiceState get state => current;
  @override
  set onStateChanged(void Function()? callback) {}
  @override
  Future<void> init() async {}
  @override
  Future<void> prepare(String language) async {}
  @override
  void say(String text, String language) => said.add(text);
  @override
  void stop() {}
}

/// One GPS fix of a simulated drive.
class SimFix {
  const SimFix(
    this.position, {
    this.speed,
    this.heading,
    this.accuracy = 8,
    this.gapS = 1,
  });

  final LatLng position;
  final double? speed;
  final double? heading;
  final double accuracy;

  /// Seconds since the fix before.
  final int gapS;
}

/// Drives along [path] at [speed] m/s, one fix a second, each off the path
/// by up to [noiseM] metres (seeded, so a run is the same every time).
List<SimFix> drive(
  List<LatLng> path, {
  double speed = 10,
  double noiseM = 0,
  double accuracy = 8,
  int seed = 7,
}) {
  final line = RouteLine(path);
  final random = math.Random(seed);
  final out = <SimFix>[];
  for (var along = speed; along <= line.lengthM + 0.01; along += speed) {
    var p = line.pointAt(along);
    final bearing = line.bearingAt(along);
    if (noiseM > 0) {
      p = offsetBy(p, random.nextDouble() * 360, random.nextDouble() * noiseM);
    }
    out.add(SimFix(p, speed: speed, heading: bearing, accuracy: accuracy));
  }
  return out;
}

/// One OSRM shaped step.
NavStep navStep(
  String type,
  LatLng at,
  double distance,
  double duration, {
  String? modifier,
  String street = '',
  int leg = 0,
}) => NavStep(
  maneuverType: type,
  modifier: modifier,
  location: at,
  distanceM: distance,
  durationS: duration,
  streetName: street,
  legIndex: leg,
);

/// A route along [parts] (bearing, metres, the street of that leg) from
/// [from]: a departure, a turn at each corner (left or right from the change
/// of bearing, a U-turn when it goes straight back) and the arrival, at
/// 10 m/s. [stopsAfter] puts a stop at the end of those parts (indexes).
NavRoute navRoute(
  LatLng from,
  List<(double, double, String)> parts, {
  Set<int> stopsAfter = const {},
}) {
  final points = legs(from, [for (final (b, m, _) in parts) (b, m)]);
  final steps = <NavStep>[];
  final waypoints = <LatLng>[];
  var here = from;
  var leg = 0;
  for (var i = 0; i < parts.length; i++) {
    final (bearing, metres, street) = parts[i];
    if (i == 0 || stopsAfter.contains(i - 1)) {
      steps.add(
        navStep('depart', here, metres, metres / 10, street: street, leg: leg),
      );
    } else {
      final turn = ((bearing - parts[i - 1].$1) % 360 + 360) % 360;
      if (turn == 180) {
        steps.add(
          navStep(
            'continue',
            here,
            metres,
            metres / 10,
            modifier: 'uturn',
            street: street,
            leg: leg,
          ),
        );
      } else {
        steps.add(
          navStep(
            'turn',
            here,
            metres,
            metres / 10,
            modifier: turn < 180 ? 'right' : 'left',
            street: street,
            leg: leg,
          ),
        );
      }
    }
    here = offsetBy(here, bearing, metres);
    if (stopsAfter.contains(i)) {
      steps.add(navStep('arrive', here, 0, 0, street: street, leg: leg));
      waypoints.add(here);
      leg++;
    }
  }
  steps.add(navStep('arrive', here, 0, 0, street: parts.last.$3, leg: leg));
  final length = parts.fold<double>(0, (s, p) => s + p.$2);
  return NavRoute(
    points: points,
    steps: steps,
    distanceM: length,
    durationS: length / 10,
    waypoints: waypoints,
  );
}

/// The test route: 600 m east on Egnatia, left 500 m north on Agias Sofias,
/// right 400 m east on Ermou to the end.
NavRoute testRoute() => navRoute(trackStart, [
  (90, 600, 'Egnatia'),
  (0, 500, 'Agias Sofias'),
  (90, 400, 'Ermou'),
]);

/// The test route's corners: A (the left turn), B (the right turn), D (the
/// end).
final cornerA = offsetBy(trackStart, 90, 600);
final cornerB = offsetBy(cornerA, 0, 500);
final endD = offsetBy(cornerB, 90, 400);

/// One request for a new route.
class Asked {
  Asked(this.request, this.at);
  final RouteRequest request;
  final int at;

  LatLng get from => request.points.first;
  LatLng get to => request.points.last;
  double? get heading => request.headingDeg;
}

/// One navigation on a test clock.
class Drive {
  Drive({
    NavigationSettings settings = const NavigationSettings(),
    NavigationStrings strings = const EnglishNavigationStrings(),
  }) {
    nav = NavigationController(
      settings: settings,
      strings: strings,
      voice: voice,
      clock: () => now,
    );
    events = [];
    nav.events.listen(events.add);
  }

  final voice = RecordingVoice();
  late final NavigationController nav;
  late final List<NavigationEvent> events;
  int now = 0;

  /// Each request for a new route.
  final asked = <Asked>[];

  /// The new route the router gives (null: none, as when it fails).
  NavRoute? Function(LatLng from)? answer;

  /// Requests wait here until the test completes them.
  bool hold = false;
  final waiting = <Completer<NavRoute?>>[];

  int? answeredAt;

  void start(
    NavRoute route, {
    ArrivalType arrival = ArrivalType.destination,
    String? name,
    Future<double?> Function(RouteRequest r)? eta,
    LatLng? destination,
  }) {
    nav.router = CallbackRouter(
      route: (request) async {
        asked.add(Asked(request, now));
        NavRoute? r;
        if (hold) {
          final c = Completer<NavRoute?>();
          waiting.add(c);
          r = await c.future;
        } else {
          answeredAt = now;
          r = answer?.call(request.points.first);
        }
        if (r == null) throw const RoutingException('no route');
        return r;
      },
      eta: eta,
    );
    nav.start(
      route,
      arrival: arrival,
      destinationName: name,
      destination: destination,
    );
  }

  /// Feeds [fixes], letting each request come back before the next fix.
  Future<void> feed(Iterable<SimFix> fixes) async {
    for (final f in fixes) {
      now += f.gapS * 1000;
      nav.updateLocation(
        NavFix(
          f.position,
          accuracyM: f.accuracy,
          speedMps: f.speed,
          headingDeg: f.heading,
        ),
      );
      await settle();
    }
  }

  /// Answers the oldest waiting request with [route].
  Future<void> complete(NavRoute? route) async {
    answeredAt = now;
    waiting.removeAt(0).complete(route);
    await settle();
  }

  static Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.value();
    }
  }
}

/// The whole test route as a path.
List<LatLng> routePath() => testPath();
