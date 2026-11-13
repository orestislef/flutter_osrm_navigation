import 'package:flutter/material.dart';

import '../route.dart';

/// The Material icon for [step].
///
/// U-turns and roundabouts follow the side of the road traffic keeps to
/// ([NavStep.drivingSide]): with traffic on the right a U-turn goes round to
/// the left. [stop] picks the stop icon for an arrival that is not the end.
IconData maneuverIcon(NavStep step, {bool stop = false}) {
  final leftHand = step.drivingSide == 'left';
  final mod = step.modifier ?? '';
  switch (step.maneuverType) {
    case 'depart':
      return Icons.navigation;
    case 'arrive':
      return stop ? Icons.place : Icons.flag;
    case 'roundabout':
    case 'rotary':
    case 'roundabout turn':
    case 'exit roundabout':
    case 'exit rotary':
      return leftHand ? Icons.roundabout_left : Icons.roundabout_right;
    case 'merge':
      return Icons.merge;
    case 'fork':
      if (mod.contains('left')) return Icons.fork_left;
      if (mod.contains('right')) return Icons.fork_right;
      return Icons.straight;
    case 'on ramp':
    case 'off ramp':
      if (mod.contains('left')) return Icons.ramp_left;
      if (mod.contains('right')) return Icons.ramp_right;
      return Icons.straight;
  }
  return switch (mod) {
    'uturn' => leftHand ? Icons.u_turn_right : Icons.u_turn_left,
    'sharp right' => Icons.turn_sharp_right,
    'right' => Icons.turn_right,
    'slight right' => Icons.turn_slight_right,
    'slight left' => Icons.turn_slight_left,
    'left' => Icons.turn_left,
    'sharp left' => Icons.turn_sharp_left,
    _ => Icons.straight,
  };
}
