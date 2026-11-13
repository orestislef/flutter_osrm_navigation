import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'controller.dart';
import 'geometry.dart';
import 'off_route.dart';
import 'route.dart';

/// What the simulated car is doing.
enum SimulatorMode {
  /// Following the route.
  follow,

  /// Going straight on, off the route, as if a turn was missed.
  straight,

  /// Driving back along the route, the wrong way.
  back,
}

/// Drives along the controller's route on its own, feeding it fixes.
///
/// For trying navigation at a desk, for demos and for screenshots. It
/// follows reroutes too: when the route changes it carries on along the new
/// one from where it is.
///
/// [missTurn] and [turnAround] leave the route on purpose, to see the
/// rerouting work: the controller notices, asks for a new route, and the
/// simulator follows that one.
///
/// ```dart
/// final sim = RouteSimulator(controller, speedKmh: 50);
/// sim.start();
/// ```
///
/// Do not feed real fixes at the same time, the two would fight over the
/// position.
class RouteSimulator {
  /// Creates a simulator for [controller].
  RouteSimulator(
    this.controller, {
    this.speedKmh = 40,
    this.interval = const Duration(seconds: 1),
    this.accuracyM = 5,
  });

  /// The controller fed with fixes.
  final NavigationController controller;

  /// Speed of the simulated car. Can be changed while it runs.
  double speedKmh;

  /// Time between fixes.
  final Duration interval;

  /// The accuracy each fix claims.
  final double accuracyM;

  Timer? _timer;
  NavRoute? _route;
  RouteLine? _line;
  double _along = 0;
  SimulatorMode _mode = SimulatorMode.follow;
  LatLng? _position;
  double _heading = 0;

  /// True while driving.
  bool get isRunning => _timer != null;

  /// What the car is doing now. Back to [SimulatorMode.follow] with every
  /// new route.
  SimulatorMode get mode => _mode;

  /// Starts driving from the start of the current route, or from where the
  /// position is on it.
  void start() {
    stop();
    _position = null;
    _rebase();
    if (_line == null) return;
    controller.addListener(_onController);
    _timer = Timer.periodic(interval, (_) => _tick());
    _emit();
  }

  /// Stops driving.
  void stop() {
    _timer?.cancel();
    _timer = null;
    controller.removeListener(_onController);
  }

  /// Goes straight on from here and leaves the route, the way a missed
  /// turn does.
  void missTurn() {
    if (!isRunning) return;
    _mode = SimulatorMode.straight;
  }

  /// Turns around and drives back along the route, the wrong way.
  void turnAround() {
    if (!isRunning) return;
    _mode = SimulatorMode.back;
    _heading = (_heading + 180) % 360;
  }

  void _onController() {
    if (!controller.isActive) {
      stop();
      return;
    }
    if (!identical(controller.route, _route)) _rebase();
  }

  /// Follows the controller's current route from the nearest point to the
  /// last position.
  void _rebase() {
    _mode = SimulatorMode.follow;
    final route = controller.route;
    _route = route;
    if (route == null || route.points.length < 2) {
      _line = null;
      return;
    }
    final line = RouteLine(route.points);
    _line = line.isEmpty ? null : line;
    final here = _position ?? controller.lastFix?.position;
    _along =
        here == null || _line == null ? 0 : (_line!.match(here)?.alongM ?? 0);
  }

  void _tick() {
    final line = _line;
    if (line == null) {
      stop();
      return;
    }
    final step = speedKmh / 3.6 * interval.inMilliseconds / 1000;
    switch (_mode) {
      case SimulatorMode.follow:
        _along += step;
        if (_along >= line.lengthM) {
          _along = line.lengthM;
          _emit();
          stop();
          return;
        }
      case SimulatorMode.straight:
        _position = offsetBy(_position ?? line.pointAt(_along), _heading, step);
        _emitAt(_position!, _heading);
        return;
      case SimulatorMode.back:
        if (_along <= 0) {
          _mode = SimulatorMode.straight;
          _tick();
          return;
        }
        _along = (_along - step).clamp(0, line.lengthM);
        final p = line.pointAt(_along);
        _heading = (line.bearingAt(_along) + 180) % 360;
        _position = p;
        _emitAt(p, _heading);
        return;
    }
    _emit();
  }

  void _emit() {
    final line = _line;
    if (line == null) return;
    _position = line.pointAt(_along);
    _heading = line.bearingAt(_along);
    _emitAt(_position!, _heading);
  }

  void _emitAt(LatLng p, double heading) {
    controller.updateLocation(NavFix(
      p,
      accuracyM: accuracyM,
      speedMps: speedKmh / 3.6,
      headingDeg: heading,
    ));
  }
}
