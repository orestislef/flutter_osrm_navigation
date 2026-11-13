import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_osrm_navigation/src/off_route.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tracks.dart';

void main() {
  group('RerouteGate', () {
    test('one at a time, then waits that double up to the cap', () {
      final gate = RerouteGate(const NavigationSettings(
          rerouteMinSeconds: 10, rerouteRetryMaxSeconds: 35));
      expect(gate.canAsk(0), isTrue);
      gate.asked(0);
      expect(gate.canAsk(60000), isFalse, reason: 'one is out');
      gate.answered(1000, ok: false);
      expect(gate.canAsk(10999), isFalse);
      expect(gate.canAsk(11000), isTrue);
      gate.asked(11000);
      gate.answered(12000, ok: false);
      expect(gate.canAsk(31999), isFalse, reason: '20 s after two failures');
      expect(gate.canAsk(32000), isTrue);
      gate.asked(32000);
      gate.answered(33000, ok: false);
      expect(gate.canAsk(67999), isFalse, reason: 'capped at 35 s');
      expect(gate.canAsk(68000), isTrue);
      gate.asked(68000);
      gate.answered(69000, ok: true);
      expect(gate.failures, 0);
      expect(gate.canAsk(79000), isTrue);
    });
  });

  group('OffRouteDetector', () {
    final line = RouteLine(testPath());
    final end = line.points.last;

    FixVerdict judge(OffRouteDetector d, NavFix f) =>
        d.judge(f, line.match(f.position)!, line, end);

    test('needs three fixes in a row off the line while moving', () {
      final d = OffRouteDetector(const NavigationSettings());
      var t = 0;
      // 300 m along, then 80 m north of the line.
      for (var i = 0; i < 3; i++) {
        t += 1000;
        final p = offsetBy(offsetBy(trackStart, 90, 300 + i * 10.0), 0, 80);
        final v = judge(
            d, NavFix(p, accuracyM: 5, speedMps: 10, headingDeg: 90, atMs: t));
        expect(v, FixVerdict.offRoute);
        expect(d.offRoute, i == 2);
      }
    });

    test('ignores an imprecise fix and a jump', () {
      final d = OffRouteDetector(const NavigationSettings());
      final p = offsetBy(trackStart, 90, 300);
      expect(judge(d, NavFix(p, accuracyM: 80, atMs: 1000)), FixVerdict.bad);
      judge(d, NavFix(p, accuracyM: 5, speedMps: 10, atMs: 2000));
      final far = offsetBy(p, 0, 2000);
      expect(judge(d, NavFix(far, accuracyM: 5, atMs: 3000)), FixVerdict.bad);
    });

    test('standing still is not counted', () {
      final d = OffRouteDetector(const NavigationSettings());
      final p = offsetBy(offsetBy(trackStart, 90, 300), 0, 80);
      expect(judge(d, NavFix(p, accuracyM: 5, speedMps: 0, atMs: 1000)),
          FixVerdict.still);
    });

    test('driving back along the line is the wrong way', () {
      final d = OffRouteDetector(const NavigationSettings());
      var t = 0;
      for (var i = 0; i < 3; i++) {
        t += 1000;
        final p = offsetBy(trackStart, 90, 400 - i * 10.0);
        final v = judge(
            d, NavFix(p, accuracyM: 5, speedMps: 10, headingDeg: 270, atMs: t));
        expect(v, FixVerdict.wrongWay);
      }
      expect(d.wrongWay, isTrue);
      expect(d.offRoute, isTrue);
    });
  });
}
