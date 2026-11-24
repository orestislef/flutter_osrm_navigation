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
  const RoutingException(
    this.message, {
    this.statusCode,
    this.code,
    this.retryAfter,
  });

  /// What went wrong.
  final String message;

  /// HTTP status, when the router answered.
  final int? statusCode;

  /// The router's own error code (`NoRoute`, `NoSegment`, a Valhalla error
  /// number), when it sent one.
  final String? code;

  /// How long the router asked to wait before the next request (its
  /// `Retry-After`), when it said.
  final Duration? retryAfter;

  /// The router said too many requests (HTTP 429). Public demo servers do
  /// this quickly.
  bool get isRateLimited => statusCode == 429;

  /// The router had a problem of its own (HTTP 5xx).
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() =>
      'RoutingException: $message'
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
  }) : _route = route,
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

/// Asks several routers in order, the next one when a router is down,
/// slow, rate limited or failing.
///
/// For mixing kinds, say your own Valhalla first and an OSRM behind it:
///
/// ```dart
/// final router = FallbackRouter([
///   ValhallaRouter(baseUrl: 'https://valhalla.example.com'),
///   OsrmRouter(baseUrl: 'https://osrm.example.com'),
/// ]);
/// ```
///
/// A plain "no route between these points" is not asked elsewhere unless
/// [onNoRoute] is true (routers with different map data may disagree).
/// For several servers of one kind, `fallbackUrls` on [OsrmRouter] and
/// [ValhallaRouter] does the same with one router.
class FallbackRouter extends NavRouter {
  /// Creates a router that asks [routers] in order.
  FallbackRouter(List<NavRouter> routers, {this.onNoRoute = false})
    : assert(routers.isNotEmpty, 'FallbackRouter needs a router'),
      routers = List.unmodifiable(routers);

  /// The routers, first asked first.
  final List<NavRouter> routers;

  /// Ask the next router also when one says there is no route.
  final bool onNoRoute;

  bool _next(Object e) {
    if (e is! RoutingException) return true;
    if (onNoRoute) return true;
    return e.statusCode == null ||
        e.isRateLimited ||
        e.isServerError ||
        e.code == 'NotJson';
  }

  @override
  Future<NavRoute> route(RouteRequest request) async {
    Object? last;
    for (var i = 0; i < routers.length; i++) {
      try {
        return await routers[i].route(request);
      } catch (e) {
        last = e;
        if (i == routers.length - 1 || !_next(e)) rethrow;
      }
    }
    throw last!;
  }

  @override
  Future<double?> eta(RouteRequest request) async {
    for (final r in routers) {
      if (!r.supportsEta) continue;
      try {
        final seconds = await r.eta(request);
        if (seconds != null) return seconds;
      } catch (e) {
        if (!_next(e)) rethrow;
      }
    }
    return null;
  }

  @override
  bool get supportsEta => routers.any((r) => r.supportsEta);
}

/// Shared HTTP plumbing for the built in routers.
abstract class _HttpRouter extends NavRouter {
  _HttpRouter({
    required String baseUrl,
    List<String> fallbackUrls = const [],
    this.retryMainAfter = const Duration(minutes: 5),
    Map<String, String>? headers,
    this.headersBuilder,
    http.Client? client,
    required this.timeout,
  }) : baseUrl = _trim(baseUrl),
       fallbackUrls = List.unmodifiable(fallbackUrls.map(_trim)),
       headers = {
         // Browsers refuse to let a page set the user agent.
         if (!kIsWeb) 'User-Agent': 'flutter_osrm_navigation',
         ...?headers,
       },
       _client = client;

  static String _trim(String url) => url.replaceAll(RegExp(r'/+$'), '');

  /// The server, without a trailing slash.
  final String baseUrl;

  /// Servers to try, in order, when [baseUrl] is down, too slow, rate
  /// limited or failing (no answer, a timeout, HTTP 429 or 5xx). "No route"
  /// is not tried elsewhere, the same map data would say the same.
  final List<String> fallbackUrls;

  /// After falling back, requests stay on the server that answered, and
  /// [baseUrl] is tried first again once this long has passed.
  final Duration retryMainAfter;

  /// Index into [baseUrl] then [fallbackUrls] of the server asked first.
  int _preferred = 0;
  DateTime? _preferredSince;

  /// The server that answered last, [baseUrl] until a fallback had to be
  /// used.
  String get currentUrl =>
      _preferred == 0 ? baseUrl : fallbackUrls[_preferred - 1];

  /// Sent with every request (an API key, a user agent).
  final Map<String, String> headers;

  /// Called before every request for headers that change, such as a token
  /// that expires. They go over [headers].
  final FutureOr<Map<String, String>> Function()? headersBuilder;

  /// How long one request may take.
  final Duration timeout;

  final http.Client? _client;

  /// [headers] with whatever [headersBuilder] gives now.
  Future<Map<String, String>> _headers() async {
    final build = headersBuilder;
    if (build == null) return headers;
    return {...headers, ...await build()};
  }

  /// `Retry-After` in seconds. The date form is rare and left out.
  static Duration? _retryAfter(http.Response res) {
    final value = res.headers['retry-after'];
    final seconds = value == null ? null : int.tryParse(value.trim());
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// Whether [e] is the server's fault, worth asking another server.
  static bool _serverFault(RoutingException e) =>
      e.statusCode == null ||
      e.isRateLimited ||
      e.isServerError ||
      e.code == 'NotJson';

  /// The router's JSON answer from the first server that gives one: the
  /// preferred one, then the rest in order.
  Future<({Map<String, dynamic> json, int statusCode})> _send(
    Future<http.Response> Function(
      http.Client c,
      Map<String, String> h,
      String base,
    )
    send,
  ) async {
    final bases = [baseUrl, ...fallbackUrls];
    if (bases.length == 1) return _sendTo(baseUrl, send);
    final since = _preferredSince;
    if (_preferred != 0 &&
        since != null &&
        DateTime.now().difference(since) >= retryMainAfter) {
      _preferred = 0;
      _preferredSince = null;
    }
    final order = [
      _preferred,
      for (var i = 0; i < bases.length; i++)
        if (i != _preferred) i,
    ];
    RoutingException? last;
    for (final i in order) {
      try {
        final answer = await _sendTo(bases[i], send);
        if (i != _preferred) {
          _preferred = i;
          _preferredSince = i == 0 ? null : DateTime.now();
        }
        return answer;
      } on RoutingException catch (e) {
        if (!_serverFault(e)) rethrow;
        last = e;
      }
    }
    throw last!;
  }

  /// The JSON answer of the server at [base], with [statusCode] filled in.
  ///
  /// Too many requests (429) and server errors (5xx) throw right away, so
  /// nothing asks the same server again in the same breath.
  Future<({Map<String, dynamic> json, int statusCode})> _sendTo(
    String base,
    Future<http.Response> Function(
      http.Client c,
      Map<String, String> h,
      String base,
    )
    send,
  ) async {
    final own = _client == null;
    final client = _client ?? http.Client();
    try {
      final res = await send(client, await _headers(), base).timeout(timeout);
      Object? body;
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
      final json = body is Map ? Map<String, dynamic>.from(body) : null;
      final status = res.statusCode;
      if (status == 429 || status >= 500) {
        final said = json?['message'] ?? json?['error'];
        throw RoutingException(
          said is String && said.isNotEmpty
              ? said
              : (status == 429
                    ? 'The router says too many requests'
                    : 'The router had a problem'),
          statusCode: status,
          code: (json?['code'] ?? json?['error_code'])?.toString(),
          retryAfter: _retryAfter(res),
        );
      }
      if (json == null) {
        throw RoutingException(
          'The router did not answer with JSON',
          statusCode: status,
          code: 'NotJson',
        );
      }
      return (json: json, statusCode: status);
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
  /// [queryParameters] are added to every request (`exclude=toll`).
  /// [fallbackUrls] are other servers to ask when [baseUrl] is down, slow,
  /// rate limited or failing.
  /// [speedLimits] asks for `annotations=maxspeed`, the speed limit of
  /// every stretch of the route. Plain OSRM does not know it (Mapbox
  /// compatible servers do), so it is off by default. A server that turns
  /// it down is asked again without it, and not asked for it again.
  OsrmRouter({
    super.baseUrl = 'https://router.project-osrm.org',
    this.profile = 'driving',
    this.queryParameters = const {},
    this.speedLimits = false,
    super.fallbackUrls,
    super.retryMainAfter,
    super.headers,
    super.headersBuilder,
    super.client,
    super.timeout = const Duration(seconds: 12),
  });

  /// Profile in the URL.
  final String profile;

  /// Extra query parameters for every request.
  final Map<String, String> queryParameters;

  /// Ask for the speed limits along the route.
  final bool speedLimits;

  /// The server turned `annotations=maxspeed` down once.
  bool _noMaxspeed = false;

  bool get _askMaxspeed =>
      speedLimits &&
      !_noMaxspeed &&
      !queryParameters.containsKey('annotations');

  Uri _uri(String base, RouteRequest r, {required bool full}) {
    final coords = r.points
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},'
              '${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    final heading = r.headingDeg;
    return Uri.parse('$base/route/v1/$profile/$coords').replace(
      queryParameters: {
        'alternatives': 'false',
        if (full) ...{
          'overview': 'full',
          'geometries': 'polyline6',
          'steps': 'true',
          if (_askMaxspeed) 'annotations': 'maxspeed',
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

  Future<({Map<String, dynamic> json, int statusCode})> _ask(
    RouteRequest r, {
    required bool full,
  }) {
    if (r.points.length < 2) {
      throw const RoutingException('A route needs at least two points');
    }
    return _send((c, h, base) => c.get(_uri(base, r, full: full), headers: h));
  }

  /// OSRM's answer, retried without the heading when no road there runs
  /// that way. A rate limit or a server error is not retried here.
  Future<Map<String, dynamic>> _askWithFallback(
    RouteRequest r, {
    required bool full,
  }) async {
    final askedMaxspeed = full && _askMaxspeed;
    var answer = await _ask(r, full: full);
    if (askedMaxspeed && answer.json['code'] == 'InvalidQuery') {
      // An older or slimmer OSRM that does not know maxspeed.
      _noMaxspeed = true;
      answer = await _ask(r, full: full);
    }
    if (answer.json['code'] != 'Ok' && r.headingDeg != null) {
      answer = await _ask(r.withoutHeading(), full: full);
    }
    final json = answer.json;
    if (json['code'] != 'Ok') {
      throw RoutingException(
        '${json['message'] ?? 'No route between these points'}',
        statusCode: answer.statusCode,
        code: json['code']?.toString(),
      );
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
  /// [queryParameters] go on every request URL, for hosted Valhalla that
  /// wants its key there (`api_key`). [fallbackUrls] are other servers to
  /// ask when [baseUrl] is down, slow, rate limited or failing.
  ValhallaRouter({
    super.baseUrl = 'https://valhalla1.openstreetmap.de',
    this.costing = 'auto',
    this.costingOptions,
    this.language = 'en-US',
    this.queryParameters = const {},
    super.fallbackUrls,
    super.retryMainAfter,
    super.headers,
    super.headersBuilder,
    super.client,
    super.timeout = const Duration(seconds: 12),
  });

  /// Extra query parameters for every request.
  final Map<String, String> queryParameters;

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

  Future<({Map<String, dynamic> json, int statusCode})> _post(
    Map<String, dynamic> body,
  ) {
    return _send(
      (c, h, base) => c.post(
        queryParameters.isEmpty
            ? Uri.parse('$base/route')
            : Uri.parse('$base/route')
                  .replace(queryParameters: queryParameters),
        headers: {'Content-Type': 'application/json', ...h},
        body: jsonEncode(body),
      ),
    );
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

  Future<Map<String, dynamic>> _ask(
    RouteRequest r, {
    required bool full,
  }) async {
    if (r.points.length < 2) {
      throw const RoutingException('A route needs at least two points');
    }
    var answer = await _post(_body(r, full: full));
    if (_error(answer.json) != null && r.headingDeg != null) {
      answer = await _post(_body(r.withoutHeading(), full: full));
    }
    final json = answer.json;
    final error = _error(json);
    if (error != null) {
      throw RoutingException(
        error,
        statusCode: answer.statusCode,
        code: (json['error_code'] ?? json['code'])?.toString(),
      );
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
