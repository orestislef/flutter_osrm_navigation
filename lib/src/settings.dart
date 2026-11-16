/// Units for distances shown and spoken.
enum DistanceUnits {
  /// Metres and kilometres.
  metric,

  /// Feet and miles.
  imperial,
}

/// How navigation behaves: what counts as off the route, when a new route
/// is asked for, when the voice speaks.
///
/// The defaults are tuned for a car in a city and have been driven a lot.
/// Every value can be changed while navigating with
/// `NavigationController.settings`.
class NavigationSettings {
  /// Creates settings. Every field has a sensible default.
  const NavigationSettings({
    this.rerouteEnabled = true,
    this.offRouteMeters = 50,
    this.offRouteFixes = 3,
    this.badFixMeters = 50,
    this.movingKmh = 8,
    this.startGraceMeters = 60,
    this.endGraceMeters = 100,
    this.rerouteMinSeconds = 15,
    this.rerouteRetryMaxSeconds = 120,
    this.etaRefreshSeconds = 120,
    this.promptFarMeters = 600,
    this.promptNearMeters = 200,
    this.promptNowMeters = 40,
    this.promptLeadSeconds = 4,
    this.thenMeters = 150,
    this.arriveMeters = 30,
    this.snapMeters = 25,
    this.wrongWayDegrees = 120,
    this.wrongWayFixes = 3,
    this.headingKmh = 12,
    this.uturnMissMeters = 30,
    this.headingToleranceDegrees = 45,
    this.speakGapMs = 3000,
    this.units = DistanceUnits.metric,
    this.speedingToleranceKmh = 3,
    this.gpsLostSeconds = 10,
  });

  /// Ask for a new route when the user leaves the current one.
  final bool rerouteEnabled;

  /// Off the route this many metres from the line, after taking off the
  /// GPS fix's own error.
  final int offRouteMeters;

  /// Fixes in a row off the line before it counts as off the route.
  final int offRouteFixes;

  /// A fix less precise than this (metres) is ignored.
  final int badFixMeters;

  /// Slower than this the user is standing still and off-route checks pause.
  final int movingKmh;

  /// No off-route check this close to the start of the route, where GPS
  /// often puts the user on the wrong side of a building.
  final int startGraceMeters;

  /// No off-route check this close to the end, where people turn around to
  /// find a parking spot or a door.
  final int endGraceMeters;

  /// The least seconds between two new routes.
  final int rerouteMinSeconds;

  /// The longest wait after failed reroutes. Waits double from
  /// [rerouteMinSeconds] up to this.
  final int rerouteRetryMaxSeconds;

  /// Seconds between asking the router for a fresh time left. 0 turns it
  /// off. Only used when the router can answer it.
  final int etaRefreshSeconds;

  /// The far prompt ("In 600 meters, turn left"). 0 turns it off.
  final int promptFarMeters;

  /// The near prompt ("In 200 meters, turn left"). 0 turns it off.
  final int promptNearMeters;

  /// The prompt at the maneuver itself ("Turn left").
  final int promptNowMeters;

  /// At speed the prompt at the maneuver comes this many seconds early,
  /// when that is farther than [promptNowMeters]. 0 uses the metres alone.
  final int promptLeadSeconds;

  /// A maneuver this close after the next one is shown and said with it
  /// ("Turn left, then turn right"). 0 turns it off.
  final int thenMeters;

  /// This close to the destination counts as arrived.
  final int arriveMeters;

  /// The position is drawn on the route line when the fix is this close to
  /// it. 0 always draws the raw fix.
  final int snapMeters;

  /// Driving against the route by more than this many degrees is the wrong
  /// way.
  final int wrongWayDegrees;

  /// Fixes in a row the wrong way before it counts.
  final int wrongWayFixes;

  /// Faster than this the GPS heading is trusted.
  final int headingKmh;

  /// Past a U-turn of the route by this many metres, still going, means the
  /// U-turn was missed.
  final int uturnMissMeters;

  /// How far either side of the current heading a new route may start.
  final int headingToleranceDegrees;

  /// The least milliseconds between two prompts, so one does not cut the
  /// previous one short.
  final int speakGapMs;

  /// Units for distances shown and spoken.
  final DistanceUnits units;

  /// Over the speed limit by more than this (km/h) counts as speeding.
  final int speedingToleranceKmh;

  /// No usable fix for this many seconds while navigating is a lost GPS
  /// signal (a garage, a long tunnel, location switched off). 0 turns the
  /// check off.
  final int gpsLostSeconds;

  /// [movingKmh] in metres per second.
  double get movingMps => movingKmh / 3.6;

  /// [headingKmh] in metres per second.
  double get headingMps => headingKmh / 3.6;

  /// A copy with the given fields changed.
  NavigationSettings copyWith({
    bool? rerouteEnabled,
    int? offRouteMeters,
    int? offRouteFixes,
    int? badFixMeters,
    int? movingKmh,
    int? startGraceMeters,
    int? endGraceMeters,
    int? rerouteMinSeconds,
    int? rerouteRetryMaxSeconds,
    int? etaRefreshSeconds,
    int? promptFarMeters,
    int? promptNearMeters,
    int? promptNowMeters,
    int? promptLeadSeconds,
    int? thenMeters,
    int? arriveMeters,
    int? snapMeters,
    int? wrongWayDegrees,
    int? wrongWayFixes,
    int? headingKmh,
    int? uturnMissMeters,
    int? headingToleranceDegrees,
    int? speakGapMs,
    DistanceUnits? units,
    int? speedingToleranceKmh,
    int? gpsLostSeconds,
  }) {
    return NavigationSettings(
      rerouteEnabled: rerouteEnabled ?? this.rerouteEnabled,
      offRouteMeters: offRouteMeters ?? this.offRouteMeters,
      offRouteFixes: offRouteFixes ?? this.offRouteFixes,
      badFixMeters: badFixMeters ?? this.badFixMeters,
      movingKmh: movingKmh ?? this.movingKmh,
      startGraceMeters: startGraceMeters ?? this.startGraceMeters,
      endGraceMeters: endGraceMeters ?? this.endGraceMeters,
      rerouteMinSeconds: rerouteMinSeconds ?? this.rerouteMinSeconds,
      rerouteRetryMaxSeconds:
          rerouteRetryMaxSeconds ?? this.rerouteRetryMaxSeconds,
      etaRefreshSeconds: etaRefreshSeconds ?? this.etaRefreshSeconds,
      promptFarMeters: promptFarMeters ?? this.promptFarMeters,
      promptNearMeters: promptNearMeters ?? this.promptNearMeters,
      promptNowMeters: promptNowMeters ?? this.promptNowMeters,
      promptLeadSeconds: promptLeadSeconds ?? this.promptLeadSeconds,
      thenMeters: thenMeters ?? this.thenMeters,
      arriveMeters: arriveMeters ?? this.arriveMeters,
      snapMeters: snapMeters ?? this.snapMeters,
      wrongWayDegrees: wrongWayDegrees ?? this.wrongWayDegrees,
      wrongWayFixes: wrongWayFixes ?? this.wrongWayFixes,
      headingKmh: headingKmh ?? this.headingKmh,
      uturnMissMeters: uturnMissMeters ?? this.uturnMissMeters,
      headingToleranceDegrees:
          headingToleranceDegrees ?? this.headingToleranceDegrees,
      speakGapMs: speakGapMs ?? this.speakGapMs,
      units: units ?? this.units,
      speedingToleranceKmh: speedingToleranceKmh ?? this.speedingToleranceKmh,
      gpsLostSeconds: gpsLostSeconds ?? this.gpsLostSeconds,
    );
  }
}
