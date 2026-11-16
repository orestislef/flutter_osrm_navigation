// Navigation on simulated GPS tracks: progress along the line, leaving the
// route (a wrong turn, the wrong way, a missed U-turn), what does not count
// (noise, a tunnel, a red light, the ends of the route, bad fixes), the
// reroute throttle, the time left, and what the voice says.
import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/drive.dart';

double secondsLeft(NavigationController nav) =>
    nav.remainingDuration.inMilliseconds / 1000;

/// Out 300 m east, a U-turn, back 300 m west on the same street, then 200 m
/// north: both directions of the street on one line.
NavRoute outAndBack() => navRoute(trackStart,
    [(90, 300, 'Egnatia'), (270, 300, 'Egnatia'), (0, 200, 'Agias Sofias')]);

/// Fixes every 10 m from [from] towards [bearing] with no speed and no
/// heading, the way a browser often gives them.
List<SimFix> bare(LatLng from, double bearing, int count) => [
      for (var i = 1; i <= count; i++)
        SimFix(offsetBy(from, bearing, 10.0 * i)),
    ];

void main() {
  group('progress', () {
    test('the maneuvers sit where they are along the line', () {
      final d = Drive();
      d.start(testRoute());
      expect(d.nav.isActive, isTrue);
      expect(d.nav.distanceToNextStep, closeTo(600, 2));
      expect(metresBetween(d.nav.upcomingStep!.location, cornerA), lessThan(1));
      expect(d.nav.upcomingInstruction, 'Turn left onto Agias Sofias');
      expect(d.nav.remainingDistance, closeTo(1500, 3));
    });

    test('GPS noise of 15 m: nothing asked, progress follows to the end',
        () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(routePath(), noiseM: 15);
      await d.feed(track.take(10));
      expect(d.nav.upcomingStep!.streetName, 'Agias Sofias');
      expect(d.nav.distanceToNextStep, closeTo(500, 20));
      expect(d.nav.remainingDistance, closeTo(1400, 20));
      expect(d.nav.snappedPosition, isNotNull);
      await d.feed(track.skip(10).take(55));
      expect(d.nav.upcomingStep!.streetName, 'Ermou');
      await d.feed(track.skip(65));
      expect(d.asked, isEmpty);
      expect(d.nav.offRoute, isFalse);
      expect(d.nav.arrived, isTrue);
      expect(d.events.whereType<DestinationReached>(), hasLength(1));
    });

    test('the line behind is dropped and the traveled part kept', () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()).take(25));
      expect(RouteLine(d.nav.remainingLine).lengthM, closeTo(1250, 3));
      expect(RouteLine(d.nav.traveledLine).lengthM, closeTo(250, 3));
    });

    test('the road bearing turns the map while on the line and moving',
        () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()).take(10));
      expect(d.nav.roadBearing, closeTo(90, 1));
      expect(d.nav.displayHeading, closeTo(90, 1));
    });
  });

  group('off the route', () {
    test('a wrong turn: three fixes off the line, then a new route from there',
        () async {
      final d = Drive();
      d.start(testRoute());
      // Straight on at the corner instead of turning left.
      final track = drive(legs(trackStart, [(90, 600), (90, 300)]));
      await d.feed(track.take(65));
      expect(d.asked, isEmpty);
      d.hold = true;
      await d.feed(track.skip(65).take(2));
      expect(d.asked, isEmpty, reason: 'two fixes are not yet enough');
      await d.feed(track.skip(67).take(1));
      expect(d.asked, hasLength(1));
      expect(metresBetween(d.asked.single.from, offsetBy(trackStart, 90, 680)),
          lessThan(1));
      expect(d.asked.single.heading, closeTo(90, 1),
          reason: 'the new route starts the way the car goes');
      expect(metresBetween(d.asked.single.to, endD), lessThan(1));
      expect(d.nav.recalculating, isTrue);
      expect(d.nav.offRoute, isTrue);
      expect(d.events.whereType<RerouteStarted>(), hasLength(1));

      final here = d.asked.single.from;
      final second = navRoute(here,
          [(90, 100, 'Egnatia'), (0, 500, 'Kamvouniou'), (270, 180, 'Ermou')]);
      await d.complete(second);
      expect(d.nav.recalculating, isFalse);
      expect(d.nav.offRoute, isFalse);
      expect(identical(d.nav.steps, second.steps), isTrue);
      expect(metresBetween(d.nav.remainingLine.first, here), lessThan(1));
      expect(d.nav.upcomingStep!.streetName, 'Kamvouniou');
      expect(d.events.whereType<Rerouted>(), hasLength(1));
    });

    test('a tunnel: no fixes for 45 s, then further along: nothing asked',
        () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(routePath());
      await d.feed(track.take(20));
      final out = track[64];
      await d.feed(
          [SimFix(out.position, speed: 10, heading: out.heading, gapS: 45)]);
      expect(d.asked, isEmpty);
      expect(d.nav.upcomingStep!.streetName, 'Ermou');
      expect(d.nav.distanceToNextStep, closeTo(450, 15));
      await d.feed(track.skip(65));
      expect(d.asked, isEmpty);
      expect(d.nav.arrived, isTrue);
    });

    test('a U-turn in the street: three fixes the wrong way, then a new route',
        () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 300)])));
      final back = drive(legs(offsetBy(trackStart, 90, 300), [(270, 150)]));
      await d.feed(back.take(2));
      expect(d.asked, isEmpty);
      await d.feed(back.skip(2).take(1));
      expect(d.asked, hasLength(1), reason: 'no distance to wait for');
      expect(d.asked.single.heading, closeTo(270, 1));
    });

    test('a red light: the fix drifts 60 m off while standing, nothing asked',
        () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(routePath());
      await d.feed(track.take(20));
      final drift = offsetBy(offsetBy(trackStart, 90, 200), 0, 60);
      await d.feed([
        for (var i = 0; i < 30; i++) SimFix(drift, speed: 0, accuracy: 5),
      ]);
      expect(d.asked, isEmpty);
      expect(d.nav.remainingDistance, closeTo(1300, 2));
      await d.feed(track.skip(20).take(20));
      expect(d.asked, isEmpty);
    });

    test('near the start off the line is not checked, past it it is', () async {
      final d = Drive(
          settings: const NavigationSettings(
              offRouteMeters: 20, startGraceMeters: 100))
        ..hold = true;
      d.start(testRoute());
      final track = drive(legs(trackStart, [(0, 200)]));
      await d.feed(track.take(9));
      expect(d.asked, isEmpty);
      await d.feed(track.skip(9).take(3));
      expect(d.asked, hasLength(1));
    });

    test('near the end, looking around the corner asks for nothing', () async {
      final d = Drive(settings: const NavigationSettings(arriveMeters: 10));
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 600), (0, 500), (90, 340)])));
      final near = offsetBy(cornerB, 90, 340);
      await d.feed(drive(legs(near, [(180, 70)]), speed: 5));
      expect(d.asked, isEmpty);
      expect(d.nav.arrived, isFalse);
    });

    test('a place off the road: near where the route ends is not checked',
        () async {
      final d = Drive(settings: const NavigationSettings(arriveMeters: 10))
        ..hold = true;
      d.start(testRoute(), destination: offsetBy(endD, 0, 150));
      await d.feed(drive(legs(trackStart, [(90, 600), (0, 500), (90, 340)])));
      await d
          .feed(drive(legs(offsetBy(cornerB, 90, 340), [(180, 70)]), speed: 5));
      expect(d.asked, isEmpty);
    });

    test('overshooting the end: well past it, a route back', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(routePath()));
      expect(d.nav.arrived, isTrue);
      final on = drive(legs(endD, [(90, 300)]));
      await d.feed(on.take(9));
      expect(d.nav.arrived, isTrue);
      expect(d.asked, isEmpty);
      await d.feed(on.skip(9));
      expect(d.nav.arrived, isFalse);
      expect(d.asked, hasLength(1));
    });

    test('imprecise fixes and a jump are left out', () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(routePath());
      await d.feed(track.take(20));
      final off = offsetBy(offsetBy(trackStart, 90, 200), 0, 100);
      await d.feed([
        for (var i = 0; i < 10; i++)
          SimFix(off, speed: 10, heading: 0, accuracy: 80),
      ]);
      expect(d.asked, isEmpty);
      await d
          .feed([SimFix(offsetBy(trackStart, 0, 800), speed: 10, accuracy: 5)]);
      expect(d.nav.remainingDistance, closeTo(1300, 2));
      await d.feed(track.skip(20).take(10));
      expect(d.asked, isEmpty);
      expect(d.nav.offRoute, isFalse);
    });

    test('a failed reroute keeps the old route and retries after 15 then 30 s',
        () async {
      final d = Drive();
      final first = testRoute();
      d.start(first);
      d.nav.voiceEnabled = false;
      var fail = true;
      d.answer = (from) => fail
          ? null
          : navRoute(from, [(0, 500, 'Kamvouniou'), (270, 400, 'Ermou')]);
      final track = drive(legs(trackStart, [(90, 600), (90, 1500)]));
      await d.feed(track.take(68));
      expect(d.asked, hasLength(1));
      expect(identical(d.nav.steps, first.steps), isTrue);
      expect(d.nav.offRoute, isTrue);
      expect(d.nav.recalculating, isFalse);
      expect(d.events.whereType<RerouteFailed>(), hasLength(1));
      final failedAt = d.answeredAt!;

      await d.feed(track.skip(68).take(14));
      expect(d.asked, hasLength(1), reason: 'not again within 15 s');
      await d.feed(track.skip(82).take(1));
      expect(d.asked, hasLength(2));
      expect(d.asked[1].at - failedAt, 15000);

      final secondFailedAt = d.answeredAt!;
      await d.feed(track.skip(83).take(29));
      expect(d.asked, hasLength(2), reason: 'the wait doubles');
      fail = false;
      await d.feed(track.skip(112).take(1));
      expect(d.asked, hasLength(3));
      expect(d.asked[2].at - secondFailedAt, 30000);
      expect(d.nav.steps.first.streetName, 'Kamvouniou');
      expect(d.nav.offRoute, isFalse);
      expect(d.nav.voiceEnabled, isFalse, reason: 'muted stays muted');
      expect(d.voice.said, isEmpty);
    });

    test('a new route that comes after arriving keeps the arrival', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 600), (90, 100)])).take(68));
      expect(d.asked, hasLength(1));
      await d.feed([SimFix(endD, speed: 3, accuracy: 5, gapS: 60)]);
      expect(d.nav.arrived, isTrue);
      await d.complete(navRoute(offsetBy(trackStart, 90, 680),
          [(0, 500, 'Kamvouniou'), (270, 80, 'Ermou')]));
      expect(d.nav.arrived, isTrue);
      expect(d.nav.steps.first.streetName, 'Kamvouniou');
    });

    test('one request at a time, none sooner than rerouteMinSeconds', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      final track = drive(legs(trackStart, [(90, 600), (90, 1500)]));
      await d.feed(track.take(68));
      expect(d.asked, hasLength(1));
      await d.feed(track.skip(68).take(10));
      expect(d.asked, hasLength(1), reason: 'still out');
      final at = d.asked.single.from;
      await d
          .complete(navRoute(at, [(0, 500, 'Kamvouniou'), (90, 400, 'Ermou')]));
      final answered = d.answeredAt!;
      for (final f in track.skip(78)) {
        await d.feed([f]);
        if (d.asked.length > 1) break;
      }
      expect(d.asked, hasLength(2));
      expect(d.asked[1].at - answered, greaterThanOrEqualTo(15000));
    });

    test('rerouting switched off: off the route, nothing asked', () async {
      final d =
          Drive(settings: const NavigationSettings(rerouteEnabled: false));
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 600), (90, 300)])));
      expect(d.nav.offRoute, isTrue);
      expect(d.asked, isEmpty);
    });

    test('the same fix again within half a second does not count', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 660)])));
      final off = offsetBy(trackStart, 90, 670);
      for (var i = 0; i < 5; i++) {
        d.nav.updateLocation(
            NavFix(off, accuracyM: 8, speedMps: 10, headingDeg: 90));
      }
      expect(d.asked, isEmpty);
    });
  });

  group('a router that rate limits', () {
    test('the next reroute waits as long as Retry-After says', () async {
      final d = Drive();
      d.start(testRoute());
      d.nav.router = CallbackRouter(route: (r) async {
        d.asked.add(Asked(r, d.now));
        throw const RoutingException('Too Many Requests',
            statusCode: 429, retryAfter: Duration(seconds: 60));
      });
      final track = drive(legs(trackStart, [(90, 600), (90, 1500)]));
      await d.feed(track.take(68));
      expect(d.asked, hasLength(1));
      await d.feed(track.skip(68).take(80));
      expect(d.asked, hasLength(2), reason: 'once more, not every 15 s');
      expect(d.asked[1].at - d.asked[0].at, greaterThanOrEqualTo(60000));
      final failed = d.events.whereType<RerouteFailed>().first;
      expect((failed.error as RoutingException).isRateLimited, isTrue);
      expect(identical(d.nav.steps, d.nav.route!.steps), isTrue);
      expect(d.nav.offRoute, isTrue, reason: 'the old route stays');
    });
  });

  group('the wrong way and U-turns', () {
    test('a start the other way with no heading: a new route within 40 m',
        () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed([const SimFix(trackStart, speed: 0)]);
      final west = bare(trackStart, 270, 8);
      await d.feed(west.take(3));
      expect(d.asked, isEmpty);
      await d.feed(west.skip(3).take(1));
      expect(d.asked, hasLength(1));
      expect(d.asked.single.heading, closeTo(270, 1));
      expect(metresBetween(d.asked.single.from, offsetBy(trackStart, 270, 40)),
          lessThan(1));
    });

    test('a start the other way with the GPS heading: after three fixes',
        () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      final west = drive(legs(trackStart, [(270, 100)]));
      await d.feed(west.take(2));
      expect(d.asked, isEmpty);
      await d.feed(west.skip(2).take(1));
      expect(d.asked, hasLength(1));
      expect(d.asked.single.heading, closeTo(270, 1));
    });

    test('following a route out and back on one line asks nothing', () async {
      final d = Drive();
      d.start(outAndBack());
      await d.feed(drive(legs(trackStart, [(90, 295)])));
      await d.feed([
        SimFix(offsetBy(trackStart, 90, 298), speed: 1, heading: 180),
        SimFix(offsetBy(trackStart, 90, 296), speed: 1, heading: 270),
      ]);
      await d.feed(
          drive(legs(offsetBy(trackStart, 90, 296), [(270, 296), (0, 200)])));
      expect(d.asked, isEmpty);
      expect(d.nav.arrived, isTrue);
    });

    test('turning back early where the route comes back anyway is fine',
        () async {
      final d = Drive();
      d.start(outAndBack());
      await d.feed(drive(legs(trackStart, [(90, 150)])));
      await d.feed(drive(legs(offsetBy(trackStart, 90, 150), [(270, 80)])));
      expect(d.asked, isEmpty);
      expect(d.nav.upcomingStep!.streetName, 'Agias Sofias');
    });

    test('turning round again after the U-turn is the wrong way', () async {
      final d = Drive()..hold = true;
      d.start(outAndBack());
      await d.feed(drive(legs(trackStart, [(90, 300), (270, 150)])));
      expect(d.asked, isEmpty);
      final again = drive(legs(offsetBy(trackStart, 90, 150), [(90, 100)]));
      await d.feed(again.take(2));
      expect(d.asked, isEmpty);
      await d.feed(again.skip(2).take(1));
      expect(d.asked, hasLength(1));
      expect(d.asked.single.heading, closeTo(90, 1));
    });

    test('heading noise at low speed and one wrong heading count for nothing',
        () async {
      final d = Drive();
      d.start(testRoute());
      final crawl = drive(legs(trackStart, [(90, 120)]), speed: 2);
      var spin = 0.0;
      await d.feed([
        for (final f in crawl)
          SimFix(f.position, speed: 2, heading: (spin += 137) % 360),
      ]);
      expect(d.asked, isEmpty);
      final on = drive(legs(offsetBy(trackStart, 90, 120), [(90, 200)]));
      await d.feed(on.take(5));
      await d.feed([SimFix(on[5].position, speed: 10, heading: 270)]);
      await d.feed(on.skip(6));
      expect(d.asked, isEmpty);
      expect(d.nav.offRoute, isFalse);
    });

    test('a U-turn of the route, taken: said as one, no new route', () async {
      final d = Drive();
      d.start(outAndBack());
      expect(d.nav.upcomingInstruction, 'Make a U-turn onto Egnatia');
      await d.feed(drive(legs(trackStart, [(90, 295)])));
      await d.feed([
        SimFix(offsetBy(trackStart, 90, 298), speed: 1, heading: 180),
        SimFix(offsetBy(trackStart, 90, 296), speed: 1, heading: 270),
      ]);
      await d.feed(drive(legs(offsetBy(trackStart, 90, 296), [(270, 200)])));
      expect(d.voice.said.take(2), [
        'In 200 meters, make a U-turn onto Egnatia',
        'Make a U-turn onto Egnatia',
      ]);
      expect(d.asked, isEmpty);
      expect(d.nav.upcomingStep!.streetName, 'Agias Sofias');
    });

    test('a U-turn of the route, not taken: a new route soon after', () async {
      final d = Drive()..hold = true;
      d.start(outAndBack());
      final on = drive(legs(trackStart, [(90, 400)]));
      await d.feed(on.take(32));
      expect(d.asked, isEmpty);
      await d.feed(on.skip(32).take(2));
      expect(d.asked, hasLength(1));
      expect(d.asked.single.heading, closeTo(90, 1));
      expect(metresBetween(d.asked.single.from, offsetBy(trackStart, 90, 300)),
          inInclusiveRange(30, 41));
    });

    test('more wrong way fixes wait longer, 45 degrees off is not wrong',
        () async {
      final d = Drive(settings: const NavigationSettings(wrongWayFixes: 5))
        ..hold = true;
      d.start(testRoute());
      final west = drive(legs(trackStart, [(270, 100)]));
      await d.feed(west.take(4));
      expect(d.asked, isEmpty);
      await d.feed(west.skip(4).take(1));
      expect(d.asked, hasLength(1));

      final e = Drive()..hold = true;
      e.start(testRoute());
      await e.feed(drive(legs(trackStart, [(90, 100)])));
      await e.feed([
        for (var i = 1; i <= 4; i++)
          SimFix(offsetBy(offsetBy(trackStart, 90, 100), 90, 8.0 * i),
              speed: 10, heading: 135),
      ]);
      expect(e.asked, isEmpty);
    });
  });

  group('the time left', () {
    test('follows the route, and the router estimate scales it', () async {
      var etaAsked = 0;
      final d =
          Drive(settings: const NavigationSettings(etaRefreshSeconds: 60));
      d.start(testRoute(), eta: (r) async {
        etaAsked++;
        return 2 * secondsLeft(d.nav);
      });
      final track = drive(routePath());
      await d.feed(track.take(10));
      expect(secondsLeft(d.nav), closeTo(140, 3));
      await d.feed(track.skip(10).take(50));
      expect(etaAsked, 1);
      expect(secondsLeft(d.nav), closeTo(180, 4), reason: 'twice the 90 s');
      await d.feed(track.skip(60).take(30));
      expect(etaAsked, 1, reason: 'not again before 60 s');
      expect(d.nav.estimatedArrival, isNotNull);
    });
  });

  group('stops on the way', () {
    NavRoute withStop() => navRoute(
          trackStart,
          [(90, 600, 'Egnatia'), (0, 500, 'Agias Sofias'), (90, 400, 'Ermou')],
          stopsAfter: {0},
        );

    test('the stop is announced, reached, and the drive goes on', () async {
      final d = Drive();
      d.start(withStop());
      expect(d.nav.remainingWaypoints, hasLength(1));
      expect(d.nav.upcomingInstruction, 'Arrive at the stop');
      await d.feed(drive(routePath()));
      expect(d.voice.said, [
        'In 200 meters, you reach the stop',
        'You are at the stop',
        'In 500 meters, turn right onto Ermou',
        'In 200 meters, turn right onto Ermou',
        'Turn right onto Ermou',
        'In 200 meters, you reach the destination',
        'You are at the destination',
      ]);
      final reached = d.events.whereType<WaypointReached>().toList();
      expect(reached, hasLength(1));
      expect(reached.single.index, 0);
      expect(d.nav.remainingWaypoints, isEmpty);
      expect(d.nav.arrived, isTrue);
    });

    test('a reroute before the stop goes through it, after it does not',
        () async {
      final d = Drive()..hold = true;
      d.start(withStop());
      // North at the start instead of east.
      await d.feed(drive(legs(trackStart, [(0, 200)])).take(12));
      expect(d.asked, hasLength(1));
      expect(d.asked.single.request.points, hasLength(3));
      expect(metresBetween(d.asked.single.request.points[1], cornerA),
          lessThan(1));

      final e = Drive()..hold = true;
      e.start(withStop());
      // Past the stop, then straight on instead of the right turn.
      await e.feed(drive(legs(trackStart, [(90, 600), (0, 700)])).take(120));
      expect(e.asked, hasLength(1));
      expect(e.asked.single.request.points, hasLength(2));
    });
  });

  group('the voice', () {
    test('English: each turn far, near and at it, then the arrival', () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()));
      expect(d.voice.said, [
        'In 600 meters, turn left onto Agias Sofias',
        'In 200 meters, turn left onto Agias Sofias',
        'Turn left onto Agias Sofias',
        'In 500 meters, turn right onto Ermou',
        'In 200 meters, turn right onto Ermou',
        'Turn right onto Ermou',
        'In 200 meters, you reach the destination',
        'You are at the destination',
      ]);
      expect(d.events.whereType<InstructionSpoken>(), hasLength(8));
    });

    test('Greek: the same drive', () async {
      final d = Drive(strings: const GreekNavigationStrings());
      d.start(testRoute());
      await d.feed(drive(routePath()));
      expect(d.voice.said, [
        'Σε 600 μέτρα, στρίψτε αριστερά στην Agias Sofias',
        'Σε 200 μέτρα, στρίψτε αριστερά στην Agias Sofias',
        'Στρίψτε αριστερά στην Agias Sofias',
        'Σε 500 μέτρα, στρίψτε δεξιά στην Ermou',
        'Σε 200 μέτρα, στρίψτε δεξιά στην Ermou',
        'Στρίψτε δεξιά στην Ermou',
        'Σε 200 μέτρα, φτάνετε στον προορισμό',
        'Φτάσατε στον προορισμό',
      ]);
    });

    test('imperial units', () async {
      final d = Drive(
          settings: const NavigationSettings(units: DistanceUnits.imperial));
      d.start(testRoute());
      await d.feed(drive(routePath()).take(10));
      expect(d.voice.said, ['In 0.4 miles, turn left onto Agias Sofias']);
    });

    test('at speed the turn is said earlier', () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(routePath(), speed: 20);
      for (final f in track) {
        await d.feed([f]);
        if (d.voice.said.contains('Turn left onto Agias Sofias')) break;
      }
      expect(d.nav.distanceToNextStep, inInclusiveRange(60, 80));
    });

    test('a turn right after the next is shown and said with it', () async {
      final d = Drive();
      d.start(navRoute(trackStart, [
        (90, 600, 'Egnatia'),
        (0, 100, 'Agias Sofias'),
        (90, 400, 'Ermou')
      ]));
      final track = drive(legs(trackStart, [(90, 600), (0, 100), (90, 400)]));
      await d.feed(track.take(10));
      expect(d.nav.upcomingStep!.streetName, 'Agias Sofias');
      expect(d.nav.thenStep?.streetName, 'Ermou');
      expect(d.nav.thenInstruction, 'Turn right onto Ermou');
      await d.feed(track.skip(10).take(50));
      expect(d.voice.said,
          contains('Turn left onto Agias Sofias, then turn right onto Ermou'));
    });

    test('the arrival at a pickup', () async {
      final d = Drive();
      d.start(testRoute(), arrival: ArrivalType.pickup);
      await d.feed(drive(routePath()));
      expect(d.voice.said.skip(6),
          ['In 200 meters, you reach the pickup', 'You are at the pickup']);
    });

    test('"Recalculating" is said once, also over a failed try', () async {
      final d = Drive();
      d.start(testRoute());
      final track = drive(legs(trackStart, [(90, 600), (90, 1500)]));
      await d.feed(track.take(100));
      expect(d.asked, hasLength(2));
      expect(d.voice.said.where((s) => s == 'Recalculating the route'),
          hasLength(1));
    });

    test('"Navigating to" at the start', () {
      final d = Drive();
      d.start(testRoute(), name: 'Ermou 5');
      expect(d.voice.said, ['Navigating to Ermou 5']);
    });

    test('muted says nothing, unmuted says the turn that is due', () async {
      final d = Drive();
      d.start(testRoute());
      d.nav.voiceEnabled = false;
      final track = drive(routePath());
      await d.feed(track.take(45));
      expect(d.voice.said, isEmpty);
      d.nav.voiceEnabled = true;
      await d.feed(track.skip(45).take(1));
      expect(d.voice.said, ['In 150 meters, turn left onto Agias Sofias']);
    });

    test('a browser waiting for a tap says nothing until unlocked', () async {
      final d = Drive();
      d.voice.current = VoiceState.needsTap;
      d.start(testRoute());
      expect(d.nav.voiceState, VoiceState.needsTap);
      final track = drive(routePath());
      await d.feed(track.take(30));
      expect(d.voice.said, isEmpty);
      d.voice.current = VoiceState.ready;
      d.nav.unlockVoice();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(d.voice.said, ['Voice directions are on']);
      d.now += 5000;
      await d.feed(track.skip(30).take(10));
      expect(d.voice.said.last, 'In 200 meters, turn left onto Agias Sofias');
    });

    test('no voice on the device: nothing said, the state says so', () async {
      final d = Drive();
      d.voice.current = VoiceState.unavailable;
      d.start(testRoute());
      await d.feed(drive(routePath()).take(70));
      expect(d.voice.said, isEmpty);
      expect(d.nav.voiceState, VoiceState.unavailable);
    });
  });

  group('the GPS signal', () {
    test('lost after gpsLostSeconds without a fix, back with the next',
        () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()).take(3));
      expect(d.nav.gpsSignal, GpsSignal.good);
      d.now += 9000;
      d.nav.checkGps();
      expect(d.nav.gpsSignal, GpsSignal.good, reason: '9 s is not yet 10');
      d.now += 2000;
      d.nav.checkGps();
      expect(d.nav.gpsSignal, GpsSignal.lost);
      await d.feed(drive(routePath()).skip(3).take(1));
      expect(d.nav.gpsSignal, GpsSignal.good);
      await Drive.settle();
      expect(d.events.whereType<GpsSignalChanged>().map((e) => e.signal),
          [GpsSignal.lost, GpsSignal.good]);
    });

    test('weak while every fix is too rough to use', () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()).take(2));
      await d.feed([
        for (final f in drive(routePath()).skip(2).take(12))
          SimFix(f.position, speed: 10, accuracy: 2000),
      ]);
      expect(d.nav.gpsSignal, GpsSignal.weak);
    });

    test('nothing reported while not navigating, or with the check off', () {
      final d = Drive();
      d.now += 60000;
      d.nav.checkGps();
      expect(d.nav.gpsSignal, GpsSignal.good);
      final e = Drive(settings: const NavigationSettings(gpsLostSeconds: 0));
      e.start(testRoute());
      e.now += 60000;
      e.nav.checkGps();
      expect(e.nav.gpsSignal, GpsSignal.good);
    });
  });

  group('voice problems', () {
    test('a voice that tells why, and a recheck', () async {
      final voice = _DiagnosedVoice()..problem = VoiceProblem.languageMissing;
      final nav = NavigationController(
          voice: voice, strings: const GreekNavigationStrings());
      expect(nav.voiceProblem, VoiceProblem.languageMissing);
      voice.problem = VoiceProblem.none;
      await nav.recheckVoice();
      expect(voice.rechecked, ['el-GR']);
      expect(nav.voiceProblem, VoiceProblem.none);
    });

    test('a voice of your own that does not tell', () {
      final d = Drive();
      expect(d.nav.voiceProblem, VoiceProblem.none);
      d.voice.current = VoiceState.unavailable;
      expect(d.nav.voiceProblem, VoiceProblem.unknown);
    });
  });

  group('speed limits', () {
    /// The test route with 50 km/h on its first street and 30 on the rest.
    NavRoute limited() {
      final r = testRoute();
      final segments = r.points.length - 1;
      return NavRoute(
        points: r.points,
        steps: r.steps,
        distanceM: r.distanceM,
        durationS: r.durationS,
        speedLimitsKmh: [
          for (var i = 0; i < segments; i++) i < 30 ? 50.0 : 30.0,
        ],
      );
    }

    test('the limit of the road under the car, and speeding', () async {
      final d = Drive();
      d.start(limited());
      expect(d.nav.speedLimitKmh, isNull, reason: 'no fix yet');
      await d.feed(drive(routePath()).take(10));
      expect(d.nav.speedLimitKmh, 50);
      expect(d.nav.speeding, isFalse, reason: '36 km/h');
      final track = drive(routePath());
      await d.feed(track.skip(10).take(60)); // on to 700 m, the 30 street
      await d.feed([
        for (final f in track.skip(70).take(5))
          SimFix(f.position, speed: 15, heading: f.heading),
      ]);
      expect(d.nav.speedLimitKmh, 30);
      expect(d.nav.speeding, isTrue, reason: '54 km/h in a 30');
      await Drive.settle();
      expect(d.events.whereType<SpeedLimitChanged>().map((e) => e.limitKmh),
          [50, 30]);
    });

    test('no limits from the router: none shown, never speeding', () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath(), speed: 40).take(5));
      expect(d.nav.speedLimitKmh, isNull);
      expect(d.nav.speeding, isFalse);
    });
  });

  group('progress events', () {
    test('every counted fix reports progress, each maneuver passed once',
        () async {
      final d = Drive();
      d.start(testRoute());
      await d.feed(drive(routePath()).take(20));
      await Drive.settle();
      final progress = d.events.whereType<ProgressUpdated>().toList();
      expect(progress, hasLength(20));
      expect(progress.last.remainingDistance, closeTo(1300, 3));
      expect(progress.last.distanceToNextStep, closeTo(400, 3));
      expect(progress.last.remainingDuration.inSeconds, closeTo(130, 2));
      expect(progress.last.speedMps, 10);
      expect(d.events.whereType<StepChanged>(), isEmpty);

      await d.feed(drive(routePath()).skip(20).take(50));
      await Drive.settle();
      final steps = d.events.whereType<StepChanged>().toList();
      expect(steps, hasLength(1));
      expect(steps.single.step.streetName, 'Ermou');
      expect(steps.single.index, d.nav.upcomingIndex);
    });

    test('a corrected time left from the router is an event', () async {
      final d =
          Drive(settings: const NavigationSettings(etaRefreshSeconds: 30));
      d.start(testRoute(), eta: (r) async => 500);
      await d.feed(drive(routePath()).take(35));
      await Drive.settle();
      final eta = d.events.whereType<EtaUpdated>().toList();
      expect(eta, hasLength(1));
      // 500 s against 120 s planned is capped at three times: 360 s.
      expect(eta.single.remainingDuration.inSeconds, closeTo(360, 5));
    });
  });

  group('start and stop', () {
    test('navigateTo asks from the last fix and starts', () async {
      final d = Drive();
      RouteRequest? seen;
      d.nav.router = CallbackRouter(route: (r) async {
        seen = r;
        return testRoute();
      });
      expect(() => d.nav.navigateTo(endD), throwsStateError);
      d.nav.updateLocation(const NavFix(trackStart, accuracyM: 5));
      final route =
          await d.nav.navigateTo(endD, via: [cornerA], destinationName: 'Home');
      expect(seen!.points, [trackStart, cornerA, endD]);
      expect(seen!.headingDeg, isNull, reason: 'standing still');
      expect(d.nav.isActive, isTrue);
      expect(d.nav.route, same(route));
      expect(d.nav.destinationName, 'Home');
      expect(d.nav.remainingWaypoints, [cornerA]);
      await Drive.settle();
      expect(d.events.whereType<NavigationStarted>(), hasLength(1));
    });

    test('stop clears everything and says so once', () async {
      final d = Drive();
      d.start(testRoute());
      d.nav.stop();
      d.nav.stop();
      expect(d.nav.isActive, isFalse);
      expect(d.nav.upcomingStep, isNull);
      expect(d.nav.remainingLine, isEmpty);
      await Drive.settle();
      expect(d.events.whereType<NavigationStopped>(), hasLength(1));
    });

    test('fixes before the start still move the position', () {
      final d = Drive();
      d.nav.updateLocation(
          NavFix(offsetBy(trackStart, 90, 5), accuracyM: 5, headingDeg: 90));
      expect(d.nav.displayPosition, isNotNull);
      expect(d.nav.isActive, isFalse);
    });

    test('a reroute that lands after stop is dropped', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 600), (90, 300)])).take(68));
      expect(d.asked, hasLength(1));
      d.nav.stop();
      await d.complete(testRoute());
      expect(d.nav.isActive, isFalse);
      expect(d.nav.steps, isEmpty);
    });

    test('dispose with a reroute in flight does not throw', () async {
      final d = Drive()..hold = true;
      d.start(testRoute());
      await d.feed(drive(legs(trackStart, [(90, 600), (90, 300)])).take(68));
      d.nav.dispose();
      await d.complete(testRoute());
    });
  });
}

class _DiagnosedVoice implements NavigationVoice, DiagnosableVoice {
  @override
  VoiceProblem problem = VoiceProblem.none;
  final rechecked = <String>[];

  @override
  Future<void> recheck(String language) async => rechecked.add(language);
  @override
  VoiceState get state => VoiceState.unavailable;
  @override
  set onStateChanged(void Function()? callback) {}
  @override
  Future<void> init() async {}
  @override
  Future<void> prepare(String language) async {}
  @override
  void say(String text, String language) {}
  @override
  void stop() {}
}
