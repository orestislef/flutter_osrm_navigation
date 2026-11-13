import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'route.dart';

/// What to ask a router for.
class RouteRequest {
  /// Creates a request through [points] in order.
  const RouteRequest({
    required this.points,
    this.headingDeg,
    this.headingToleranceDeg = 45,
  });

  /// The start, any stops, and the end. At least two.
  final List<LatLng> points;

  /// The way the user is heading at the start, degrees from north. When
  /// set the route starts that way rather than with a U-turn.
  final double? headingDeg;

  /// How far either side of [headingDeg] the route may start.
  final int headingToleranceDeg;

  /// The same request without a heading.
  RouteRequest withoutHeading() => RouteRequest(points: points);
}

/// A router could not give a route.
class RoutingException implements Exception {
  /// Creates the exception.
  const RoutingException(this.message, {this.statusCode, this.code});

  /// What went wrong.
  final String message;

  /// HTTP status, when the router answered.
  final int? statusCode;

  /// The router's own error code (`NoRoute`, `NoSegment`, a Valhalla error
  /// number), when it sent one.
  final String? code;

  @override
  String toString() => 'RoutingException: $message'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}'
      '${code == null ? '' : ' [$code]'}';
}

/// Something that gives routes.
///
/// Use [OsrmRouter] or [ValhallaRouter] for a server you can reach
/// directly, or [CallbackRouter] when routes come through your own backend.
abstract class NavRouter {
  /// Const constructor for subclasses.
  const NavRouter();

  /// A route for [request]. Throws a [RoutingException] when there is none.
  Future<NavRoute> route(RouteRequest request);

  /// Seconds left from the first point of [request] to its last, or null
  /// when the router cannot tell. Used now and then while navigating to
  /// correct the time left (traffic, when the router knows it).
  Future<double?> eta(RouteRequest request) async => null;

  /// Whether [eta] gives anything.
  bool get supportsEta => false;
}

/// Routes from your own code, for when routes come through your backend.
///
/// ```dart
/// final router = CallbackRouter(
///   route: (request) async {
///     final json = await myApi.directions(request.points);
///     return NavRoute.fromOsrmJson(json);
///   },
/// );
/// ```
class CallbackRouter extends NavRouter {
  /// Creates a router that calls [route] and, when given, [eta].
  const CallbackRouter({
    required Future<NavRoute> Function(RouteRequest request) route,
    Future<double?> Function(RouteRequest request)? eta,
  })  : _route = route,
        _eta = eta;

  final Future<NavRoute> Function(RouteRequest request) _route;
  final Future<double?> Function(RouteRequest request)? _eta;

  @override
  Future<NavRoute> route(RouteRequest request) => _route(request);

  @override
  Future<double?> eta(RouteRequest request) async =>
      _eta == null ? null : await _eta(request);

  @override
  bool get supportsEta => _eta != null;
}

/// Shared HTTP plumbing for the built in routers.
abstract class _HttpRouter extends NavRouter {
  _HttpRouter({
    required String baseUrl,
    Map<String, String>? headers,
    http.Client? client,
    required this.timeout,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        headers = {
          // Browsers refuse to let a page set the user agent.
          if (!kIsWeb) 'User-Agent': 'flutter_osrm_navigation',
          ...?headers,
        },
        _client = client;

  /// The server, without a trailing slash.
  final String baseUrl;

  /// Sent with every request (an API key, a user agent).
  final Map<String, String> headers;

  /// How long one request may take.
  final Duration timeout;

  final http.Client? _client;

  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function(http.Client c) send) async {
    final own = _client == null;
    final client = _client ?? http.Client();
    try {
      final res = await send(client).timeout(timeout);
      Object? body;
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
      if (body is! Map) {
        throw RoutingException('The router did not answer with JSON',
            statusCode: res.statusCode);
      }
      return Map<String, dynamic>.from(body);
    } on TimeoutException {
      throw const RoutingException('The router took too long');
    } on RoutingException {
      rethrow;
    } catch (e) {
      throw RoutingException('Could not reach the router: $e');
    } finally {
      if (own) client.close();
    }
  }
}

/// Routes from an OSRM server.
///
/// The default [baseUrl] is OSRM's public demo server. It is fine for
/// trying things out, but it has a strict usage policy, so run your own for
/// anything real.
class OsrmRouter extends _HttpRouter {
  /// Creates a router for the OSRM server at [baseUrl].
  ///
  /// [profile] is the profile in the URL, usually `driving`.
  /// [queryParameters] are added to every request (`exclude=toll`,
  /// `annotations=true`).
  OsrmRouter({
    super.baseUrl = 'https://router.project-osrm.org',
    this.profile = 'driving',
    this.queryParameters = const {},
    super.headers,
    super.client,
    super.timeout = const Duration(seconds: 12),
  });

  /// Profile in the URL.
  final String profile;

  /// Extra query parameters for every request.
  final Map<String, String> queryParameters;

  Uri _uri(RouteRequest r, {required bool full}) {
    final coords = r.points
        .map((p) => '${p.longitude.toStringAsFixed(6)},'
            '${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final heading = r.headingDeg;
    return Uri.parse('$baseUrl/route/v1/$profile/$coords').replace(
      queryParameters: {
        'alternatives': 'false',
        if (full) ...{
          'overview': 'full',
          'geometries': 'polyline6',
          'steps': 'true',
        } else ...{
          'overview': 'false',
          'steps': 'false',
        },
        if (heading != null && heading >= 0)
          'bearings': [
            '${heading.round() % 360},${r.headingToleranceDeg.clamp(0, 180)}',
            for (var i = 1; i < r.points.length; i++) '',
          ].join(';'),
        ...queryParameters,
      },
    );
  }

  Future<Map<String, dynamic>> _ask(RouteRequest r, {required bool full}) {
    if (r.points.length < 2) {
      throw const RoutingException('A route needs at least two points');
    }
    return _send((c) => c.get(_uri(r, full: full), headers: headers));
  }

  /// OSRM's answer, retried without the heading when no road there runs
  /// that way.
  Future<Map<String, dynamic>> _askWithFallback(RouteRequest r,
      {required bool full}) async {
    var json = await _ask(r, full: full);
    if (json['code'] != 'Ok' && r.headingDeg != null) {
      json = await _ask(r.withoutHeading(), full: full);
    }
    if (json['code'] != 'Ok') {
      throw RoutingException(
          '${json['message'] ?? 'No route between these points'}',
          code: json['code']?.toString());
    }
    return json;
  }

  @override
  Future<NavRoute> route(RouteRequest request) async {
    final json = await _askWithFallback(request, full: true);
    return NavRoute.fromOsrmJson(json, precision: 6);
  }

  @override
  Future<double?> eta(RouteRequest request) async {
    final json = await _askWithFallback(request, full: false);
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
    return ((routes.first as Map)['duration'] as num?)?.toDouble();
  }

  @override
  bool get supportsEta => true;
}

/// Routes from a Valhalla server, asked for in OSRM's shape.
///
/// The default [baseUrl] is the public FOSSGIS server. Fine to try things
/// with, run your own for anything real.
class ValhallaRouter extends _HttpRouter {
  /// Creates a router for the Valhalla server at [baseUrl].
  ///
  /// [costing] is Valhalla's costing model (`auto`, `taxi`, `bus`,
  /// `truck`, `motor_scooter`, `bicycle`, `pedestrian`). [costingOptions]
  /// goes into `costing_options` as is. [language] is the language of the
  /// router's own instruction text ([NavStep.routerInstruction]).
  ValhallaRouter({
    super.baseUrl = 'https://valhalla1.openstreetmap.de',
    this.costing = 'auto',
    this.costingOptions,
    this.language = 'en-US',
    super.headers,
    super.client,
    super.timeout = const Duration(seconds: 12),
  });

  /// Costing model.
  final String costing;

  /// Extra costing options, sent as `costing_options`.
  final Map<String, dynamic>? costingOptions;

  /// Language of the router's instruction text.
  final String language;

  List<Map<String, dynamic>> _locations(RouteRequest r) {
    final heading = r.headingDeg;
    return [
      for (var i = 0; i < r.points.length; i++)
        {
          'lat': r.points[i].latitude,
          'lon': r.points[i].longitude,
          if (i == 0 && heading != null && heading >= 0) ...{
            'heading': heading.round() % 360,
            'heading_tolerance': r.headingToleranceDeg.clamp(0, 180),
          },
        },
    ];
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) {
    return _send((c) => c.post(
          Uri.parse('$baseUrl/route'),
          headers: {'Content-Type': 'application/json', ...headers},
          body: jsonEncode(body),
        ));
  }

  Map<String, dynamic> _body(RouteRequest r, {required bool full}) => {
        'locations': _locations(r),
        'costing': costing,
        if (costingOptions != null) 'costing_options': costingOptions,
        if (full) ...{
          'format': 'osrm',
          'shape_format': 'polyline6',
          'directions_options': {'units': 'kilometers', 'language': language},
        } else
          'directions_options': {'directions_type': 'none'},
      };

  static String? _error(Map<String, dynamic> json) {
    if (json['code'] == 'Ok' || json['trip'] is Map) return null;
    return '${json['error'] ?? json['message'] ?? 'No route between these points'}';
  }

  Future<Map<String, dynamic>> _ask(RouteRequest r,
      {required bool full}) async {
    if (r.points.length < 2) {
      throw const RoutingException('A route needs at least two points');
    }
    var json = await _post(_body(r, full: full));
    if (_error(json) != null && r.headingDeg != null) {
      json = await _post(_body(r.withoutHeading(), full: full));
    }
    final error = _error(json);
    if (error != null) {
      throw RoutingException(error,
          code: (json['error_code'] ?? json['code'])?.toString());
    }
    return json;
  }

  @override
  Future<NavRoute> route(RouteRequest request) async {
    final json = await _ask(request, full: true);
    return NavRoute.fromOsrmJson(json, precision: 6);
  }

  @override
  Future<double?> eta(RouteRequest request) async {
    final json = await _ask(request, full: false);
    final trip = json['trip'];
    final summary = trip is Map ? trip['summary'] : null;
    if (summary is! Map) return null;
    return (summary['time'] as num?)?.toDouble();
  }

  @override
  bool get supportsEta => true;
}
