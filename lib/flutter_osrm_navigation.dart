/// Turn-by-turn navigation for flutter_map on OSRM and Valhalla routers.
///
/// Start with [NavigationController] for the navigation itself,
/// [NavigationMap] for a ready map with the banner, and [NavigationStyle]
/// for the colors.
library;

export 'src/controller.dart';
export 'src/events.dart';
export 'src/geometry.dart';
export 'src/location.dart';
export 'src/off_route.dart' show NavFix;
export 'src/polyline.dart';
export 'src/route.dart';
export 'src/router.dart';
export 'src/settings.dart';
export 'src/simulator.dart';
export 'src/languages/bulgarian.dart';
export 'src/languages/french.dart';
export 'src/languages/german.dart';
export 'src/languages/italian.dart';
export 'src/languages/spanish.dart';
export 'src/strings.dart';
export 'src/voice/voice.dart';
export 'src/widgets/banner.dart';
export 'src/widgets/layers.dart';
export 'src/widgets/maneuver_icon.dart';
export 'src/widgets/navigation_map.dart';
export 'src/widgets/speedometer.dart';
export 'src/widgets/style.dart';
