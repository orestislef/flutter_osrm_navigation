import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../controller.dart';
import 'style.dart';

/// The route on a flutter_map: what is left of it, wide with an edge, and
/// the part already driven when [NavigationStyle.traveledColor] is set.
/// While off the route the line fades.
///
/// Put it in `FlutterMap.children` above the tiles.
class NavigationRouteLayer extends StatelessWidget {
  /// Creates the layer.
  const NavigationRouteLayer({super.key, required this.controller, this.style});

  /// The navigation to draw.
  final NavigationController controller;

  /// Colors over the theme's.
  final NavigationStyle? style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isActive) return const SizedBox.shrink();
        final s = NavigationStyle.resolve(context, style);
        final ahead = controller.remainingLine;
        final behind = s.traveledColor == null
            ? const <LatLng>[]
            : controller.traveledLine;
        return PolylineLayer(
          polylines: [
            if (behind.length >= 2)
              Polyline(
                points: behind,
                color: s.traveledColor!,
                strokeWidth: s.routeWidth * 0.75,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            if (ahead.length >= 2)
              Polyline(
                points: ahead,
                color: controller.offRoute ? s.offRouteLineColor : s.routeColor,
                strokeWidth: s.routeWidth,
                borderColor: s.routeBorderColor,
                borderStrokeWidth: s.routeBorderWidth,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
          ],
        );
      },
    );
  }
}

/// The stops still ahead (numbered) and the destination, as markers.
class NavigationStopsLayer extends StatelessWidget {
  /// Creates the layer.
  const NavigationStopsLayer({
    super.key,
    required this.controller,
    this.style,
    this.size = 30,
  });

  /// The navigation to draw.
  final NavigationController controller;

  /// Colors over the theme's.
  final NavigationStyle? style;

  /// Marker size.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final destination = controller.destination;
        if (!controller.isActive || destination == null) {
          return const SizedBox.shrink();
        }
        final s = NavigationStyle.resolve(context, style);
        final stops = controller.remainingWaypoints;
        final first = controller.route == null
            ? 0
            : controller.route!.waypoints.length - stops.length;
        return MarkerLayer(
          markers: [
            for (var i = 0; i < stops.length; i++)
              Marker(
                point: stops[i],
                width: size,
                height: size,
                child: _Dot(
                  color: s.stopColor,
                  border: s.puckBorderColor,
                  child: Text(
                    '${first + i + 1}',
                    style: TextStyle(
                      color: s.onMarkerColor,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.45,
                    ),
                  ),
                ),
              ),
            Marker(
              point: destination,
              width: size,
              height: size,
              child: _Dot(
                color: s.destinationColor,
                border: s.puckBorderColor,
                child:
                    Icon(Icons.flag, color: s.onMarkerColor, size: size * 0.55),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.border, required this.child});

  final Color color;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Center(child: child),
    );
  }
}

/// The position marker: an arrow pointing the way of travel, or a dot when
/// the heading is not known, with the GPS accuracy circle when the position
/// is not drawn on the route.
///
/// [NavigationMap] uses it with a smooth glide between fixes. In your own
/// map, feed it from the controller:
///
/// ```dart
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => NavigationPositionLayer(
///     position: controller.displayPosition,
///     heading: controller.displayHeading,
///   ),
/// )
/// ```
class NavigationPositionLayer extends StatelessWidget {
  /// Creates the layer.
  const NavigationPositionLayer({
    super.key,
    required this.position,
    this.heading,
    this.accuracyM,
    this.style,
    this.marker,
  });

  /// Where to draw it. Nothing is drawn when null.
  final LatLng? position;

  /// Degrees from north. A dot when null.
  final double? heading;

  /// Radius of the accuracy circle in metres. None when null.
  final double? accuracyM;

  /// Colors over the theme's.
  final NavigationStyle? style;

  /// Your own marker instead of the arrow. It is turned to [heading], so
  /// draw it pointing up.
  final Widget? marker;

  @override
  Widget build(BuildContext context) {
    final p = position;
    if (p == null) return const SizedBox.shrink();
    final s = NavigationStyle.resolve(context, style);
    final h = heading;
    final acc = accuracyM;
    final child = marker ??
        CustomPaint(
          size: Size.square(s.puckSize),
          painter: PuckPainter(
            color: s.puckColor,
            border: s.puckBorderColor,
            arrow: s.puckArrowColor,
            showArrow: h != null,
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (acc != null && acc > 5)
          CircleLayer(circles: [
            CircleMarker(
              point: p,
              radius: acc,
              useRadiusInMeter: true,
              color: s.accuracyColor,
              borderStrokeWidth: 0,
            ),
          ]),
        MarkerLayer(
          markers: [
            Marker(
              point: p,
              width: s.puckSize,
              height: s.puckSize,
              child: h == null
                  ? child
                  : Transform.rotate(angle: h * math.pi / 180, child: child),
            ),
          ],
        ),
      ],
    );
  }
}

/// Paints the default position marker, pointing up.
class PuckPainter extends CustomPainter {
  /// Creates the painter.
  const PuckPainter({
    required this.color,
    required this.border,
    required this.arrow,
    this.showArrow = true,
  });

  /// Fill.
  final Color color;

  /// Ring.
  final Color border;

  /// The arrow.
  final Color arrow;

  /// An arrow, or a plain dot.
  final bool showArrow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
        c.translate(0, 1.5),
        r - 1,
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(c, r - 1, Paint()..color = border);
    canvas.drawCircle(c, r - 1 - r * 0.14, Paint()..color = color);
    if (!showArrow) return;
    final a = r * 0.52;
    final path = Path()
      ..moveTo(c.dx, c.dy - a)
      ..lineTo(c.dx + a * 0.78, c.dy + a * 0.8)
      ..lineTo(c.dx, c.dy + a * 0.38)
      ..lineTo(c.dx - a * 0.78, c.dy + a * 0.8)
      ..close();
    canvas.drawPath(path, Paint()..color = arrow);
  }

  @override
  bool shouldRepaint(PuckPainter old) =>
      old.color != color ||
      old.border != border ||
      old.arrow != arrow ||
      old.showArrow != showArrow;
}
