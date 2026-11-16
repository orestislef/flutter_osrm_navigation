import 'package:fake_async/fake_async.dart';
import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/drive.dart';

void main() {
  NavigationController controller(FakeAsync async, RecordingVoice voice) =>
      NavigationController(
        voice: voice,
        clock: () => async.elapsed.inMilliseconds,
      );

  test('drives the route to the end and arrives', () {
    fakeAsync((async) {
      final voice = RecordingVoice();
      final nav = controller(async, voice)..start(testRoute());
      final sim = RouteSimulator(nav, speedKmh: 36);
      sim.start();
      expect(sim.isRunning, isTrue);
      async.elapse(const Duration(seconds: 60));
      expect(nav.remainingDistance, closeTo(900, 15));
      async.elapse(const Duration(seconds: 100));
      expect(nav.arrived, isTrue);
      expect(sim.isRunning, isFalse);
      expect(voice.said.first, 'In 600 meters, turn left onto Agias Sofias');
      expect(voice.said.last, 'You are at the destination');
      expect(nav.speedMps, 0, reason: 'parked at the end, not still at 36');
    });
  });

  test('a new drive starts at the start, wherever the last one ended', () {
    fakeAsync((async) {
      final nav = controller(async, RecordingVoice())..start(testRoute());
      final sim = RouteSimulator(nav, speedKmh: 36)..start();
      async.elapse(const Duration(seconds: 140));
      sim.stop();
      nav.stop();
      async.elapse(const Duration(seconds: 1));
      nav.start(testRoute());
      sim.start();
      async.elapse(const Duration(seconds: 2));
      expect(nav.remainingDistance, closeTo(1480, 15));
      expect(nav.arrived, isFalse);
    });
  });

  test('stops when navigation stops', () {
    fakeAsync((async) {
      final nav = controller(async, RecordingVoice())..start(testRoute());
      final sim = RouteSimulator(nav)..start();
      async.elapse(const Duration(seconds: 5));
      nav.stop();
      expect(sim.isRunning, isFalse);
    });
  });

  test('nothing to drive without a route', () {
    fakeAsync((async) {
      final nav = controller(async, RecordingVoice());
      final sim = RouteSimulator(nav)..start();
      expect(sim.isRunning, isFalse);
    });
  });

  group('leaving the route on purpose', () {
    /// A controller whose router answers with a straight route east from
    /// wherever it is asked, and records the requests.
    (NavigationController, List<RouteRequest>, RecordingVoice) rerouting(
        FakeAsync async) {
      final asked = <RouteRequest>[];
      final voice = RecordingVoice();
      final nav = NavigationController(
        voice: voice,
        clock: () => async.elapsed.inMilliseconds,
        router: CallbackRouter(route: (r) async {
          asked.add(r);
          return navRoute(r.points.first, [(90, 400, 'Detour')]);
        }),
      );
      return (nav, asked, voice);
    }

    test('a missed turn: off the route, a new route, and on along it', () {
      fakeAsync((async) {
        final (nav, asked, voice) = rerouting(async);
        nav.start(testRoute());
        final sim = RouteSimulator(nav, speedKmh: 36)..start();
        // 550 m along, 50 m before the left turn: carry straight on.
        async.elapse(const Duration(seconds: 55));
        sim.missTurn();
        expect(sim.mode, SimulatorMode.straight);
        // 50 m to the corner, then three fixes more than 50 m off the line.
        async.elapse(const Duration(seconds: 15));
        expect(asked, hasLength(1));
        expect(asked.single.headingDeg, closeTo(90, 1));
        expect(voice.said, contains('Recalculating the route'));
        expect(sim.mode, SimulatorMode.follow, reason: 'on the new route');
        expect(nav.upcomingStep!.streetName, 'Detour');
        async.elapse(const Duration(seconds: 60));
        expect(nav.arrived, isTrue);
        expect(asked, hasLength(1), reason: 'no more reroutes once back on');
      });
    });

    test('turning around: the wrong way, a new route starting that way', () {
      fakeAsync((async) {
        final (nav, asked, _) = rerouting(async);
        nav.start(testRoute());
        final sim = RouteSimulator(nav, speedKmh: 36)..start();
        async.elapse(const Duration(seconds: 30));
        sim.turnAround();
        async.elapse(const Duration(seconds: 6));
        expect(asked, hasLength(1));
        expect(asked.single.headingDeg, closeTo(270, 1));
        expect(sim.mode, SimulatorMode.follow);
      });
    });
  });
}
