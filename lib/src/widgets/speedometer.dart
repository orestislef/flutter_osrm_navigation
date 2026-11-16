import 'package:flutter/material.dart';

import '../controller.dart';
import 'style.dart';

/// The current speed in a round badge, in km/h or mph by
/// [NavigationSettings.units], in the navigation's language.
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
    this.onlyWhileNavigating = true,
  });

  /// The navigation to read the speed from.
  final NavigationController controller;

  /// Colors over the theme's ([NavigationStyle.speedColor] and
  /// [NavigationStyle.onSpeedColor]).
  final NavigationStyle? style;

  /// Width and height.
  final double size;

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
        final value = strings.speedValue(controller.speedMps, units);
        return Material(
          key: const ValueKey('nav-speed'),
          color: s.speedColor,
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
                    color: s.onSpeedColor,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  strings.speedUnit(units),
                  style: TextStyle(
                    color: s.onSpeedColor.withValues(alpha: 0.75),
                    fontSize: size * 0.16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
