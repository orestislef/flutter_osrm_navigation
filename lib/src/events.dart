import 'package:latlong2/latlong.dart';

import 'route.dart';

/// Something that happened during navigation, from
/// `NavigationController.events`.
sealed class NavigationEvent {
  const NavigationEvent();
}

/// Navigation started on [route].
class NavigationStarted extends NavigationEvent {
  /// Creates the event.
  const NavigationStarted(this.route);

  /// The route being followed.
  final NavRoute route;
}

/// Navigation stopped, by `stop()` or a new start.
class NavigationStopped extends NavigationEvent {
  /// Creates the event.
  const NavigationStopped();
}

/// The user left the route, or came back to it.
class OffRouteChanged extends NavigationEvent {
  /// Creates the event.
  const OffRouteChanged(this.offRoute);

  /// True when off the route now.
  final bool offRoute;
}

/// A new route is being asked for.
class RerouteStarted extends NavigationEvent {
  /// Creates the event.
  const RerouteStarted(this.from);

  /// Where the new route starts.
  final LatLng from;
}

/// A new route replaced the old one.
class Rerouted extends NavigationEvent {
  /// Creates the event.
  const Rerouted(this.route);

  /// The new route.
  final NavRoute route;
}

/// Asking for a new route failed. The old route stays and it is tried
/// again later.
class RerouteFailed extends NavigationEvent {
  /// Creates the event.
  const RerouteFailed(this.error);

  /// What went wrong.
  final Object error;
}

/// A stop on the way was reached.
class WaypointReached extends NavigationEvent {
  /// Creates the event.
  const WaypointReached(this.index, this.position);

  /// Which stop, 0 for the first of the trip.
  final int index;

  /// Where it is.
  final LatLng position;
}

/// The end of the route was reached.
class DestinationReached extends NavigationEvent {
  /// Creates the event.
  const DestinationReached();
}

/// The next maneuver changed: the one before was passed.
class StepChanged extends NavigationEvent {
  /// Creates the event.
  const StepChanged(this.index, this.step);

  /// Index of the new next maneuver in `NavigationController.steps`.
  final int index;

  /// The new next maneuver.
  final NavStep step;
}

/// Progress along the route, after every GPS fix that counted.
class ProgressUpdated extends NavigationEvent {
  /// Creates the event.
  const ProgressUpdated({
    required this.remainingDistance,
    required this.remainingDuration,
    required this.distanceToNextStep,
    required this.position,
    required this.speedMps,
  });

  /// Metres left along the route.
  final double remainingDistance;

  /// Time left.
  final Duration remainingDuration;

  /// Metres to the next maneuver.
  final double distanceToNextStep;

  /// Where the position is drawn (on the route line when close to it).
  final LatLng position;

  /// Speed in m/s.
  final double speedMps;

  /// When the user should arrive, by the device's clock.
  DateTime get estimatedArrival => DateTime.now().add(remainingDuration);
}

/// The router gave a fresh time estimate (traffic, when it knows it) and
/// the time left was corrected.
class EtaUpdated extends NavigationEvent {
  /// Creates the event.
  const EtaUpdated(this.remainingDuration, this.estimatedArrival);

  /// Time left now.
  final Duration remainingDuration;

  /// When the user should arrive, by the device's clock.
  final DateTime estimatedArrival;
}

/// The voice said [text].
class InstructionSpoken extends NavigationEvent {
  /// Creates the event.
  const InstructionSpoken(this.text);

  /// What was said.
  final String text;
}
