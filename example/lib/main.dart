import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:latlong2/latlong.dart';

// OSRM's public demo server is fine to try things with. For a real app run
// your own OSRM or Valhalla and point the router at it:
//
//   OsrmRouter(baseUrl: 'https://osrm.example.com')
//   ValhallaRouter(baseUrl: 'https://valhalla.example.com', costing: 'auto')
const _osrmDemo = 'https://router.project-osrm.org';

void main() => runApp(const ExampleApp());

/// Three looks to show that every color can be changed.
enum Look { theme, night, custom }

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Look _look = Look.theme;

  ThemeData _theme() {
    switch (_look) {
      case Look.theme:
        return ThemeData(colorSchemeSeed: Colors.indigo);
      case Look.night:
        return ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        );
      case Look.custom:
        return ThemeData(
          colorSchemeSeed: Colors.teal,
          extensions: const [
            NavigationStyle(
              bannerColor: Color(0xFF1B1B1F),
              onBannerColor: Colors.white,
              thenColor: Color(0xFF2E2E33),
              onThenColor: Color(0xFFFFC107),
              footerAccentColor: Color(0xFF00897B),
              routeColor: Color(0xFF00897B),
              routeBorderColor: Color(0xFF004D40),
              routeWidth: 10,
              traveledColor: Color(0x8890A4AE),
              puckColor: Color(0xFFFFC107),
              puckArrowColor: Color(0xFF1B1B1F),
              destinationColor: Color(0xFF1B1B1F),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSRM Navigation',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: NavigationPage(
        look: _look,
        onLook: (look) => setState(() => _look = look),
      ),
    );
  }
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key, required this.look, required this.onLook});

  final Look look;
  final ValueChanged<Look> onLook;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final _nav = NavigationController(router: OsrmRouter(baseUrl: _osrmDemo));
  late final _sim = RouteSimulator(_nav, speedKmh: 50);
  StreamSubscription<NavigationEvent>? _events;

  LocationAccess? _access;
  LatLng? _from;
  LatLng? _to;
  final List<LatLng> _stops = [];
  bool _busy = false;
  bool _simulating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nav.initVoice();
    _events = _nav.events.listen(_onEvent);
    _startGps();
  }

  @override
  void dispose() {
    _events?.cancel();
    _sim.stop();
    _nav.dispose();
    super.dispose();
  }

  Future<void> _startGps() async {
    LocationAccess access;
    try {
      access = await NavigationLocation.ensurePermission();
    } catch (_) {
      access = LocationAccess.denied;
    }
    if (!mounted) return;
    setState(() => _access = access);
    if (access == LocationAccess.granted) _nav.attachLocation(_gps());
  }

  Stream<NavFix> _gps() => NavigationLocation.stream(
        notificationTitle: 'OSRM Navigation',
        notificationText: 'Guiding you to your destination',
      );

  void _onEvent(NavigationEvent event) {
    if (!mounted) return;
    final text = switch (event) {
      WaypointReached(:final index) => 'Stop ${index + 1} reached',
      DestinationReached() => 'You made it',
      RerouteFailed() => 'No new route yet, trying again soon',
      _ => null,
    };
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  bool get _hasGps =>
      _access == LocationAccess.granted && _nav.lastFix != null && !_simulating;

  /// A long press sets the start (when there is no GPS), then the
  /// destination, then adds stops.
  void _onLongPress(TapPosition _, LatLng point) {
    if (_nav.isActive) return;
    setState(() {
      _error = null;
      if (!_hasGps && _from == null) {
        _from = point;
      } else if (_to == null) {
        _to = point;
      } else {
        _stops.add(_to!);
        _to = point;
      }
    });
  }

  Future<void> _go({required bool simulate}) async {
    final to = _to;
    final from = simulate ? (_from ?? _nav.lastFix?.position) : null;
    if (to == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (simulate) {
        _simulating = true;
        // The simulator feeds the position now. The location stream stays
        // listened to with its fixes dropped: on Android that keeps the
        // foreground service, so a simulated drive also goes on talking
        // with the phone locked, just like a real one.
        if (_access == LocationAccess.granted) {
          _nav.attachLocation(_gps().where((_) => false));
        } else {
          _nav.detachLocation();
        }
      }
      await _nav.navigateTo(
        to,
        from: from,
        via: List.of(_stops),
        destinationName: 'the pin',
      );
      if (simulate) _sim.start();
    } catch (e) {
      _error = e is RoutingException ? e.message : '$e';
      if (simulate) {
        _simulating = false;
        _startGps();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _stop() {
    _sim.stop();
    _nav.stop();
    if (_simulating) {
      _simulating = false;
      _startGps();
    }
    setState(() {});
  }

  void _clear() => setState(() {
        _from = null;
        _to = null;
        _stops.clear();
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pins = <Marker>[
      if (!_nav.isActive && _from != null) _pin(_from!, Icons.trip_origin),
      if (!_nav.isActive)
        for (final s in _stops) _pin(s, Icons.circle),
      if (!_nav.isActive && _to != null) _pin(_to!, Icons.flag),
    ];
    return Scaffold(
      body: ListenableBuilder(
        listenable: _nav,
        builder: (context, _) => NavigationMap(
          controller: _nav,
          // Somewhere to open before the first fix.
          initialCenter: const LatLng(40.6301, 22.9444),
          initialZoom: 14,
          onLongPress: _onLongPress,
          layers: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'gr.orestislef.flutter_osrm_navigation',
              tileBuilder: dark ? darkModeTileBuilder : null,
            ),
          ],
          topLayers: [MarkerLayer(markers: pins)],
          bannerActions: [
            IconButton(
              tooltip: 'Stop',
              icon: const Icon(Icons.close),
              onPressed: _stop,
            ),
          ],
          overlays: [
            if (_nav.isActive && _simulating)
              Positioned(
                left: 12,
                bottom: 0,
                child: SafeArea(child: _detours()),
              ),
            if (!_nav.isActive)
              Positioned(
                left: 12,
                right: 12,
                bottom: 0,
                child: SafeArea(child: _panel(context)),
              ),
          ],
        ),
      ),
    );
  }

  /// Leave the route on purpose while simulating, to see it reroute.
  Widget _detours() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _sim.missTurn,
            icon: const Icon(Icons.call_missed_outgoing),
            label: const Text('Miss the turn'),
          ),
          FilledButton.tonalIcon(
            onPressed: _sim.turnAround,
            icon: const Icon(Icons.u_turn_left),
            label: const Text('Turn around'),
          ),
        ],
      ),
    );
  }

  Marker _pin(LatLng p, IconData icon) => Marker(
        point: p,
        width: 32,
        height: 32,
        child: Icon(icon, color: Colors.redAccent, size: 28),
      );

  Widget _panel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hint = switch ((_hasGps, _from, _to)) {
      (false, null, _) => 'Long press the map to set where you start.',
      (_, _, null) => 'Long press the map to set where you are going.',
      _ => 'Long press again to add a stop on the way.',
    };
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(hint, style: text.titleSmall),
            if (_access != null && _access != LocationAccess.granted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No GPS (${_access!.name}). You can still simulate a drive.',
                  style: text.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: text.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _busy || _to == null || !_hasGps
                      ? null
                      : () => _go(simulate: false),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ||
                          _to == null ||
                          (_from == null && _nav.lastFix == null)
                      ? null
                      : () => _go(simulate: true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Simulate'),
                ),
                TextButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('EN')),
                    ButtonSegment(value: 'el', label: Text('EL')),
                  ],
                  selected: {
                    _nav.strings is GreekNavigationStrings ? 'el' : 'en'
                  },
                  onSelectionChanged: (v) => setState(() =>
                      _nav.strings = NavigationStrings.forLanguage(v.first)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<Look>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: Look.theme, label: Text('Theme')),
                      ButtonSegment(value: Look.night, label: Text('Night')),
                      ButtonSegment(value: Look.custom, label: Text('Custom')),
                    ],
                    selected: {widget.look},
                    onSelectionChanged: (v) => widget.onLook(v.first),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
