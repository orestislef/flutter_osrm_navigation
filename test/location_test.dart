import 'dart:async';

import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'support/drive.dart';

Position position({double speed = 12, double heading = 90}) => Position(
  latitude: 40.63,
  longitude: 22.94,
  timestamp: DateTime(2026),
  accuracy: 6,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  test('a geolocator position becomes a fix', () {
    final fix = NavigationLocation.fromPosition(position());
    expect(fix.position.latitude, 40.63);
    expect(fix.accuracyM, 6);
    expect(fix.speedMps, 12);
    expect(fix.headingDeg, 90);
  });

  test('unknown speed and heading are left out', () {
    final fix = NavigationLocation.fromPosition(
      position(speed: -1, heading: -1),
    );
    expect(fix.speedMps, isNull);
    expect(fix.headingDeg, isNull);
  });

  test(
    'an attached stream drives the controller and its errors do not',
    () async {
      final d = Drive();
      final fixes = StreamController<NavFix>();
      final errors = <Object>[];
      d.nav.attachLocation(fixes.stream, onError: errors.add);
      d.start(testRoute());
      fixes.add(NavFix(offsetBy(trackStart, 90, 50), accuracyM: 5));
      fixes.addError(StateError('permission gone'));
      fixes.add(NavFix(offsetBy(trackStart, 90, 60), accuracyM: 5));
      await Drive.settle();
      expect(errors, hasLength(1));
      expect(d.nav.isActive, isTrue);
      expect(d.nav.remainingDistance, closeTo(1440, 3));
      d.nav.detachLocation();
      fixes.add(NavFix(offsetBy(trackStart, 90, 100), accuracyM: 5));
      await Drive.settle();
      expect(d.nav.remainingDistance, closeTo(1440, 3));
      await fixes.close();
    },
  );
}
