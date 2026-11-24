import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../controller.dart';
import '../geometry.dart';
import 'banner.dart';
import 'layers.dart';
import 'gps_ticker.dart';
import 'speedometer.dart';
import 'style.dart';

/// A flutter_map with navigation built in: the route, the stops, the
/// position gliding smoothly between fixes, the banner, and a camera that
/// follows.
///
/// While navigating the camera turns with the road ([headingUp]), zooms out
/// as the car goes faster ([autoZoom]), and keeps the car low on the screen
/// ([positionAt]) so more of the road ahead shows. Touch the map and it
/// stops following; it comes back after [recenterAfter] or with the
/// re-center button.
///
/// Bring your own tiles in [layers]:
///
/// ```dart
/// NavigationMap(
///   controller: controller,
///   layers: [
///     TileLayer(
///       urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
///       userAgentPackageName: 'com.example.app',
///     ),
///   ],
/// )
/// ```
class NavigationMap extends StatefulWidget {
  /// Creates the map.
  const NavigationMap({
    super.key,
    required this.controller,
    this.layers = const [],
    this.topLayers = const [],
    this.overlays = const [],
    this.mapController,
    this.style,
    this.initialCenter,
    this.initialZoom = 16,
    this.minZoom = 3,
    this.crs,
    this.cameraConstraint,
    this.maxZoom = 19,
    this.headingUp = true,
    this.autoZoom = true,
    this.slowZoom = 17.5,
    this.fastZoom = 15.5,
    this.slowKmh = 20,
    this.fastKmh = 90,
    this.positionAt = 0.7,
    this.recenterAfter = const Duration(seconds: 10),
    this.glide = const Duration(milliseconds: 900),
    this.showBanner = true,
    this.bannerActions = const [],
    this.showRecenterButton = true,
    this.recenterAlignment = AlignmentDirectional.bottomEnd,
    this.recenterPadding = const EdgeInsets.all(16),
    this.bannerPadding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
    this.bannerMaxWidth = 560,
    this.overlayInsets = EdgeInsets.zero,
    this.showStops = true,
    this.showAccuracy = true,
    this.showSpeed = true,
    this.speedOnlyWhileNavigating = false,
    this.idleHeadingUp = true,
    this.idleFollowLikeNavigation = true,
    this.recenterWhenIdle = true,
    this.showSpeedLimit = true,
    this.stopBuilder,
    this.destinationBuilder,
    this.stopSize = 30,
    this.onFollowingChanged,
    this.speedAlignment = AlignmentDirectional.bottomStart,
    this.speedPadding = const EdgeInsets.all(16),
    this.positionMarker,
    this.onTap,
    this.onLongPress,
  });

  /// The navigation to show.
  final NavigationController controller;

  /// Layers under the route: your tile layer, polygons, anything.
  final List<Widget> layers;

  /// Layers above the position marker.
  final List<Widget> topLayers;

  /// Widgets over the map, in a [Stack] above the banner (a bottom panel,
  /// your own buttons). Use [Positioned] or [Align] in them.
  final List<Widget> overlays;

  /// Your own map controller, to move the map yourself. One is made when
  /// null.
  final MapController? mapController;

  /// Colors over the theme's.
  final NavigationStyle? style;

  /// Where the map opens. The last fix, or 0, 0 when null.
  final LatLng? initialCenter;

  /// The zoom the map opens at.
  final double initialZoom;

  /// The map projection. Web Mercator (`Epsg3857`) when null, as in
  /// flutter_map. Pass one that does not repeat the world if your app
  /// needs that.
  final Crs? crs;

  /// Limits on where the camera can go. None when null.
  final CameraConstraint? cameraConstraint;

  /// The least zoom.
  final double minZoom;

  /// The most zoom.
  final double maxZoom;

  /// Turn the map with the direction of travel while navigating.
  final bool headingUp;

  /// Zoom by speed while navigating, from [slowZoom] at [slowKmh] to
  /// [fastZoom] at [fastKmh].
  final bool autoZoom;

  /// Zoom at [slowKmh] and below.
  final double slowZoom;

  /// Zoom at [fastKmh] and above.
  final double fastZoom;

  /// See [autoZoom].
  final double slowKmh;

  /// See [autoZoom].
  final double fastKmh;

  /// Where the car sits while navigating, as a fraction of the height from
  /// the top. 0.5 is the middle.
  final double positionAt;

  /// After the user moves the map, follow again after this long while
  /// navigating. [Duration.zero] waits for the button.
  final Duration recenterAfter;

  /// How long the position takes to glide to a new fix. About the time
  /// between fixes looks smooth. [Duration.zero] jumps.
  final Duration glide;

  /// Show the [NavigationBanner] at the top.
  final bool showBanner;

  /// Extra buttons at the end of the banner's footer.
  final List<Widget> bannerActions;

  /// Show the re-center button when not following.
  final bool showRecenterButton;

  /// Where the re-center button sits over the map.
  final AlignmentGeometry recenterAlignment;

  /// Space around the re-center button, inside the safe area.
  final EdgeInsetsGeometry recenterPadding;

  /// Space around the banner, inside the safe area.
  final EdgeInsetsGeometry bannerPadding;

  /// The widest the banner gets (tablets, landscape).
  final double bannerMaxWidth;

  /// Pushes the banner, the speed and the re-center button in from the
  /// edges together, for a panel or buttons of your own over the map
  /// (the height of a bottom sheet, say). On top of each one's padding.
  final EdgeInsetsGeometry overlayInsets;

  /// Draw the stops and the destination.
  final bool showStops;

  /// Draw the GPS accuracy circle around the position. On by default. It
  /// is left out while the position is drawn on the route line, where a
  /// circle around the snapped point would mislead.
  final bool showAccuracy;

  /// Show the current speed, in km/h or mph by
  /// [NavigationSettings.units]. On by default.
  final bool showSpeed;

  /// Show the speed only while navigating. Off by default: the speed shows
  /// whenever there is a fix. The speed limit needs a route either way.
  final bool speedOnlyWhileNavigating;

  /// When not navigating, turn the map with the direction of travel while
  /// following, once the car moves faster than
  /// [NavigationSettings.headingKmh]. Slower than that the map keeps its
  /// rotation, so it does not spin at a red light. False keeps north up.
  final bool idleHeadingUp;

  /// When not navigating, follow the way navigation does: zoom with the
  /// speed ([autoZoom]) and keep the car at [positionAt]. False keeps the
  /// zoom the user picked and the car in the middle.
  final bool idleFollowLikeNavigation;

  /// When not navigating, follow again [recenterAfter] after the user
  /// moved the map, as while navigating.
  final bool recenterWhenIdle;

  /// Show the speed limit sign next to the speed when the router sent
  /// limits. Without them only the speed shows.
  final bool showSpeedLimit;

  /// Your own widget for each stop on the way. [index] is 0 for the
  /// first stop of the trip. A numbered dot when null. It stays upright
  /// when the map turns, no need to turn it back yourself.
  final Widget Function(BuildContext context, int index, LatLng point)?
  stopBuilder;

  /// Your own widget for the destination. A flag in a dot when null. It
  /// stays upright when the map turns.
  final Widget Function(BuildContext context, LatLng point)? destinationBuilder;

  /// Width and height of the stop and destination markers.
  final double stopSize;

  /// Called when the camera stops following the position (the user
  /// moved the map) and when it follows again (the re-center button,
  /// the wait after a pan, a new navigation, [NavigationMapState.recenter]).
  final ValueChanged<bool>? onFollowingChanged;

  /// Where the speed sits over the map.
  final AlignmentGeometry speedAlignment;

  /// Space around the speed, inside the safe area.
  final EdgeInsetsGeometry speedPadding;

  /// Your own position marker, drawn pointing up. See
  /// [NavigationPositionLayer.marker].
  final Widget? positionMarker;

  /// A tap on the map.
  final void Function(TapPosition tapPosition, LatLng point)? onTap;

  /// A long press on the map.
  final void Function(TapPosition tapPosition, LatLng point)? onLongPress;

  @override
  State<NavigationMap> createState() => NavigationMapState();
}

/// The state of a [NavigationMap]. Reach it with a
/// `GlobalKey<NavigationMapState>` to follow the position again from your
/// own button.
class NavigationMapState extends State<NavigationMap>
    with TickerProviderStateMixin {
  static const _gestures = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.multiFingerGestureStart,
    MapEventSource.onMultiFinger,
    MapEventSource.doubleTap,
    MapEventSource.doubleTapHold,
    MapEventSource.scrollWheel,
    MapEventSource.cursorKeyboardRotation,
    MapEventSource.keyboard,
  };

  MapController? _own;
  MapController get _map => widget.mapController ?? (_own ??= MapController());

  late final AnimationController _glide;
  late final AnimationController _fly;
  LatLng? _flyFrom;
  LatLng? _flyTo;
  double _flyFromZoom = 0;
  double _flyToZoom = 0;

  // Where the camera was when following started again, so it eases over
  // instead of jumping (the first fix, the map opening, re-center).
  LatLng? _blendFrom;
  bool _ready = false;
  bool _following = true;

  /// Whether the camera follows the position.
  bool get following => _following;

  /// Follows the position again, as the re-center button does.
  void recenter() => _recenter();

  /// Stops following and moves the camera to [point], at [zoom] or the
  /// zoom the map has. The re-center button shows, and following comes
  /// back by itself after [NavigationMap.recenterAfter], as after a pan.
  void showPoint(LatLng point, {double? zoom}) {
    _setFollowing(false);
    _armRecenter();
    if (!_ready) return;
    _glide.stop();
    final camera = _map.camera;
    _flyFrom = camera.center;
    _flyTo = point;
    _flyFromZoom = camera.zoom;
    _flyToZoom = zoom ?? camera.zoom;
    if (_noAnimations) {
      _fly.value = 1;
      _onFly();
    } else {
      _fly.forward(from: 0);
    }
  }

  void _onFly() {
    final from = _flyFrom;
    final to = _flyTo;
    if (from == null || to == null || !_ready || !mounted || _following) {
      return;
    }
    final t = Curves.easeInOut.transform(_fly.value);
    _map.move(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      _flyFromZoom + (_flyToZoom - _flyFromZoom) * t,
    );
  }

  /// Starts the wait after which following comes back on its own.
  void _armRecenter() {
    _recenterTimer?.cancel();
    if (widget.recenterAfter <= Duration.zero) return;
    if (!_nav.isActive && !widget.recenterWhenIdle) return;
    _recenterTimer = Timer(widget.recenterAfter, () {
      if (mounted &&
          !_following &&
          (_nav.isActive || widget.recenterWhenIdle)) {
        _recenter();
      }
    });
  }

  void _setFollowing(bool value) {
    if (value == _following) return;
    if (mounted) {
      setState(() => _following = value);
    } else {
      _following = value;
    }
    widget.onFollowingChanged?.call(value);
  }

  bool _wasActive = false;
  bool _noAnimations = false;
  Timer? _recenterTimer;

  LatLng? _pos;
  double? _heading;
  LatLng? _fromPos;
  LatLng? _toPos;
  double? _fromHeading;
  double? _toHeading;
  double _fromZoom = 0;
  double _toZoom = 0;
  double _fromRot = 0;
  double _toRot = 0;

  // While on the route the marker glides along the road (round corners
  // rather than across them) and the line is cut right at it.
  RouteLine? _line;
  double? _fromAlong;
  double? _toAlong;
  double? _along;

  @override
  void initState() {
    super.initState();
    _glide = AnimationController(vsync: this, duration: widget.glide)
      ..addListener(_onTick);
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_onFly);
    _wasActive = widget.controller.isActive;
    _pos = widget.controller.displayPosition;
    _heading = widget.controller.displayHeading;
    widget.controller.addListener(_onNav);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(NavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onNav);
      widget.controller.addListener(_onNav);
    }
    if (oldWidget.glide != widget.glide) _glide.duration = widget.glide;
    // Where the car sits changed (a panel was dragged, say): place the
    // camera again now, not at the next fix, which may not come soon.
    if (_following &&
        (oldWidget.positionAt != widget.positionAt ||
            oldWidget.overlayInsets != widget.overlayInsets)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _following) _recenter();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onNav);
    _recenterTimer?.cancel();
    _glide.dispose();
    _fly.dispose();
    _own?.dispose();
    super.dispose();
  }

  NavigationController get _nav => widget.controller;

  /// Following follows the way navigation does: while navigating, or
  /// idle with [NavigationMap.idleFollowLikeNavigation].
  bool get _likeNavigation => _nav.isActive || widget.idleFollowLikeNavigation;

  double _targetZoom() {
    final current = _ready ? _map.camera.zoom : widget.initialZoom;
    if (!_likeNavigation || !widget.autoZoom) return current;
    final kmh = _nav.speedMps * 3.6;
    final span = widget.fastKmh - widget.slowKmh;
    final t = span <= 0 ? 0.0 : ((kmh - widget.slowKmh) / span).clamp(0.0, 1.0);
    return widget.slowZoom + (widget.fastZoom - widget.slowZoom) * t;
  }

  double _targetRotation(double? heading) {
    final current = _ready ? _map.camera.rotation : 0.0;
    if (!_following) return current;
    if (_nav.isActive) {
      if (!widget.headingUp) return 0;
      return heading == null ? current : -heading;
    }
    if (!widget.idleHeadingUp) return 0;
    // Not navigating there is no road to turn with: only a heading the car
    // is moving fast enough to trust, else the map keeps its rotation.
    if (heading == null || _nav.speedMps < _nav.settings.headingMps) {
      return current;
    }
    return -heading;
  }

  void _onNav() {
    final active = _nav.isActive;
    final started = active && !_wasActive;
    if (started) _setFollowing(true);
    final ended = !active && _wasActive;
    _wasActive = active;
    final target = _nav.displayPosition;
    final heading = _nav.displayHeading;
    if (target == null) return;
    final moved =
        target != _toPos ||
        heading != _toHeading ||
        !identical(_nav.routeLine, _line);
    if (!moved && !ended && !started) return;
    _startGlide(target, heading, ease: started);
  }

  /// Sets up the glide along the route line, or a cut at the controller's
  /// progress when the marker cannot follow the line (a new route, off the
  /// route, a jump).
  void _setAlong({required bool glide}) {
    final line = _nav.routeLine;
    final snapped = _nav.snappedPosition != null;
    final to = _nav.progressMeters;
    final from = _along;
    final sameLine = line != null && identical(line, _line);
    if (glide &&
        snapped &&
        sameLine &&
        from != null &&
        to - from >= -5 &&
        to - from <= 500) {
      _fromAlong = from;
    } else {
      _fromAlong = null;
    }
    _toAlong = snapped ? to : null;
    _line = line;
    if (_fromAlong == null) _along = _toAlong;
  }

  /// Glides the position (and the camera, while following) to [target].
  /// With [ease], or for the very first fix, the camera eases over from
  /// where it is instead of jumping.
  void _startGlide(LatLng target, double? heading, {bool ease = false}) {
    final first = _pos == null;
    final canAnimate = !_noAnimations && widget.glide > Duration.zero;
    if ((first || ease) && canAnimate && _ready && _following) {
      _blendFrom = _map.camera.center;
    }
    final jump =
        first ||
        _noAnimations ||
        widget.glide == Duration.zero ||
        metresBetween(_pos!, target) > 1000;
    _fromPos = jump ? target : _pos;
    _toPos = target;
    _fromHeading = heading == null || _heading == null ? heading : _heading;
    _toHeading = heading;
    _setAlong(glide: !jump);
    if (_ready) {
      _fromZoom = _map.camera.zoom;
      _fromRot = _map.camera.rotation;
    }
    _toZoom = _targetZoom();
    _toRot = _targetRotation(heading);
    if (jump && _blendFrom == null) {
      _glide.value = 1;
      _onTick();
    } else {
      _glide.forward(from: 0);
    }
  }

  static double _lerpAngle(double a, double b, double t) {
    final d = ((b - a) % 360 + 540) % 360 - 180;
    return a + d * t;
  }

  void _onTick() {
    final from = _fromPos;
    final to = _toPos;
    if (from == null || to == null || !mounted) return;
    final t = _glide.value;
    final line = _line;
    final fromAlong = _fromAlong;
    final toAlong = _toAlong;
    final LatLng pos;
    double? along = _along;
    if (line != null && fromAlong != null && toAlong != null) {
      along = fromAlong + (toAlong - fromAlong) * t;
      pos = t >= 1 ? to : line.pointAt(along);
    } else {
      pos = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    }
    final fh = _fromHeading;
    final th = _toHeading;
    final heading = th == null
        ? null
        : (fh == null ? th : (_lerpAngle(fh, th, t) + 360) % 360);
    setState(() {
      _pos = pos;
      _heading = heading;
      _along = along;
    });
    if (_following && _ready) {
      final zoom = _fromZoom + (_toZoom - _fromZoom) * t;
      final rotation = _lerpAngle(_fromRot, _toRot, t);
      var center = _centerFor(pos, zoom, rotation);
      final blend = _blendFrom;
      if (blend != null) {
        final e = Curves.easeInOut.transform(t);
        center = LatLng(
          blend.latitude + (center.latitude - blend.latitude) * e,
          blend.longitude + (center.longitude - blend.longitude) * e,
        );
        if (t >= 1) _blendFrom = null;
      }
      _map.moveAndRotate(center, zoom, rotation);
    }
  }

  /// The camera center that puts [p] at [NavigationMap.positionAt] for the
  /// given zoom and rotation.
  LatLng _centerFor(LatLng p, double zoom, double rotation) {
    if (!_likeNavigation || widget.positionAt == 0.5) return p;
    final camera = _map.camera;
    final size = camera.nonRotatedSize;
    if (size.width <= 0 || size.height <= 0) return p;
    final placed = camera
        .withRotation(rotation)
        .withPosition(center: p, zoom: zoom);
    final middle = size.center(Offset.zero);
    final focus = Offset(size.width / 2, size.height * widget.positionAt);
    return placed.screenOffsetToLatLng(middle + (middle - focus));
  }

  void _onMapEvent(MapEvent event) {
    if (!_gestures.contains(event.source)) return;
    _fly.stop();
    _setFollowing(false);
    _armRecenter();
  }

  void _recenter() {
    _recenterTimer?.cancel();
    _fly.stop();
    final here = _nav.displayPosition;
    _setFollowing(true);
    if (here == null || !_ready) return;
    _fromPos = _pos ?? here;
    _toPos = here;
    _fromHeading = _heading;
    _toHeading = _nav.displayHeading;
    _setAlong(glide: false);
    _fromZoom = _map.camera.zoom;
    _fromRot = _map.camera.rotation;
    _toZoom = _targetZoom();
    _toRot = _targetRotation(_toHeading);
    _blendFrom = _noAnimations ? null : _map.camera.center;
    if (_noAnimations) {
      _glide.value = 1;
      _onTick();
    } else {
      _glide.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NavigationStyle.resolve(context, widget.style);
    final fix = _nav.lastFix;
    final accuracy = widget.showAccuracy && _nav.snappedPosition == null
        ? fix?.accuracyM
        : null;
    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter:
            widget.initialCenter ?? _nav.displayPosition ?? const LatLng(0, 0),
        initialZoom: widget.initialZoom,
        minZoom: widget.minZoom,
        crs: widget.crs ?? const Epsg3857(),
        cameraConstraint:
            widget.cameraConstraint ?? const CameraConstraint.unconstrained(),
        maxZoom: widget.maxZoom,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onMapEvent: _onMapEvent,
        onMapReady: () {
          _ready = true;
          final here = _nav.displayPosition;
          if (here != null) {
            _startGlide(here, _nav.displayHeading, ease: true);
          }
        },
      ),
      children: [
        ...widget.layers,
        NavigationRouteLayer(
          controller: _nav,
          style: widget.style,
          progressMeters: _along,
        ),
        if (widget.showStops)
          NavigationStopsLayer(
            controller: _nav,
            style: widget.style,
            size: widget.stopSize,
            stopBuilder: widget.stopBuilder,
            destinationBuilder: widget.destinationBuilder,
          ),
        NavigationPositionLayer(
          position: _pos,
          heading: _heading,
          accuracyM: accuracy,
          style: widget.style,
          marker: widget.positionMarker,
        ),
        ...widget.topLayers,
      ],
    );

    // The banner, the speed and the re-center button, all inside the safe
    // area and overlayInsets, each with its own padding on top.
    Widget place(
      EdgeInsetsGeometry padding,
      AlignmentGeometry alignment,
      Widget child,
    ) => Positioned.fill(
      child: Padding(
        padding: widget.overlayInsets,
        child: SafeArea(
          child: Padding(
            padding: padding,
            child: Align(alignment: alignment, child: child),
          ),
        ),
      ),
    );

    // SizedBox.expand: with loose constraints and an overlay that takes no
    // room, a Stack sizes itself to that overlay and the map vanished.
    return SizedBox.expand(
      child: Stack(
        children: [
          // The banner checks the GPS too; this one covers showBanner false.
          Positioned.fill(
            child: GpsTicker(controller: _nav, child: map),
          ),
          if (widget.showBanner)
            place(
              widget.bannerPadding,
              Alignment.topCenter,
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.bannerMaxWidth),
                child: NavigationBanner(
                  controller: _nav,
                  style: widget.style,
                  footerActions: widget.bannerActions,
                ),
              ),
            ),
          if (widget.showSpeed)
            place(
              widget.speedPadding,
              widget.speedAlignment,
              NavigationSpeedometer(
                controller: _nav,
                style: widget.style,
                showSpeedLimit: widget.showSpeedLimit,
                onlyWhileNavigating: widget.speedOnlyWhileNavigating,
              ),
            ),
          if (widget.showRecenterButton &&
              !_following &&
              _nav.displayPosition != null)
            place(
              widget.recenterPadding,
              widget.recenterAlignment,
              FloatingActionButton.extended(
                key: const ValueKey('nav-recenter'),
                heroTag: null,
                backgroundColor: s.buttonColor,
                foregroundColor: s.onButtonColor,
                onPressed: _recenter,
                icon: const Icon(Icons.navigation),
                label: Text(_nav.strings.recenter),
              ),
            ),
          ...widget.overlays,
        ],
      ),
    );
  }
}
