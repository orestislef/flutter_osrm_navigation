import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'events.dart';
import 'geometry.dart';
import 'off_route.dart';
import 'route.dart';
import 'router.dart';
import 'settings.dart';
import 'strings.dart';
import 'voice/voice.dart';

/// Turn-by-turn navigation along a route, with the voice.
///
/// Feed it GPS fixes with [updateLocation] (or [attachLocation]) and it
/// keeps track of where the user is on the route line, what the next
/// maneuver is and how far it is, the distance and time left, and speaks
/// each maneuver far, near and at the turn.
///
/// When the user leaves the route (off the line for a few fixes, the wrong
/// way along it, or past a U-turn they did not take) it asks the [router]
/// for a new one from where they are, starting the way they are heading.
/// One request at a time, with a backoff after failures, and the old route
/// stays until a new one arrives.
///
/// It is a [ChangeNotifier]: listen to it to redraw the banner and the map.
/// Discrete things that happen (arrival, a stop reached, a reroute) also
/// come through [events].
///
/// Everything runs in Dart on the fixes it gets, so it keeps working with
/// the app in the background for as long as the platform keeps delivering
/// location updates. See `NavigationLocation` for that part.
class NavigationController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [router] is needed for [navigateTo] and for rerouting. [strings] picks
  /// the language, English by default. [voice] defaults to the device's
  /// text to speech. [clock] is for tests: milliseconds on a clock that
  /// only goes forward.
  NavigationController({
    this.router,
    NavigationSettings settings = const NavigationSettings(),
    this._strings = const EnglishNavigationStrings(),
    NavigationVoice? voice,
    this._voiceEnabled = true,
    @visibleForTesting int Function()? clock,
  }) : _settings = settings,
       _voice = voice ?? TtsNavigationVoice(),
       _clock = clock ?? _monotonicMs {
    _detector = OffRouteDetector(settings);
    _gate = RerouteGate(settings);
  }

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static int _monotonicMs() => _stopwatch.elapsedMilliseconds;

  /// Where new routes come from.
  NavRouter? router;

  final NavigationVoice _voice;
  final int Function() _clock;
  late final OffRouteDetector _detector;
  late final RerouteGate _gate;
  final StreamController<NavigationEvent> _events =
      StreamController<NavigationEvent>.broadcast();
  StreamSubscription<NavFix>? _locationSub;
  bool _disposed = false;

  NavigationSettings _settings;
  NavigationStrings _strings;
  bool _voiceEnabled;

  // The route.
  NavRoute? _route;
  List<NavStep> _steps = const [];
  RouteLine? _line;
  List<double> _maneuverAlong = const [];
  LatLng? _destination;
  String? _destinationName;
  ArrivalType _arrival = ArrivalType.destination;
  double _routeDurationS = 0;

  // The speed limit of each segment of the route line, and the last one
  // reported.
  List<double?> _segmentLimits = const [];
  double? _lastLimit;
  double _trafficFactor = 1;

  // Stops still ahead, with where they are along the line.
  List<LatLng> _waypoints = const [];
  List<double> _waypointAlong = const [];
  int _nextWaypoint = 0;
  int _waypointsPassed = 0;

  // The GPS signal: when a fix last came, and when one was last used.
  int? _lastFixAt;
  int? _lastUsedAt;
  int _startedAt = 0;
  GpsSignal _gps = GpsSignal.good;

  // Progress.
  NavFix? _lastFix;
  double? _heading;
  double _along = 0;
  RouteMatch? _lastMatch;
  int _upcoming = 0;
  int? _then;
  double _distanceToNext = 0;
  bool _active = false;
  bool _arrived = false;
  bool _recalculating = false;
  bool _offRoute = false;
  bool _saidRecalculating = false;
  int _routeSeq = 0;
  int? _lastEtaAt;
  bool _etaInFlight = false;

  // Prompts said per step: 1 far, 2 near, 3 at the maneuver.
  final Map<int, int> _stage = {};
  bool _arrivingSpoken = false;
  bool _arrivedSpoken = false;
  int? _lastSpeakAt;

  /// A maneuver this far behind is done.
  static const _passedM = 10.0;

  // ── Settings, language, voice ────────────────────────────────────────

  /// The thresholds in use. Can be changed while navigating.
  NavigationSettings get settings => _settings;
  set settings(NavigationSettings value) {
    _settings = value;
    _detector.settings = value;
    _gate.settings = value;
    if (_steps.isNotEmpty) _then = _thenOf(_upcoming);
    _notify();
  }

  /// The words shown and said. Can be changed while navigating.
  NavigationStrings get strings => _strings;
  set strings(NavigationStrings value) {
    _strings = value;
    unawaited(_voice.prepare(value.speechLanguage));
    _notify();
  }

  /// Whether the voice can speak.
  VoiceState get voiceState => _voice.state;

  /// Why the voice cannot speak, or may not speak well: no engine on the
  /// device, no voice for the language, a voice not downloaded, no speech on
  /// this platform. Show the user what to do, then call [recheckVoice] when
  /// the app comes back.
  VoiceProblem get voiceProblem {
    final v = _voice;
    if (v is DiagnosableVoice) return (v as DiagnosableVoice).problem;
    return v.state == VoiceState.unavailable
        ? VoiceProblem.unknown
        : VoiceProblem.none;
  }

  /// Looks at the voice again, after the user installed an engine or a
  /// voice (call it when the app is resumed).
  Future<void> recheckVoice() async {
    final v = _voice;
    if (v is DiagnosableVoice) {
      await (v as DiagnosableVoice).recheck(_strings.speechLanguage);
    } else {
      await v.prepare(_strings.speechLanguage);
    }
    _notify();
  }

  /// Whether the user wants the voice. Muting stops what is being said.
  bool get voiceEnabled => _voiceEnabled;
  set voiceEnabled(bool value) {
    if (value == _voiceEnabled) return;
    _voiceEnabled = value;
    if (!value) _voice.stop();
    _notify();
  }

  /// Gets the voice ready. Call once, early (before navigating) so the
  /// first prompt is not lost while the engine starts.
  Future<void> initVoice() async {
    _voice.onStateChanged = _notify;
    await _voice.init();
    await _voice.prepare(_strings.speechLanguage);
    _notify();
  }

  /// For the "tap for voice" button in a browser: the tap itself unlocked
  /// the voice, and it says so, so the user hears it works.
  void unlockVoice() {
    _voiceEnabled = true;
    _notify();
    // The page sees the tap before Flutter does, give it that moment.
    Future<void>.delayed(
      const Duration(milliseconds: 150),
      () => _speak(_strings.voiceOn, force: true),
    );
  }

  // ── State ────────────────────────────────────────────────────────────

  /// Discrete things that happen: start, stop, off route, reroutes, stops
  /// and the destination reached, prompts spoken.
  Stream<NavigationEvent> get events => _events.stream;

  /// True while navigating.
  bool get isActive => _active;

  /// The route being followed. It changes on a reroute.
  NavRoute? get route => _route;

  /// The steps of the route being followed.
  List<NavStep> get steps => _steps;

  /// Where the route ends.
  LatLng? get destination => _destination;

  /// The name given to [start], if any.
  String? get destinationName => _destinationName;

  /// What the route ends at.
  ArrivalType get arrival => _arrival;

  /// True once the user reached the end of the route.
  bool get arrived => _arrived;

  /// A new route is on its way.
  bool get recalculating => _recalculating;

  /// The user is off the route. A new one is asked for, or will be.
  bool get offRoute => _offRoute;

  /// The last fix received, navigating or not.
  NavFix? get lastFix => _lastFix;

  /// Speed in m/s, from the GPS or worked out from the last fixes.
  double get speedMps =>
      (_active ? _detector.speed : null) ?? _lastFix?.speedMps ?? 0;

  /// Index of the next real maneuver in [steps] (not the departure, not a
  /// road changing its name).
  int get upcomingIndex => _upcoming;

  /// The next real maneuver.
  NavStep? get upcomingStep => _steps.isEmpty ? null : _steps[_upcoming];

  /// The maneuver right after the next one, when it comes within
  /// [NavigationSettings.thenMeters].
  NavStep? get thenStep => _then == null ? null : _steps[_then!];

  /// Metres to the next maneuver, along the route.
  double get distanceToNextStep => _distanceToNext;

  /// The text for the next maneuver, "Turn left onto Main Street".
  String? get upcomingInstruction {
    final step = upcomingStep;
    return step == null ? null : instructionFor(_upcoming);
  }

  /// The text for [thenStep].
  String? get thenInstruction => _then == null ? null : instructionFor(_then!);

  /// The text for step [index] of [steps].
  String instructionFor(int index) =>
      _strings.instruction(_steps[index], arrival: _arrivalOf(index));

  /// Metres left along the route.
  double get remainingDistance =>
      _line == null ? 0 : math.max(0, _line!.lengthM - _along);

  /// Time left, from the route's times and the router's latest estimate.
  Duration get remainingDuration => Duration(
    milliseconds: (_routeSecondsFrom(_along) * _trafficFactor * 1000).round(),
  );

  /// When the user should arrive, by the device's clock.
  DateTime? get estimatedArrival =>
      _active ? DateTime.now().add(remainingDuration) : null;

  /// The route as a measured line, null when not navigating.
  RouteLine? get routeLine => _line;

  /// How far along [routeLine] the user is, in metres.
  double get progressMeters => _along;

  /// The line still ahead. The part behind is not part of it.
  List<LatLng> get remainingLine =>
      _line == null ? const [] : _line!.remainingFrom(_along);

  /// The line already driven.
  List<LatLng> get traveledLine =>
      _line == null ? const [] : _line!.traveledTo(_along);

  /// Stops not reached yet, in order.
  List<LatLng> get remainingWaypoints => _waypoints.length <= _nextWaypoint
      ? const []
      : _waypoints.sublist(_nextWaypoint);

  /// Where the position is drawn while navigating close to the line: on
  /// the line. Null otherwise.
  LatLng? get snappedPosition {
    final m = _lastMatch;
    if (!_active ||
        m == null ||
        _offRoute ||
        _settings.snapMeters <= 0 ||
        m.distanceM > _settings.snapMeters) {
      return null;
    }
    return m.point;
  }

  /// The direction of the road under the position while it is drawn on the
  /// line and moving, so the map turns with the road and not with a shaky
  /// GPS heading.
  double? get roadBearing {
    if (snappedPosition == null || speedMps < _settings.movingMps) return null;
    return _lastMatch!.bearing;
  }

  /// The speed limit of the road under the car in km/h, from the router
  /// (OSRM's `maxspeed`). Null when the router sent none, the road has
  /// none, or the car is off the route.
  double? get speedLimitKmh {
    final m = _lastMatch;
    if (!_active || m == null || _offRoute || _segmentLimits.isEmpty) {
      return null;
    }
    if (m.distanceM > _settings.offRouteMeters) return null;
    return m.segment < _segmentLimits.length ? _segmentLimits[m.segment] : null;
  }

  /// Faster than [speedLimitKmh] by more than
  /// [NavigationSettings.speedingToleranceKmh].
  bool get speeding {
    final limit = speedLimitKmh;
    return limit != null &&
        speedMps * 3.6 > limit + _settings.speedingToleranceKmh;
  }

  /// How the GPS is doing while navigating: [GpsSignal.weak] when fixes
  /// come but are all too rough to use, [GpsSignal.lost] when none came
  /// for [NavigationSettings.gpsLostSeconds]. Kept up to date by
  /// [checkGps], which `NavigationMap` and `NavigationBanner` call every
  /// second.
  GpsSignal get gpsSignal => _gps;

  /// Works out [gpsSignal] for now and reports a change. Call it every
  /// second or so when you show navigation without the package's
  /// widgets: a lost signal is the absence of fixes, so nothing else
  /// would notice it.
  void checkGps() {
    if (_disposed) return;
    final now = _clock();
    final limit = _settings.gpsLostSeconds * 1000;
    var signal = GpsSignal.good;
    if (_active && limit > 0) {
      final lastFix = _lastFixAt ?? _startedAt;
      final lastUsed = _lastUsedAt ?? _startedAt;
      if (now - lastFix > limit) {
        signal = GpsSignal.lost;
      } else if (now - lastUsed > limit) {
        signal = GpsSignal.weak;
      }
    }
    if (signal == _gps) return;
    _gps = signal;
    _emit(GpsSignalChanged(signal));
    _notify();
  }

  /// Where to draw the position: on the line when close to it, else the
  /// last fix.
  LatLng? get displayPosition => snappedPosition ?? _lastFix?.position;

  /// Which way to draw the position and turn the map: the road while on it
  /// and moving, else the last heading that was trusted.
  double? get displayHeading => roadBearing ?? _heading;

  // ── Location ─────────────────────────────────────────────────────────

  /// Listens to [fixes] until [detachLocation], [dispose], or another
  /// stream is attached. Errors on the stream (permission taken away,
  /// location switched off) go to [onError] and do not end navigation.
  void attachLocation(
    Stream<NavFix> fixes, {
    void Function(Object error)? onError,
  }) {
    _locationSub?.cancel();
    _locationSub = fixes.listen(
      updateLocation,
      onError: (Object e) {
        onError?.call(e);
      },
    );
  }

  /// Stops listening to the attached location stream.
  void detachLocation() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  /// One GPS fix. Call it for every fix, navigating or not, so the position
  /// is known when navigation starts.
  void updateLocation(NavFix fix) {
    if (_disposed) return;
    final now = _clock();
    final stamped = fix.atMs == null ? fix.at(now) : fix;
    _lastFix = stamped;
    final h = stamped.headingDeg;
    if (h != null && h >= 0 && (stamped.speedMps ?? 0) > 0.8) _heading = h;

    final line = _line;
    final destination = _destination;
    if (!_active || _steps.isEmpty || line == null || destination == null) {
      // Started arrived, with no line: the fix still counts for the signal.
      if (_active) {
        _lastFixAt = now;
        _lastUsedAt = now;
      }
      _notify();
      return;
    }
    _lastFixAt = now;
    final match = _matchFix(stamped, line);
    final verdict = _detector.judge(stamped, match, line, destination);
    if (verdict == FixVerdict.bad) {
      checkGps();
      _notify();
      return;
    }
    _lastUsedAt = now;
    checkGps();
    if (_detector.headingReliable) _heading = _detector.heading;
    _lastMatch = match;
    final position = stamped.position;
    final onLine =
        match.distanceM - (stamped.accuracyM ?? 0) <= _settings.offRouteMeters;
    if (onLine) _along = match.alongM;

    _checkWaypoints(position, onLine);

    if (!_arrived &&
        (metresBetween(position, destination) <= _settings.arriveMeters ||
            (onLine && line.lengthM - _along <= _settings.arriveMeters))) {
      _arrived = true;
      _emit(const DestinationReached());
    } else if (_arrived) {
      // Drove on, well away from the place and the end of the route: not
      // there any more, and off the route (a new route back).
      final away = (_settings.endGraceMeters + _settings.offRouteMeters)
          .toDouble();
      if (metresBetween(position, destination) > away &&
          metresBetween(position, line.points.last) > away) {
        _arrived = false;
        _arrivingSpoken = false;
        _arrivedSpoken = false;
      }
    }

    final wasOff = _offRoute;
    _offRoute =
        (_detector.offRoute ||
            _missedUturn(stamped, match, line, destination)) &&
        !_arrived;
    if (_offRoute != wasOff) _emit(OffRouteChanged(_offRoute));
    if (!_offRoute && !_recalculating) _saidRecalculating = false;
    if (_offRoute &&
        _settings.rerouteEnabled &&
        router != null &&
        _gate.canAsk(now)) {
      unawaited(_rerouteFrom(stamped));
    }

    final previousStep = _upcoming;
    _upcoming = _upcomingFrom(_along);
    _then = _thenOf(_upcoming);
    _distanceToNext = math.max(0, _maneuverAlong[_upcoming] - _along);
    if (_upcoming != previousStep) {
      _emit(StepChanged(_upcoming, _steps[_upcoming]));
    }

    if (!_recalculating && !_offRoute) _prompt();

    final r = router;
    if (!_arrived &&
        !_offRoute &&
        !_recalculating &&
        !_etaInFlight &&
        r != null &&
        r.supportsEta &&
        _settings.etaRefreshSeconds > 0 &&
        now - (_lastEtaAt ?? now) >= _settings.etaRefreshSeconds * 1000) {
      unawaited(_refreshEta(stamped));
    }
    final limit = speedLimitKmh;
    if (limit != _lastLimit) {
      _lastLimit = limit;
      _emit(SpeedLimitChanged(limit));
    }
    _emit(
      ProgressUpdated(
        remainingDistance: remainingDistance,
        remainingDuration: remainingDuration,
        distanceToNextStep: _distanceToNext,
        position: displayPosition ?? position,
        speedMps: speedMps,
      ),
    );
    _notify();
  }

  // ── Start / stop ─────────────────────────────────────────────────────

  /// Asks the [router] for a route to [destination] and starts on it.
  ///
  /// [from] defaults to the last fix. With no [from] and a moving user the
  /// route starts the way they are heading. [via] are stops on the way, in
  /// order. Throws a [RoutingException] when there is no route and a
  /// [StateError] when there is no router or no position. A route with no
  /// length (the destination is where the car is) starts arrived, see
  /// [start].
  Future<NavRoute> navigateTo(
    LatLng destination, {
    LatLng? from,
    List<LatLng> via = const [],
    String? destinationName,
    ArrivalType arrival = ArrivalType.destination,
  }) async {
    final r = router;
    if (r == null) throw StateError('navigateTo needs a router');
    final origin = from ?? _lastFix?.position;
    if (origin == null) {
      throw StateError('No position yet: pass from, or send a fix first');
    }
    final moving = from == null && speedMps >= _settings.headingMps;
    final route = await r.route(
      RouteRequest(
        points: [origin, ...via, destination],
        headingDeg: moving ? displayHeading : null,
        headingToleranceDeg: _settings.headingToleranceDegrees,
      ),
    );
    if (route.steps.isEmpty) {
      throw const RoutingException('The router gave an empty route');
    }
    start(
      route,
      destination: destination,
      waypoints: via,
      destinationName: destinationName,
      arrival: arrival,
    );
    return route;
  }

  /// Starts navigating along [route].
  ///
  /// [destination] is the place itself, which can be off the road (the end
  /// of the line when not given). [waypoints] are the stops on the way, read
  /// from the route when not given. [destinationName] is said at the start
  /// ("Navigating to Home"). [arrival] changes how the end is announced.
  ///
  /// A route with no length ([NavRoute.hasLength] false), from the spot the
  /// car is on to that same spot, starts arrived: [isActive] and [arrived]
  /// are true, [NavigationStarted] then [DestinationReached] come through
  /// [events], and the voice says the arrival. A route with no steps does
  /// not start, [isActive] stays false. Neither throws.
  void start(
    NavRoute route, {
    LatLng? destination,
    List<LatLng>? waypoints,
    String? destinationName,
    ArrivalType arrival = ArrivalType.destination,
  }) {
    final wasActive = _active;
    _voice.stop();
    _gate.reset();
    _detector.reset();
    // A last fix far from where this route starts is from another trip (or
    // a simulated drive somewhere else): it must not make the first fixes of
    // this one look like a jump.
    final last = _lastFix;
    final first = route.points.isNotEmpty
        ? route.points.first
        : (route.steps.isNotEmpty ? route.steps.first.location : null);
    if (last == null ||
        first == null ||
        metresBetween(last.position, first) > 500) {
      _detector.forget();
    }
    _arrival = arrival;
    _destinationName = destinationName;
    _routeSeq++;
    _waypointsPassed = 0;
    _setRoute(route, waypoints ?? route.waypoints);
    _destination = destination ?? route.end;
    _arrived = false;
    _arrivingSpoken = false;
    _arrivedSpoken = false;
    _recalculating = false;
    _offRoute = false;
    _saidRecalculating = false;
    _trafficFactor = 1;
    _lastEtaAt = _clock();
    _etaInFlight = false;
    _lastSpeakAt = null;
    _startedAt = _clock();
    _lastFixAt = null;
    _lastUsedAt = null;
    _gps = GpsSignal.good;
    _active = _steps.isNotEmpty && _destination != null;
    // Nothing to drive: the start is the end.
    final there = _active && _line == null;
    if (there) _arrived = true;
    if (wasActive) _emit(const NavigationStopped());
    if (_active) _emit(NavigationStarted(route));
    if (there) _emit(const DestinationReached());
    _notify();
    unawaited(_voice.prepare(_strings.speechLanguage));
    final name = destinationName;
    if (there) {
      if (_speak(_strings.arrived(_arrival))) _arrivedSpoken = true;
    } else if (_active && name != null && name.isNotEmpty) {
      _speak(_strings.navigatingTo(name));
    }
    // A fix that came before the start counts right away.
    final fix = _lastFix;
    if (_active && fix != null && _clock() - (fix.atMs ?? 0) < 5000) {
      _matchStart(fix);
    }
  }

  /// Places the last fix on a new route without judging it.
  void _matchStart(NavFix fix) {
    final line = _line;
    if (line == null) return;
    final m = _matchFix(fix, line);
    _lastMatch = m;
    if (m.distanceM - (fix.accuracyM ?? 0) <= _settings.offRouteMeters) {
      _along = m.alongM;
      _upcoming = _upcomingFrom(_along);
      _then = _thenOf(_upcoming);
      _distanceToNext = math.max(0, _maneuverAlong[_upcoming] - _along);
    }
  }

  /// Stops navigating.
  void stop() {
    final wasActive = _active;
    _routeSeq++;
    _gate.reset();
    _route = null;
    _setRoute(null, const []);
    _active = false;
    _arrived = false;
    _recalculating = false;
    _offRoute = false;
    _destination = null;
    _destinationName = null;
    _voice.stop();
    if (wasActive) {
      _emit(const NavigationStopped());
      _notify();
    }
  }

  void _setRoute(NavRoute? route, List<LatLng> waypoints) {
    _route = route;
    final steps = route?.steps ?? const <NavStep>[];
    _steps = steps;
    final pts = route != null && route.points.length >= 2
        ? route.points
        : [for (final s in steps) s.location];
    final line = RouteLine(pts);
    _line = line.isEmpty || line.lengthM < NavRoute.minLengthM ? null : line;
    _segmentLimits = _limitsFor(route, pts);
    _lastLimit = null;
    _maneuverAlong = _line == null
        ? const []
        : _maneuverPositions(_line!, steps);
    _routeDurationS = route == null
        ? 0
        : (route.durationS > 0
              ? route.durationS
              : steps.fold<double>(0, (s, step) => s + step.durationS));
    _along = 0;
    _lastMatch = null;
    _stage.clear();
    _upcoming = steps.isEmpty ? 0 : _upcomingFrom(0);
    _then = _thenOf(_upcoming);
    _distanceToNext = _maneuverAlong.isEmpty ? 0 : _maneuverAlong[_upcoming];
    _setWaypoints(waypoints);
  }

  /// The route's speed limits per segment of the route line, which leaves
  /// out points repeated right after themselves.
  static List<double?> _limitsFor(NavRoute? route, List<LatLng> pts) {
    final limits = route?.speedLimitsKmh ?? const <double?>[];
    if (route == null ||
        limits.isEmpty ||
        !identical(pts, route.points) ||
        limits.length != pts.length - 1) {
      return const [];
    }
    final kept = <double?>[];
    LatLng? last;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      if (last != null &&
          last.latitude == p.latitude &&
          last.longitude == p.longitude) {
        continue;
      }
      if (last != null) kept.add(limits[i - 1]);
      last = p;
    }
    return kept;
  }

  /// Where each stop is along the line: at the arrival step of its leg
  /// when there is one, else its nearest point on the line.
  void _setWaypoints(List<LatLng> waypoints) {
    _waypoints = List.unmodifiable(waypoints);
    _nextWaypoint = 0;
    final line = _line;
    if (line == null || waypoints.isEmpty) {
      _waypointAlong = const [];
      return;
    }
    final arrivals = [
      for (var i = 0; i < _steps.length - 1; i++)
        if (_steps[i].isArrive) i,
    ];
    final along = <double>[];
    var previous = 0.0;
    for (var i = 0; i < waypoints.length; i++) {
      double at;
      if (i < arrivals.length) {
        at = _maneuverAlong[arrivals[i]];
      } else {
        at = line.match(waypoints[i], fromM: previous)?.alongM ?? previous;
      }
      at = math.max(at, previous);
      along.add(at);
      previous = at;
    }
    _waypointAlong = along;
  }

  void _checkWaypoints(LatLng position, bool onLine) {
    while (_nextWaypoint < _waypoints.length) {
      final at = _waypointAlong[_nextWaypoint];
      final point = _waypoints[_nextWaypoint];
      final reached =
          (onLine && at - _along <= _settings.arriveMeters) ||
          (metresBetween(position, point) <= _settings.arriveMeters &&
              _along >= at - 200);
      if (!reached) return;
      _nextWaypoint++;
      _emit(WaypointReached(_waypointsPassed++, point));
      _speak(_strings.arrived(ArrivalType.stop), force: true);
    }
  }

  /// Where each maneuver is along the line: looked for near where the step
  /// lengths before it put it, never behind the one before.
  static List<double> _maneuverPositions(RouteLine line, List<NavStep> steps) {
    final out = <double>[];
    var previous = 0.0;
    var expected = 0.0;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      double along;
      if (i == 0) {
        along = 0;
      } else if (i == steps.length - 1 && step.isArrive) {
        along = line.lengthM;
      } else {
        final m = line.match(
          step.location,
          fromM: math.max(previous, expected - 300),
          toM: expected + 300,
        );
        along = m?.alongM ?? expected;
        along = along.clamp(previous, line.lengthM);
      }
      out.add(along);
      previous = along;
      expected = along + step.distanceM;
    }
    return out;
  }

  ArrivalType _arrivalOf(int index) =>
      index == _steps.length - 1 ? _arrival : ArrivalType.stop;

  /// The first maneuver still ahead of [along] that is a real action.
  int _upcomingFrom(double along) {
    // No line, no positions along it: the last step, the arrival.
    if (_maneuverAlong.length < _steps.length) {
      return _steps.isEmpty ? 0 : _steps.length - 1;
    }
    for (var i = 1; i < _steps.length; i++) {
      if (_maneuverAlong[i] < along - _passedM) continue;
      if (_steps[i].isPassive) continue;
      return i;
    }
    return _steps.length - 1;
  }

  /// The real action after maneuver [i], when it comes within thenMeters.
  int? _thenOf(int i) {
    if (_settings.thenMeters <= 0 ||
        _steps.isEmpty ||
        i >= _steps.length - 1 ||
        _maneuverAlong.length < _steps.length) {
      return null;
    }
    if (_steps[i].isArrive) return null;
    for (var j = i + 1; j < _steps.length; j++) {
      final step = _steps[j];
      if (step.isPassive) continue;
      if (step.isArrive) return null;
      return _maneuverAlong[j] - _maneuverAlong[i] <= _settings.thenMeters
          ? j
          : null;
    }
    return null;
  }

  /// Seconds of the route from [along] to its end, step by step.
  double _routeSecondsFrom(double along) {
    final line = _line;
    if (line == null || _steps.isEmpty) return 0;
    final stepsTotal = _steps.fold<double>(0, (s, step) => s + step.durationS);
    if (stepsTotal <= 0) {
      return line.lengthM <= 0
          ? 0
          : _routeDurationS * math.max(0, line.lengthM - along) / line.lengthM;
    }
    var seconds = 0.0;
    for (var k = 0; k < _steps.length; k++) {
      final start = _maneuverAlong[k];
      final end = k + 1 < _steps.length ? _maneuverAlong[k + 1] : line.lengthM;
      if (end <= along) continue;
      final span = end - start;
      final duration = _steps[k].durationS;
      if (span <= 0) {
        if (start >= along) seconds += duration;
        continue;
      }
      seconds +=
          duration * ((end - math.max(start, along)) / span).clamp(0.0, 1.0);
    }
    return seconds;
  }

  /// The point of the line the user is at: looked for just behind and ahead
  /// of the last place first (a route that uses a street twice), the whole
  /// line when that is far (a GPS gap, a tunnel).
  RouteMatch _matchFix(NavFix fix, RouteLine line) {
    final h = fix.headingDeg;
    final heading =
        h != null && h >= 0 && (fix.speedMps ?? 0) >= _settings.headingMps
        ? h
        : _detector.heading;
    final ahead = math.max(1500.0, (fix.speedMps ?? 0) * 90);
    final near = line.match(
      fix.position,
      fromM: _along - 80,
      toM: _along + ahead,
      headingDeg: heading,
      againstPenaltyM: 30,
    );
    if (near != null && near.distanceM <= _settings.offRouteMeters) return near;
    final any = line.match(
      fix.position,
      headingDeg: heading,
      againstPenaltyM: 30,
    )!;
    if (near == null) return any;
    return any.distanceM + 20 < near.distanceM ? any : near;
  }

  /// Went on past a U-turn of the route by uturnMissMeters, moving away from
  /// it: the U-turn was not taken. The wrong way rule cannot see this, as
  /// the car still drives along the route's direction.
  bool _missedUturn(
    NavFix fix,
    RouteMatch match,
    RouteLine line,
    LatLng destination,
  ) {
    final heading = _detector.heading;
    if (heading == null || (_detector.speed ?? 0) < _settings.movingMps) {
      return false;
    }
    if (metresBetween(fix.position, destination) < _settings.endGraceMeters ||
        metresBetween(fix.position, line.points.last) <
            _settings.endGraceMeters) {
      return false;
    }
    for (var k = 1; k < _steps.length; k++) {
      if (!_steps[k].isUturn) continue;
      final at = _maneuverAlong[k];
      if ((match.alongM - at).abs() > 15) continue;
      final point = line.pointAt(at);
      if (metresBetween(point, fix.position) <= _settings.uturnMissMeters) {
        continue;
      }
      if (angleBetween(bearingBetween(point, fix.position), heading) < 60) {
        return true;
      }
    }
    return false;
  }

  /// Adds a stop on the way while navigating: a new route from where the
  /// car is (the way it is heading) through the stops not reached yet, with
  /// [point] at [index] among them (the last one when null), to the same
  /// destination. Comes through [events] as [Rerouted], with no "Navigating
  /// to" said again.
  ///
  /// Throws a [StateError] when not navigating or with no router or fix,
  /// and a [RoutingException] when the router has no route; the old route
  /// stays then.
  Future<NavRoute> addWaypoint(LatLng point, {int? index}) {
    final stops = [...remainingWaypoints];
    final at = index == null ? stops.length : index.clamp(0, stops.length);
    stops.insert(at, point);
    return _routeThrough(stops);
  }

  /// Takes stop [index] of [remainingWaypoints] out of the trip, with a new
  /// route as [addWaypoint] makes one.
  Future<NavRoute> removeWaypoint(int index) {
    final stops = [...remainingWaypoints];
    if (index < 0 || index >= stops.length) {
      throw RangeError.index(index, stops, 'index');
    }
    stops.removeAt(index);
    return _routeThrough(stops);
  }

  /// A new route from the last fix through [stops] to the destination, put
  /// in place of the current one.
  Future<NavRoute> _routeThrough(List<LatLng> stops) async {
    final r = router;
    final to = _destination;
    final fix = _lastFix;
    if (!_active || to == null) throw StateError('Not navigating');
    if (r == null) throw StateError('Changing the stops needs a router');
    if (fix == null) throw StateError('No position yet');
    // A reroute that is out answers about the old stops: it is dropped.
    final seq = ++_routeSeq;
    final moving = speedMps >= _settings.headingMps;
    NavRoute route;
    try {
      route = await r.route(
        RouteRequest(
          points: [fix.position, ...stops, to],
          headingDeg: moving ? displayHeading : null,
          headingToleranceDeg: _settings.headingToleranceDegrees,
        ),
      );
      if (!route.usable) {
        throw const RoutingException('The router gave an empty route');
      }
    } catch (_) {
      if (!_disposed && _active && seq == _routeSeq) {
        // The old route stays, and rerouting can ask again.
        _gate.reset();
        _recalculating = false;
        _notify();
      }
      rethrow;
    }
    if (_disposed || !_active || seq != _routeSeq) {
      throw StateError('Navigation changed while the route was asked for');
    }
    _routeSeq++;
    // A reroute that was out is now about an old route.
    _gate.reset();
    _recalculating = false;
    final passed = _waypointsPassed;
    _setRoute(route, stops);
    _waypointsPassed = passed;
    _detector.reset();
    _offRoute = false;
    _saidRecalculating = false;
    _trafficFactor = 1;
    _lastEtaAt = _clock();
    _emit(Rerouted(route));
    _matchStart(fix);
    _notify();
    return route;
  }

  /// Forgets the recent fixes (the last good one, the speed and the
  /// heading worked out from them), so the next fix is not judged against
  /// them. For when fixes start coming from somewhere else, a simulated
  /// drive say: else a first fix far from the last real one looks like a
  /// GPS jump and is left out. The simulator calls it when it starts.
  void resetFixHistory() => _detector.forget();

  Future<void> _rerouteFrom(NavFix fix) async {
    final r = router;
    final to = _destination;
    if (r == null || to == null) return;
    final seq = _routeSeq;
    _gate.asked(fix.atMs!);
    _recalculating = true;
    if (!_saidRecalculating) {
      _saidRecalculating = _speak(_strings.recalculatingSpoken, force: true);
    }
    _emit(RerouteStarted(fix.position));
    _notify();
    // The heading while moving, so the new route starts that way.
    final moving = (_detector.speed ?? 0) >= _settings.movingMps;
    final waypoints = remainingWaypoints;
    NavRoute? route;
    Object? error;
    try {
      route = await r
          .route(
            RouteRequest(
              points: [fix.position, ...waypoints, to],
              headingDeg: moving ? _detector.heading : null,
              headingToleranceDeg: _settings.headingToleranceDegrees,
            ),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      error = e;
    }
    if (_disposed || seq != _routeSeq || !_active) return;
    final ok = route != null && route.usable;
    // No length from here: at the destination that is arriving, anywhere
    // else the router has nothing to drive, and the current route stays.
    final noLength = route != null && route.steps.isNotEmpty && !ok;
    final atDestination =
        noLength &&
        metresBetween(fix.position, to) <=
            _settings.endGraceMeters + _settings.offRouteMeters;
    // A router that says how long to wait (rate limited) is listened to.
    _gate.answered(
      _clock(),
      ok: ok || atDestination,
      waitAtLeast: error is RoutingException ? error.retryAfter : null,
    );
    _recalculating = false;
    if (atDestination) {
      _detector.reset();
      _offRoute = false;
      _saidRecalculating = false;
      _emit(const OffRouteChanged(false));
      if (!_arrived) {
        _arrived = true;
        _emit(const DestinationReached());
      }
      if (!_arrivedSpoken && _speak(_strings.arrived(_arrival))) {
        _arrivedSpoken = true;
      }
    } else if (ok) {
      _routeSeq++;
      final arrived = _arrived;
      _setRoute(route, waypoints);
      _arrived = arrived;
      _detector.reset();
      _offRoute = false;
      _saidRecalculating = false;
      _trafficFactor = 1;
      _lastEtaAt = _clock();
      _emit(Rerouted(route));
      _emit(const OffRouteChanged(false));
      final last = _lastFix;
      if (last != null) _matchStart(last);
    } else {
      _emit(
        RerouteFailed(
          error ??
              RoutingException(
                noLength
                    ? 'The router gave a route with no length'
                    : 'The router gave an empty route',
              ),
        ),
      );
    }
    _notify();
  }

  Future<void> _refreshEta(NavFix fix) async {
    final r = router;
    final to = _destination;
    if (r == null || to == null) return;
    _etaInFlight = true;
    _lastEtaAt = fix.atMs;
    final seq = _routeSeq;
    final along = _along;
    double? seconds;
    try {
      seconds = await r
          .eta(
            RouteRequest(
              points: [fix.position, ...remainingWaypoints, to],
              headingDeg: _detector.headingReliable ? _detector.heading : null,
              headingToleranceDeg: _settings.headingToleranceDegrees,
            ),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // The route's own times stay. A router that asks to wait gets that
      // long before the next estimate.
      final wait = e is RoutingException ? e.retryAfter : null;
      final at = fix.atMs;
      if (wait != null && at != null) _lastEtaAt = at + wait.inMilliseconds;
    }
    _etaInFlight = false;
    if (_disposed || seq != _routeSeq || !_active) return;
    if (seconds == null || seconds <= 0) return;
    final planned = _routeSecondsFrom(along);
    if (planned < 30) return;
    _trafficFactor = (seconds / planned).clamp(0.5, 3.0);
    _emit(EtaUpdated(remainingDuration, DateTime.now().add(remainingDuration)));
    _notify();
  }

  // ── Prompts ──────────────────────────────────────────────────────────

  void _prompt() {
    final i = _upcoming;
    final step = _steps[i];
    final d = _distanceToNext;
    final s = _strings;
    final units = _settings.units;
    final isLast = i == _steps.length - 1;
    if (isLast || step.isArrive) {
      final type = _arrivalOf(i);
      if (isLast && _arrived) {
        if (!_arrivedSpoken && _speak(s.arrived(type))) _arrivedSpoken = true;
        return;
      }
      final near = _settings.promptNearMeters;
      if (near <= 0 || d > near) return;
      if (isLast) {
        if (!_arrivingSpoken &&
            _speak(
              s.inDistance(s.spokenDistance(d, units), s.arriving(type)),
            )) {
          _arrivingSpoken = true;
        }
      } else if ((_stage[i] ?? 0) < 2 &&
          _speak(s.inDistance(s.spokenDistance(d, units), s.arriving(type)))) {
        _stage[i] = 2;
      }
      return;
    }
    final nowM = math.max(
      _settings.promptNowMeters.toDouble(),
      _settings.promptLeadSeconds > 0
          ? speedMps * _settings.promptLeadSeconds
          : 0.0,
    );
    final nearM = _settings.promptNearMeters.toDouble();
    final farM = _settings.promptFarMeters.toDouble();
    var due = 0;
    if (d <= nowM) {
      due = 3;
    } else if (nearM > 0 && d <= nearM && d > nowM * 1.5) {
      due = 2;
    } else if (farM > 0 && d <= farM && d > math.max(nearM, nowM) * 2) {
      due = 1;
    }
    final done = _stage[i] ?? 0;
    if (due <= done) return;
    final instruction = instructionFor(i);
    var text = due == 3
        ? instruction
        : s.inDistance(s.spokenDistance(d, units), instruction);
    final then = _then;
    if (due == 3 && then != null) text = s.then(text, instructionFor(then));
    if (_speak(text)) _stage[i] = due;
  }

  /// Says [text] through the navigation voice, for alerts of your own
  /// ("Speed camera in 300 meters"), in the voice and language of the
  /// prompts. True when it went out.
  ///
  /// It stays quiet when the voice is muted ([voiceEnabled]) or cannot
  /// speak, and while a prompt went out less than
  /// [NavigationSettings.speakGapMs] ago, so it does not cut off a turn.
  /// [interrupt] speaks even then. Like the prompts it comes through
  /// [events] as [InstructionSpoken].
  bool say(String text, {bool interrupt = false}) =>
      _speak(text, force: interrupt);

  /// Speaks [text] unless muted, the voice cannot, or a prompt went out a
  /// moment ago ([force]: even then). True when it went out.
  bool _speak(String text, {bool force = false}) {
    if (!_voiceEnabled || text.isEmpty || _voice.state != VoiceState.ready) {
      return false;
    }
    final now = _clock();
    if (!force &&
        _lastSpeakAt != null &&
        now - _lastSpeakAt! < _settings.speakGapMs) {
      return false;
    }
    _lastSpeakAt = now;
    _voice.say(text, _strings.speechLanguage);
    _emit(InstructionSpoken(text));
    return true;
  }

  void _emit(NavigationEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _locationSub?.cancel();
    _voice.stop();
    _events.close();
    super.dispose();
  }
}
