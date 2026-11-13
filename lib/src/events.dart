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

/// The voice said [text].
class InstructionSpoken extends NavigationEvent {
  /// Creates the event.
  const InstructionSpoken(this.text);

  /// What was said.
  final String text;
}
