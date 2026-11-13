import 'package:latlong2/latlong.dart';

import 'geometry.dart';
import 'settings.dart';

/// One GPS fix as navigation reads it.
class NavFix {
  /// Creates a fix. [atMs] is a time on a clock that only goes forward;
  /// leave it out and the controller stamps the fix when it arrives.
  const NavFix(
    this.position, {
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    this.atMs,
  });

  /// Where.
  final LatLng position;

  /// How precise, in metres.
  final double? accuracyM;

  /// How fast, in metres per second.
  final double? speedMps;

  /// Which way, degrees clockwise from north.
  final double? headingDeg;

  /// When, in milliseconds on a clock that only goes forward.
  final int? atMs;

  /// A copy stamped at [atMs].
  NavFix at(int atMs) => NavFix(position,
      accuracyM: accuracyM,
      speedMps: speedMps,
      headingDeg: headingDeg,
      atMs: atMs);
}

/// What one fix says about the user and the route.
enum FixVerdict {
  /// Too imprecise, or a jump no car makes. Ignored.
  bad,

  /// Close to where the route starts or ends. Not checked.
  grace,

  /// Standing still, or the same fix again. Not counted either way.
  still,

  /// On the line.
  onRoute,

  /// Off the line, not yet for enough fixes in a row.
  offRoute,

  /// On the line but driving back along it.
  wrongWay,
}

/// Tells when the user left the route, two ways.
///
/// Off the line: the distance to the route line (not to the maneuver points)
/// less the fix's own error, over several fixes in a row while moving. Bad
/// fixes, standing still and the parts near the start and the end are left
/// out.
///
/// The wrong way: on the line but driving against it for several fixes,
/// while fast enough for the heading to count. A two way street drawn as one
/// line never takes the user off it, so this needs no distance, and it
/// counts from the very start since the first route may have been asked
/// while standing still with no heading.
class OffRouteDetector {
  /// Creates a detector with [settings].
  OffRouteDetector(this.settings);

  /// The thresholds in use.
  NavigationSettings settings;

  /// A gap this long without fixes (a tunnel) breaks a row of fixes.
  static const _rowBreakMs = 20000;

  /// Faster than this between two fixes is a GPS jump, not a car.
  static const _jumpMps = 70.0;

  /// Two fixes closer in time than this are the same fix again.
  static const _sameFixMs = 500;

  /// The direction of travel is read over at least this many metres (and
  /// twice the fix's error), so noise between two close fixes cannot turn
  /// it around.
  static const _travelBaseM = 15.0;

  static const _historyMax = 15;
  static const _historyMs = 15000;

  NavFix? _lastGood;
  final List<NavFix> _history = [];
  int? _lastCountedAt;
  int _offCount = 0;
  int _wrongWayCount = 0;

  /// The direction of travel: the fix's own while fast enough, else worked
  /// out from the last fixes.
  double? heading;

  /// Speed in m/s, from the fix or from the last two fixes.
  double? speed;

  /// True when the heading can be trusted.
  bool get headingReliable =>
      heading != null && (speed ?? 0) >= settings.headingMps;

  /// Off the line, or the wrong way, for enough fixes in a row.
  bool get offRoute => _offCount >= settings.offRouteFixes || wrongWay;

  /// Driving against the route for enough fixes in a row.
  bool get wrongWay => _wrongWayCount >= settings.wrongWayFixes;

  /// Fixes in a row off the line so far.
  int get offCount => _offCount;

  /// Forgets what was counted (a new route). The recent fixes stay, for the
  /// speed and the heading.
  void reset() {
    _offCount = 0;
    _wrongWayCount = 0;
    _lastCountedAt = null;
  }

  double? _travelBearing(NavFix fix, int atMs) {
    final acc2 = 2 * (fix.accuracyM ?? 0);
    final base = _travelBaseM > acc2 ? _travelBaseM : acc2;
    for (var i = _history.length - 1; i >= 0; i--) {
      final old = _history[i];
      if (atMs - old.atMs! > _historyMs) break;
      if (metresBetween(old.position, fix.position) >= base) {
        return bearingBetween(old.position, fix.position);
      }
    }
    return null;
  }

  /// Reads [fix] (stamped, [NavFix.atMs] set) against the route: [match] is
  /// its nearest point on [line], [destination] where the route ends.
  FixVerdict judge(
      NavFix fix, RouteMatch match, RouteLine line, LatLng destination) {
    final atMs = fix.atMs!;
    final accuracy = fix.accuracyM ?? 0;
    if (accuracy > settings.badFixMeters) return FixVerdict.bad;
    final last = _lastGood;
    double? implied;
    if (last != null) {
      final moved = metresBetween(last.position, fix.position);
      final dt = (atMs - last.atMs!) / 1000;
      if (dt > 0) implied = moved / dt;
      // A jump no car makes (a reflection off a building): ignored, the
      // last good fix stays.
      if (implied != null && implied > _jumpMps && dt < _rowBreakMs / 1000) {
        return FixVerdict.bad;
      }
      if (atMs - last.atMs! > _rowBreakMs) {
        reset();
        _history.clear();
      }
    }
    speed = fix.speedMps ?? implied ?? speed;
    final h = fix.headingDeg;
    if (h != null && h >= 0 && (speed ?? 0) >= settings.headingMps) {
      heading = h;
    } else {
      heading = _travelBearing(fix, atMs) ?? heading;
    }
    _lastGood = fix;
    _history.add(fix);
    if (_history.length > _historyMax) _history.removeAt(0);

    // Near the end: the place itself, or where the route ends when the
    // place is off the road. Turning around there is fine.
    if (metresBetween(fix.position, destination) < settings.endGraceMeters ||
        metresBetween(fix.position, line.points.last) <
            settings.endGraceMeters) {
      reset();
      return FixVerdict.grace;
    }
    final lastCounted = _lastCountedAt;
    if (lastCounted != null && atMs - lastCounted < _sameFixMs) {
      return offRoute ? FixVerdict.offRoute : FixVerdict.still;
    }

    final onLine = match.distanceM - accuracy <= settings.offRouteMeters;
    if (onLine && headingReliable) {
      _lastCountedAt = atMs;
      if (angleBetween(match.bearing, heading!) > settings.wrongWayDegrees) {
        _wrongWayCount++;
        _offCount = 0;
        return FixVerdict.wrongWay;
      }
      _wrongWayCount = 0;
    }

    if (metresBetween(fix.position, line.points.first) <
        settings.startGraceMeters) {
      _offCount = 0;
      return FixVerdict.grace;
    }
    if ((speed ?? 0) < settings.movingMps) return FixVerdict.still;
    _lastCountedAt = atMs;

    if (!onLine) {
      _offCount++;
      _wrongWayCount = 0;
      return FixVerdict.offRoute;
    }
    _offCount = 0;
    return FixVerdict.onRoute;
  }
}

/// When the next new route may be asked for: never two at once, never two
/// within [NavigationSettings.rerouteMinSeconds], and after failures a wait
/// that doubles up to [NavigationSettings.rerouteRetryMaxSeconds].
class RerouteGate {
  /// Creates a gate with [settings].
  RerouteGate(this.settings);

  /// The timings in use.
  NavigationSettings settings;

  bool _inFlight = false;
  int? _nextAt;
  int _failures = 0;

  /// A request is out.
  bool get inFlight => _inFlight;

  /// Failed requests in a row.
  int get failures => _failures;

  /// Whether a new route may be asked for at [nowMs].
  bool canAsk(int nowMs) =>
      !_inFlight && (_nextAt == null || nowMs >= _nextAt!);

  /// A request leaves at [nowMs].
  void asked(int nowMs) {
    _inFlight = true;
    _nextAt = nowMs + settings.rerouteMinSeconds * 1000;
  }

  /// The request came back at [nowMs], with a route or not.
  void answered(int nowMs, {required bool ok}) {
    _inFlight = false;
    if (ok) {
      _failures = 0;
      _nextAt = nowMs + settings.rerouteMinSeconds * 1000;
      return;
    }
    _failures++;
    var waitS =
        settings.rerouteMinSeconds * (1 << (_failures - 1).clamp(0, 10));
    if (waitS > settings.rerouteRetryMaxSeconds) {
      waitS = settings.rerouteRetryMaxSeconds;
    }
    if (waitS < settings.rerouteMinSeconds) waitS = settings.rerouteMinSeconds;
    _nextAt = nowMs + waitS * 1000;
  }

  /// Navigation started again: nothing waits.
  void reset() {
    _inFlight = false;
    _nextAt = null;
    _failures = 0;
  }
}
