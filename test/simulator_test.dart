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
}
