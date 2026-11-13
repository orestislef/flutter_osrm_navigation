import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/tracks.dart';

Map<String, dynamic> step(String type, LatLng at,
        {String? modifier, String name = '', double distance = 100}) =>
    {
      'name': name,
      'distance': distance,
      'duration': distance / 10,
      'driving_side': 'right',
      'maneuver': {
        'type': type,
        if (modifier != null) 'modifier': modifier,
        'location': [at.longitude, at.latitude],
      },
    };

void main() {
  final cornerA = offsetBy(trackStart, 90, 600);
  final cornerB = offsetBy(cornerA, 0, 500);
  final end = offsetBy(cornerB, 90, 400);

  Map<String, dynamic> response({required Object geometry}) => {
        'code': 'Ok',
        'routes': [
          {
            'distance': 1500,
            'duration': 150,
            'geometry': geometry,
            'legs': [
              {
                'steps': [
                  step('depart', trackStart, name: 'Egnatia', distance: 600),
                  step('turn', cornerA,
                      modifier: 'left', name: 'Agias Sofias', distance: 500),
                  step('turn', cornerB, modifier: 'right', distance: 400),
                  step('arrive', end, distance: 0),
                ],
              },
            ],
          },
        ],
      };

  test('reads a whole OSRM response', () {
    final route =
        NavRoute.fromOsrmJson(response(geometry: encodePolyline(testPath())));
    expect(route.usable, isTrue);
    expect(route.distanceM, 1500);
    expect(route.durationS, 150);
    expect(route.steps.map((s) => s.maneuverType),
        ['depart', 'turn', 'turn', 'arrive']);
    expect(route.steps[1].modifier, 'left');
    expect(route.steps[1].road, 'Agias Sofias');
    expect(metresBetween(route.steps[1].location, cornerA), lessThan(0.5));
    expect(metresBetween(route.points.last, end), lessThan(2));
    expect(route.waypoints, isEmpty);
  });

  test('works out polyline precision 6 on its own', () {
    final route = NavRoute.fromOsrmJson(
        response(geometry: encodePolyline(testPath(), precision: 6)));
    expect(metresBetween(route.points.first, trackStart), lessThan(0.5));
    expect(metresBetween(route.points.last, end), lessThan(0.5));
  });

  test('reads a GeoJSON line', () {
    final route = NavRoute.fromOsrmJson(response(geometry: {
      'type': 'LineString',
      'coordinates': [
        for (final p in testPath()) [p.longitude, p.latitude],
      ],
    }));
    expect(route.points, hasLength(testPath().length));
  });

  test('a single route object is fine too', () {
    final json = response(geometry: encodePolyline(testPath()));
    final route = NavRoute.fromOsrmJson(
        Map<String, dynamic>.from((json['routes'] as List).first as Map));
    expect(route.steps, hasLength(4));
  });

  test('a route through a stop keeps every leg and finds the stop', () {
    final json = {
      'code': 'Ok',
      'routes': [
        {
          'distance': 1100,
          'duration': 110,
          'geometry': encodePolyline(legs(trackStart, [(90, 600), (0, 500)])),
          'legs': [
            {
              'steps': [
                step('depart', trackStart, distance: 600),
                step('arrive', cornerA, distance: 0),
              ],
            },
            {
              'steps': [
                step('depart', cornerA, distance: 500),
                step('arrive', cornerB, distance: 0),
              ],
            },
          ],
        },
      ],
    };
    final route = NavRoute.fromOsrmJson(json);
    expect(route.steps, hasLength(4));
    expect(route.steps.map((s) => s.legIndex), [0, 0, 1, 1]);
    expect(route.waypoints, hasLength(1));
    expect(metresBetween(route.waypoints.single, cornerA), lessThan(0.5));
  });

  test('bad input fails loudly, odd steps do not', () {
    expect(() => NavRoute.fromOsrmJson({'code': 'NoRoute'}),
        throwsFormatException);
    final s = NavStep.fromOsrmJson({
      'maneuver': {'location': 'nowhere'},
    });
    expect(s.location, const LatLng(0, 0));
    expect(s.maneuverType, 'turn');
    expect(s.drivingSide, 'right');
  });
}
