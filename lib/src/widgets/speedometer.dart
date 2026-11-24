import 'package:flutter/material.dart';

import '../controller.dart';
import '../settings.dart';
import 'style.dart';

/// The current speed in a round badge, in km/h or mph by
/// [NavigationSettings.units], in the navigation's language.
///
/// When the router sent speed limits (OSRM style `maxspeed`), the limit of
/// the road under the car shows next to it as a round sign, and the badge
/// turns [NavigationStyle.speedingColor] while over it. Without a limit
/// only the speed shows.
///
/// It rebuilds itself from [controller] and takes no space when not
/// navigating (or always shows with [onlyWhileNavigating] false, once
/// there is a fix).
class NavigationSpeedometer extends StatelessWidget {
  /// Creates the speedometer.
  const NavigationSpeedometer({
    super.key,
    required this.controller,
    this.style,
    this.size = 64,
    this.showSpeedLimit = true,
    this.onlyWhileNavigating = true,
  });

  /// The navigation to read the speed from.
  final NavigationController controller;

  /// Colors over the theme's.
  final NavigationStyle? style;

  /// Width and height of the badge (the sign is the same size).
  final double size;

  /// Show the speed limit sign when the limit is known.
  final bool showSpeedLimit;

  /// Hide it while not navigating.
  final bool onlyWhileNavigating;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if ((onlyWhileNavigating && !controller.isActive) ||
            controller.lastFix == null) {
          return const SizedBox.shrink();
        }
        final s = NavigationStyle.resolve(context, style);
        final units = controller.settings.units;
        final strings = controller.strings;
        final limit = showSpeedLimit ? controller.speedLimitKmh : null;
        final speeding = limit != null && controller.speeding;
        final value = strings.speedValue(controller.speedMps, units);
        final fill = speeding ? s.speedingColor : s.speedColor;
        final ink = speeding ? s.onSpeedingColor : s.onSpeedColor;
        final badge = Material(
          key: const ValueKey('nav-speed'),
          color: fill,
          shape: const CircleBorder(),
          elevation: 4,
          child: SizedBox.square(
            dimension: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  key: const ValueKey('nav-speed-value'),
                  style: TextStyle(
                    color: ink,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  strings.speedUnit(units),
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.75),
                    fontSize: size * 0.16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
        if (limit == null) return badge;
        // The limit in the units shown: mph limits come back whole.
        final shown = strings.speedValue(limit / 3.6, units);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            SizedBox(width: size * 0.15),
            _LimitSign(
              key: const ValueKey('nav-speed-limit'),
              value: units == DistanceUnits.imperial
                  ? (shown / 5).round() * 5
                  : shown,
              size: size,
              ring: s.speedLimitColor,
            ),
          ],
        );
      },
    );
  }
}

/// A round speed limit sign: a red ring on white with the number.
class _LimitSign extends StatelessWidget {
  const _LimitSign({
    super.key,
    required this.value,
    required this.size,
    required this.ring,
  });

  final int value;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(
        side: BorderSide(color: ring, width: size * 0.11),
      ),
      elevation: 4,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              color: Colors.black,
              fontSize: size * (value >= 100 ? 0.3 : 0.38),
              fontWeight: FontWeight.w800,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
