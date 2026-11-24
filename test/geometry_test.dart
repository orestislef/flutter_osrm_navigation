import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/tracks.dart';

void main() {
  group('RouteLine', () {
    test(
      'matches a position to the nearest point, measured along the line',
      () {
        final line = RouteLine(testPath());
        expect(line.lengthM, closeTo(1500, 3));
        final m = line.match(offsetBy(offsetBy(trackStart, 90, 250), 0, 12))!;
        expect(m.distanceM, closeTo(12, 0.5));
        expect(m.alongM, closeTo(250, 1));
        expect(m.bearing, closeTo(90, 1));
      },
    );

    test(
      'remainingFrom starts at the exact point and drops what is behind',
      () {
        final line = RouteLine(testPath());
        final rest = line.remainingFrom(250);
        expect(
          metresBetween(rest.first, offsetBy(trackStart, 90, 250)),
          lessThan(1),
        );
        expect(RouteLine(rest).lengthM, closeTo(1250, 3));
        final behind = line.traveledTo(250);
        expect(RouteLine(behind).lengthM, closeTo(250, 1));
        expect(metresBetween(behind.last, rest.first), lessThan(0.01));
      },
    );

    test(
      'the direction of travel picks the pass when a street is used twice',
      () {
        // 300 m east, then back 300 m west on the same street.
        final line = RouteLine(legs(trackStart, [(90, 300), (270, 300)]));
        final p = offsetBy(trackStart, 90, 100);
        expect(
          line.match(p, headingDeg: 90, againstPenaltyM: 30)!.alongM,
          closeTo(100, 1),
        );
        expect(
          line.match(p, headingDeg: 270, againstPenaltyM: 30)!.alongM,
          closeTo(500, 1),
        );
      },
    );

    test('a window along the line limits the search', () {
      final line = RouteLine(legs(trackStart, [(90, 300), (270, 300)]));
      final p = offsetBy(trackStart, 90, 100);
      expect(line.match(p, fromM: 350)!.alongM, closeTo(500, 1));
    });

    test('repeated points are kept once and a single point is empty', () {
      final a = trackStart;
      final b = offsetBy(a, 0, 100);
      final line = RouteLine([a, a, b, b]);
      expect(line.points, hasLength(2));
      expect(RouteLine([a, a]).isEmpty, isTrue);
      expect(RouteLine([a]).match(b), isNull);
    });

    test('pointAt and bearingAt clamp to the ends', () {
      final line = RouteLine(testPath());
      expect(line.pointAt(-5), line.points.first);
      expect(line.pointAt(99999), line.points.last);
      expect(line.bearingAt(100), closeTo(90, 1));
      expect(line.bearingAt(800), closeTo(0, 1));
    });
  });

  group('helpers', () {
    test('metresBetween and offsetBy agree', () {
      final b = offsetBy(trackStart, 45, 1000);
      expect(metresBetween(trackStart, b), closeTo(1000, 2));
      expect(bearingBetween(trackStart, b), closeTo(45, 0.5));
    });

    test('angleBetween is the short way round', () {
      expect(angleBetween(10, 350), 20);
      expect(angleBetween(350, 10), 20);
      expect(angleBetween(0, 180), 180);
      expect(angleBetween(90, 90), 0);
    });
  });

  group('polyline', () {
    test('decodes the reference string from the format docs', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 1e-9));
      expect(points[0].longitude, closeTo(-120.2, 1e-9));
      expect(points[2].latitude, closeTo(43.252, 1e-9));
      expect(points[2].longitude, closeTo(-126.453, 1e-9));
    });

    test('round trips at precision 5 and 6, south and west included', () {
      final path = [
        const LatLng(-33.86785, 151.20732),
        const LatLng(40.63, 22.94),
        const LatLng(-22.906847, -43.172897),
      ];
      for (final precision in [5, 6]) {
        final decoded = decodePolyline(
          encodePolyline(path, precision: precision),
          precision: precision,
        );
        expect(decoded, hasLength(3));
        for (var i = 0; i < path.length; i++) {
          expect(metresBetween(decoded[i], path[i]), lessThan(1.5));
        }
      }
    });

    test('a cut string keeps what came before the cut', () {
      final full = encodePolyline(testPath());
      final cut = decodePolyline(full.substring(0, full.length - 3));
      expect(cut, isNotEmpty);
      expect(cut.length, lessThan(testPath().length));
      expect(decodePolyline(null), isEmpty);
      expect(decodePolyline(''), isEmpty);
    });
  });
}
