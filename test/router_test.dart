import 'dart:convert';

import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'support/tracks.dart';

/// An OSRM answer for the test path, the line at precision 6.
Map<String, dynamic> osrmAnswer() {
  final corner = offsetBy(trackStart, 90, 600);
  return {
    'code': 'Ok',
    'routes': [
      {
        'distance': 1500.0,
        'duration': 150.0,
        'geometry': encodePolyline(testPath(), precision: 6),
        'legs': [
          {
            'steps': [
              {
                'name': 'Egnatia',
                'distance': 600,
                'duration': 60,
                'driving_side': 'right',
                'maneuver': {
                  'type': 'depart',
                  'location': [trackStart.longitude, trackStart.latitude],
                },
              },
              {
                'name': '',
                'ref': 'EO2',
                'distance': 900,
                'duration': 90,
                'maneuver': {
                  'type': 'turn',
                  'modifier': 'left',
                  'location': [corner.longitude, corner.latitude],
                },
              },
              {
                'name': '',
                'distance': 0,
                'duration': 0,
                'maneuver': {
                  'type': 'arrive',
                  'location': [
                    testPath().last.longitude,
                    testPath().last.latitude,
                  ],
                },
              },
            ],
          },
        ],
      },
    ],
    'waypoints': [],
  };
}

void main() {
  const a = LatLng(40.63, 22.94);
  const b = LatLng(40.635, 22.95);

  group('OsrmRouter', () {
    test('asks for the full line at precision 6 with steps', () async {
      final asked = <Uri>[];
      final router = OsrmRouter(
        baseUrl: 'https://osrm.example.com/',
        client: MockClient((req) async {
          asked.add(req.url);
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      final route = await router.route(const RouteRequest(points: [a, b]));
      expect(
        asked.single.path,
        '/route/v1/driving/22.940000,40.630000;22.950000,40.635000',
      );
      expect(asked.single.queryParameters['geometries'], 'polyline6');
      expect(asked.single.queryParameters['steps'], 'true');
      expect(asked.single.queryParameters['overview'], 'full');
      expect(asked.single.queryParameters.containsKey('bearings'), isFalse);
      expect(route.usable, isTrue);
      expect(metresBetween(route.points.first, trackStart), lessThan(0.5));
      expect(route.steps[1].road, 'EO2');
    });

    test('sends the heading as a bearing on the first point only', () async {
      final asked = <Uri>[];
      final router = OsrmRouter(
        client: MockClient((req) async {
          asked.add(req.url);
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      await router.route(
        const RouteRequest(
          points: [a, b, a],
          headingDeg: 271.6,
          headingToleranceDeg: 30,
        ),
      );
      expect(asked.single.queryParameters['bearings'], '272,30;;');
    });

    test(
      'tries again without the heading when no road runs that way',
      () async {
        final asked = <Uri>[];
        final router = OsrmRouter(
          client: MockClient((req) async {
            asked.add(req.url);
            if (req.url.queryParameters.containsKey('bearings')) {
              return http.Response(
                jsonEncode({'code': 'NoSegment', 'message': 'nope'}),
                400,
              );
            }
            return http.Response(jsonEncode(osrmAnswer()), 200);
          }),
        );
        final route = await router.route(
          const RouteRequest(points: [a, b], headingDeg: 90),
        );
        expect(asked, hasLength(2));
        expect(route.usable, isTrue);
      },
    );

    test('no route is a RoutingException with the code', () async {
      final router = OsrmRouter(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({'code': 'NoRoute', 'message': 'Impossible route'}),
            400,
          ),
        ),
      );
      expect(
        () => router.route(const RouteRequest(points: [a, b])),
        throwsA(
          isA<RoutingException>()
              .having((e) => e.code, 'code', 'NoRoute')
              .having((e) => e.message, 'message', 'Impossible route'),
        ),
      );
    });

    test('a page that is not JSON is a RoutingException', () async {
      final router = OsrmRouter(
        client: MockClient(
          (req) async => http.Response('<html>bad gateway</html>', 502),
        ),
      );
      expect(
        () => router.route(const RouteRequest(points: [a, b])),
        throwsA(isA<RoutingException>()),
      );
    });

    test('eta asks for no line and reads the duration', () async {
      final asked = <Uri>[];
      final router = OsrmRouter(
        client: MockClient((req) async {
          asked.add(req.url);
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {'duration': 321.5, 'distance': 2000},
              ],
            }),
            200,
          );
        }),
      );
      expect(router.supportsEta, isTrue);
      expect(await router.eta(const RouteRequest(points: [a, b])), 321.5);
      expect(asked.single.queryParameters['overview'], 'false');
      expect(asked.single.queryParameters['steps'], 'false');
    });
  });

  group('ValhallaRouter', () {
    test('posts OSRM format, polyline6 and the heading on the start', () async {
      final bodies = <Map<String, dynamic>>[];
      final router = ValhallaRouter(
        baseUrl: 'http://localhost:8002',
        costing: 'taxi',
        language: 'el-GR',
        client: MockClient((req) async {
          expect(req.method, 'POST');
          expect(req.url.toString(), 'http://localhost:8002/route');
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      final route = await router.route(
        const RouteRequest(points: [a, b], headingDeg: 359.7),
      );
      final body = bodies.single;
      expect(body['format'], 'osrm');
      expect(body['shape_format'], 'polyline6');
      expect(body['costing'], 'taxi');
      expect(body['directions_options']['language'], 'el-GR');
      final locations = body['locations'] as List;
      expect(locations[0]['heading'], 0);
      expect(locations[0]['heading_tolerance'], 45);
      expect((locations[1] as Map).containsKey('heading'), isFalse);
      expect(route.usable, isTrue);
    });

    test('an error answer is a RoutingException', () async {
      final router = ValhallaRouter(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'error_code': 442,
              'error': 'No path could be found for input',
              'status_code': 400,
            }),
            400,
          ),
        ),
      );
      expect(
        () => router.route(const RouteRequest(points: [a, b])),
        throwsA(
          isA<RoutingException>()
              .having((e) => e.code, 'code', '442')
              .having(
                (e) => e.message,
                'message',
                'No path could be found for input',
              ),
        ),
      );
    });

    test('eta reads the trip summary with no directions', () async {
      final router = ValhallaRouter(
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['directions_options']['directions_type'], 'none');
          expect(body.containsKey('format'), isFalse);
          return http.Response(
            jsonEncode({
              'trip': {
                'summary': {'time': 412.0, 'length': 3.2},
              },
            }),
            200,
          );
        }),
      );
      expect(await router.eta(const RouteRequest(points: [a, b])), 412.0);
    });
  });

  group('rate limits and server errors', () {
    test(
      'a 429 is reported as such, with its Retry-After, asked once',
      () async {
        var asked = 0;
        final router = OsrmRouter(
          client: MockClient((req) async {
            asked++;
            return http.Response(
              jsonEncode({'message': 'Too Many Requests'}),
              429,
              headers: {'retry-after': '30'},
            );
          }),
        );
        await expectLater(
          router.route(const RouteRequest(points: [a, b], headingDeg: 90)),
          throwsA(
            isA<RoutingException>()
                .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
                .having((e) => e.statusCode, 'statusCode', 429)
                .having(
                  (e) => e.retryAfter,
                  'retryAfter',
                  const Duration(seconds: 30),
                )
                .having((e) => e.message, 'message', 'Too Many Requests'),
          ),
        );
        expect(asked, 1, reason: 'no second try without the heading');
      },
    );

    test('a 429 page that is not JSON is still a rate limit', () async {
      final router = ValhallaRouter(
        client: MockClient(
          (req) async => http.Response('<html>slow down</html>', 429),
        ),
      );
      await expectLater(
        router.route(const RouteRequest(points: [a, b])),
        throwsA(
          isA<RoutingException>()
              .having((e) => e.isRateLimited, 'isRateLimited', isTrue)
              .having((e) => e.retryAfter, 'retryAfter', isNull),
        ),
      );
    });

    test('a server error is not retried either', () async {
      var asked = 0;
      final router = ValhallaRouter(
        client: MockClient((req) async {
          asked++;
          return http.Response('bad gateway', 502);
        }),
      );
      await expectLater(
        router.route(const RouteRequest(points: [a, b], headingDeg: 10)),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.isServerError,
            'isServerError',
            isTrue,
          ),
        ),
      );
      expect(asked, 1);
    });

    test('no route keeps its HTTP status', () async {
      final router = OsrmRouter(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({'code': 'NoRoute', 'message': 'Impossible route'}),
            400,
          ),
        ),
      );
      await expectLater(
        router.route(const RouteRequest(points: [a, b])),
        throwsA(
          isA<RoutingException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.isRateLimited, 'isRateLimited', isFalse),
        ),
      );
    });
  });

  group('fallback servers', () {
    test(
      'a server that fails hands over, and the next requests stay there',
      () async {
        final hosts = <String>[];
        final router = OsrmRouter(
          baseUrl: 'https://main.example.com',
          fallbackUrls: ['https://backup.example.com/'],
          client: MockClient((req) async {
            hosts.add(req.url.host);
            if (req.url.host == 'main.example.com') {
              return http.Response('bad gateway', 502);
            }
            return http.Response(jsonEncode(osrmAnswer()), 200);
          }),
        );
        final route = await router.route(const RouteRequest(points: [a, b]));
        expect(route.usable, isTrue);
        expect(hosts, ['main.example.com', 'backup.example.com']);
        expect(router.currentUrl, 'https://backup.example.com');
        await router.route(const RouteRequest(points: [a, b]));
        expect(hosts.last, 'backup.example.com');
        expect(hosts, hasLength(3), reason: 'the dead one is not asked again');
      },
    );

    test('back to the main server after retryMainAfter', () async {
      final hosts = <String>[];
      var mainUp = false;
      final router = ValhallaRouter(
        baseUrl: 'https://main.example.com',
        fallbackUrls: ['https://backup.example.com'],
        retryMainAfter: Duration.zero,
        client: MockClient((req) async {
          hosts.add(req.url.host);
          if (req.url.host == 'main.example.com' && !mainUp) {
            throw Exception('connection refused');
          }
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      await router.route(const RouteRequest(points: [a, b]));
      mainUp = true;
      await router.route(const RouteRequest(points: [a, b]));
      expect(hosts, [
        'main.example.com',
        'backup.example.com',
        'main.example.com',
      ]);
      expect(router.currentUrl, 'https://main.example.com');
    });

    test(
      '"no route" is not asked elsewhere, all down is the last error',
      () async {
        final hosts = <String>[];
        final noRoute = OsrmRouter(
          baseUrl: 'https://main.example.com',
          fallbackUrls: ['https://backup.example.com'],
          client: MockClient((req) async {
            hosts.add(req.url.host);
            return http.Response(
              jsonEncode({'code': 'NoRoute', 'message': 'Impossible route'}),
              400,
            );
          }),
        );
        await expectLater(
          noRoute.route(const RouteRequest(points: [a, b])),
          throwsA(isA<RoutingException>()),
        );
        expect(hosts, ['main.example.com']);

        final down = OsrmRouter(
          baseUrl: 'https://main.example.com',
          fallbackUrls: ['https://backup.example.com'],
          client: MockClient((req) async => http.Response('', 503)),
        );
        await expectLater(
          down.route(const RouteRequest(points: [a, b])),
          throwsA(
            isA<RoutingException>().having(
              (e) => e.isServerError,
              'isServerError',
              isTrue,
            ),
          ),
        );
      },
    );

    test(
      'FallbackRouter mixes kinds and keeps going past a dead one',
      () async {
        final calls = <String>[];
        final router = FallbackRouter([
          CallbackRouter(
            route: (r) async {
              calls.add('valhalla');
              throw const RoutingException('down', statusCode: 503);
            },
          ),
          CallbackRouter(
            route: (r) async {
              calls.add('osrm');
              return NavRoute.fromOsrmJson(osrmAnswer());
            },
            eta: (r) async => 99,
          ),
        ]);
        expect(
          (await router.route(const RouteRequest(points: [a, b]))).usable,
          isTrue,
        );
        expect(calls, ['valhalla', 'osrm']);
        expect(router.supportsEta, isTrue);
        expect(await router.eta(const RouteRequest(points: [a, b])), 99);

        final strict = FallbackRouter([
          CallbackRouter(
            route: (r) async => throw const RoutingException(
              'no route',
              statusCode: 400,
              code: 'NoRoute',
            ),
          ),
          CallbackRouter(
            route: (r) async => NavRoute.fromOsrmJson(osrmAnswer()),
          ),
        ]);
        await expectLater(
          strict.route(const RouteRequest(points: [a, b])),
          throwsA(isA<RoutingException>()),
        );
        final loose = FallbackRouter([
          CallbackRouter(
            route: (r) async => throw const RoutingException(
              'no route',
              statusCode: 400,
              code: 'NoRoute',
            ),
          ),
          CallbackRouter(
            route: (r) async => NavRoute.fromOsrmJson(osrmAnswer()),
          ),
        ], onNoRoute: true);
        expect(
          (await loose.route(const RouteRequest(points: [a, b]))).usable,
          isTrue,
        );
      },
    );
  });

  group('speed limits from OSRM', () {
    test('off by default, nothing extra asked', () async {
      Uri? url;
      final router = OsrmRouter(
        client: MockClient((req) async {
          url = req.url;
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      await router.route(const RouteRequest(points: [a, b]));
      expect(url!.queryParameters.containsKey('annotations'), isFalse);
    });

    test(
      'asked for when on, and dropped for good when the server says no',
      () async {
        final asked = <Uri>[];
        final router = OsrmRouter(
          speedLimits: true,
          client: MockClient((req) async {
            asked.add(req.url);
            if (req.url.queryParameters['annotations'] == 'maxspeed') {
              return http.Response(
                jsonEncode({'code': 'InvalidQuery', 'message': 'malformed'}),
                400,
              );
            }
            return http.Response(jsonEncode(osrmAnswer()), 200);
          }),
        );
        final route = await router.route(const RouteRequest(points: [a, b]));
        expect(route.usable, isTrue);
        expect(asked, hasLength(2));
        await router.route(const RouteRequest(points: [a, b]));
        expect(asked, hasLength(3), reason: 'not asked for again');
        expect(asked.last.queryParameters.containsKey('annotations'), isFalse);
      },
    );
  });

  group('headers and keys', () {
    test('fixed headers and a builder asked before every request', () async {
      var token = 0;
      final seen = <Map<String, String>>[];
      final router = OsrmRouter(
        headers: {'X-Api-Key': 'abc'},
        headersBuilder: () async => {'Authorization': 'Bearer ${++token}'},
        client: MockClient((req) async {
          seen.add(req.headers);
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      await router.route(const RouteRequest(points: [a, b]));
      await router.route(const RouteRequest(points: [a, b]));
      expect(seen.map((h) => h['Authorization']), ['Bearer 1', 'Bearer 2']);
      expect(seen.every((h) => h['X-Api-Key'] == 'abc'), isTrue);
    });

    test('Valhalla takes query parameters for hosted keys', () async {
      Uri? url;
      Map<String, String>? sent;
      final router = ValhallaRouter(
        baseUrl: 'https://valhalla.example.com',
        queryParameters: {'api_key': 'k1'},
        headersBuilder: () => {'X-Trace': 't'},
        client: MockClient((req) async {
          url = req.url;
          sent = req.headers;
          return http.Response(jsonEncode(osrmAnswer()), 200);
        }),
      );
      await router.route(const RouteRequest(points: [a, b]));
      expect(url.toString(), 'https://valhalla.example.com/route?api_key=k1');
      expect(sent!['X-Trace'], 't');
      expect(sent!['Content-Type'], startsWith('application/json'));
    });
  });

  test('CallbackRouter hands the request to your code', () async {
    RouteRequest? seen;
    final router = CallbackRouter(
      route: (r) async {
        seen = r;
        return NavRoute.fromOsrmJson(osrmAnswer());
      },
    );
    final route = await router.route(const RouteRequest(points: [a, b]));
    expect(seen!.points, [a, b]);
    expect(route.usable, isTrue);
    expect(router.supportsEta, isFalse);
    expect(await router.eta(const RouteRequest(points: [a, b])), isNull);
  });
}
