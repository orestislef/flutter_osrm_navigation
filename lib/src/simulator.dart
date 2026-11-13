import 'dart:async';

import 'controller.dart';
import 'geometry.dart';
import 'off_route.dart';
import 'route.dart';

/// Drives along the controller's route on its own, feeding it fixes.
///
/// For trying navigation at a desk, for demos and for screenshots. It
/// follows reroutes too: when the route changes it carries on along the new
/// one from where it is.
///
/// ```dart
/// final sim = RouteSimulator(controller, speedKmh: 50);
/// sim.start();
/// ```
///
/// Do not attach a real location stream at the same time, the two would
/// fight over the position.
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

  /// True while driving.
  bool get isRunning => _timer != null;

  /// Starts driving from the start of the current route, or from where the
  /// position is on it.
  void start() {
    stop();
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
    final route = controller.route;
    _route = route;
    if (route == null || route.points.length < 2) {
      _line = null;
      return;
    }
    final line = RouteLine(route.points);
    _line = line.isEmpty ? null : line;
    final here = controller.lastFix?.position;
    _along =
        here == null || _line == null ? 0 : (_line!.match(here)?.alongM ?? 0);
  }

  void _tick() {
    final line = _line;
    if (line == null) {
      stop();
      return;
    }
    _along += speedKmh / 3.6 * interval.inMilliseconds / 1000;
    if (_along >= line.lengthM) {
      _along = line.lengthM;
      _emit();
      stop();
      return;
    }
    _emit();
  }

  void _emit() {
    final line = _line;
    if (line == null) return;
    controller.updateLocation(NavFix(
      line.pointAt(_along),
      accuracyM: accuracyM,
      speedMps: speedKmh / 3.6,
      headingDeg: line.bearingAt(_along),
    ));
  }
}
