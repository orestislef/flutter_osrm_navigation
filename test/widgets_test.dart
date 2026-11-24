import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'support/drive.dart';

Widget app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? ThemeData(colorSchemeSeed: Colors.indigo),
  home: Scaffold(body: child),
);

Color? boxColor(WidgetTester tester, String key) {
  final box = tester.widget<ColoredBox>(
    find
        .descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(ColoredBox),
        )
        .first,
  );
  return box.color;
}

void main() {
  group('maneuverIcon', () {
    NavStep s(String type, {String? modifier, String side = 'right'}) =>
        NavStep(
          maneuverType: type,
          modifier: modifier,
          location: const LatLng(0, 0),
          drivingSide: side,
        );

    test('turns, U-turns and roundabouts by the side of the road', () {
      expect(maneuverIcon(s('turn', modifier: 'left')), Icons.turn_left);
      expect(
        maneuverIcon(s('turn', modifier: 'sharp right')),
        Icons.turn_sharp_right,
      );
      expect(maneuverIcon(s('continue', modifier: 'uturn')), Icons.u_turn_left);
      expect(
        maneuverIcon(s('continue', modifier: 'uturn', side: 'left')),
        Icons.u_turn_right,
      );
      expect(maneuverIcon(s('roundabout')), Icons.roundabout_right);
      expect(
        maneuverIcon(s('roundabout', side: 'left')),
        Icons.roundabout_left,
      );
      expect(maneuverIcon(s('fork', modifier: 'slight left')), Icons.fork_left);
      expect(maneuverIcon(s('off ramp', modifier: 'right')), Icons.ramp_right);
      expect(maneuverIcon(s('merge')), Icons.merge);
      expect(maneuverIcon(s('arrive')), Icons.flag);
      expect(maneuverIcon(s('arrive'), stop: true), Icons.place);
    });
  });

  group('NavigationBanner', () {
    testWidgets('nothing while not navigating', (tester) async {
      final d = Drive();
      await tester.pumpWidget(app(NavigationBanner(controller: d.nav)));
      expect(find.byKey(const ValueKey('nav-banner')), findsNothing);
    });

    testWidgets('the next turn, how far, and the footer', (tester) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(app(NavigationBanner(controller: d.nav)));
      expect(find.text('600 m'), findsOneWidget);
      expect(find.text('Turn left onto Agias Sofias'), findsOneWidget);
      expect(find.byIcon(Icons.turn_left), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-eta')), findsOneWidget);
      expect(find.textContaining('3 min'), findsOneWidget);
      expect(find.textContaining('1.5 km'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-then')), findsNothing);
    });

    testWidgets('the turn right after, off route, recalculating, arrived', (
      tester,
    ) async {
      final d = Drive()..hold = true;
      d.start(
        navRoute(trackStart, [
          (90, 600, 'Egnatia'),
          (0, 100, 'Agias Sofias'),
          (90, 400, 'Ermou'),
        ]),
      );
      await tester.pumpWidget(app(NavigationBanner(controller: d.nav)));
      await tester.runAsync(
        () => d.feed(
          drive(legs(trackStart, [(90, 600), (0, 100), (90, 400)])).take(5),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-then')), findsOneWidget);
      expect(find.text('Turn right onto Ermou'), findsOneWidget);

      // Off the line to the south.
      await tester.runAsync(
        () => d.feed(
          drive(legs(offsetBy(trackStart, 90, 50), [(180, 100)])).take(8),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-recalculating')), findsOneWidget);
      expect(find.text('Recalculating…'), findsOneWidget);

      await tester.runAsync(() => d.complete(null));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-off-route')), findsOneWidget);

      d.nav.start(testRoute());
      await tester.runAsync(() => d.feed(drive(routePath())));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-arrived')), findsOneWidget);
      expect(find.text('You are at the destination'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-eta')), findsNothing);
    });

    testWidgets('arrived: no empty footer, the buttons move up', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute(), name: 'Ermou 5');
      await tester.pumpWidget(
        app(
          NavigationBanner(
            controller: d.nav,
            footerActions: [
              IconButton(icon: const Icon(Icons.close), onPressed: d.nav.stop),
            ],
          ),
        ),
      );
      expect(find.byKey(const ValueKey('nav-actions-top')), findsNothing);
      await tester.runAsync(() => d.feed(drive(routePath())));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-arrived')), findsOneWidget);
      expect(find.text('Ermou 5'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-actions-top')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-eta')), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(d.nav.isActive, isFalse);
    });

    testWidgets(
      'the voice button mutes, asks for a tap, or says there is none',
      (tester) async {
        final d = Drive();
        d.start(testRoute());
        await tester.pumpWidget(app(NavigationBanner(controller: d.nav)));
        await tester.tap(find.byKey(const ValueKey('nav-voice')));
        await tester.pump();
        expect(d.nav.voiceEnabled, isFalse);
        expect(find.byIcon(Icons.volume_off), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('nav-voice')));
        await tester.pump();
        expect(d.nav.voiceEnabled, isTrue);

        d.voice.current = VoiceState.needsTap;
        d.nav.voiceEnabled = false;
        d.nav.voiceEnabled = true;
        await tester.pump();
        expect(find.byKey(const ValueKey('nav-voice-tap')), findsOneWidget);
        expect(find.text('Tap for voice'), findsOneWidget);

        d.voice.current = VoiceState.unavailable;
        d.nav.voiceEnabled = false;
        await tester.pump();
        expect(find.byKey(const ValueKey('nav-voice-none')), findsOneWidget);
      },
    );

    testWidgets('colors from the theme extension, the widget style wins', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      final theme = ThemeData(
        colorSchemeSeed: Colors.indigo,
        extensions: const [
          NavigationStyle(bannerColor: Colors.black, footerColor: Colors.amber),
        ],
      );
      await tester.pumpWidget(
        app(NavigationBanner(controller: d.nav), theme: theme),
      );
      expect(boxColor(tester, 'nav-banner'), Colors.black);
      await tester.pumpWidget(
        app(
          NavigationBanner(
            controller: d.nav,
            style: const NavigationStyle(bannerColor: Colors.teal),
          ),
          theme: theme,
        ),
      );
      expect(boxColor(tester, 'nav-banner'), Colors.teal);
      final material = tester.widget<Material>(
        find.byKey(const ValueKey('nav-banner')),
      );
      expect(material.color, Colors.amber);
    });

    testWidgets('Greek and imperial', (tester) async {
      final d = Drive(
        strings: const GreekNavigationStrings(),
        settings: const NavigationSettings(units: DistanceUnits.imperial),
      );
      d.start(testRoute());
      await tester.pumpWidget(app(NavigationBanner(controller: d.nav)));
      expect(find.text('Στρίψτε αριστερά στην Agias Sofias'), findsOneWidget);
      expect(find.text('0,4 mi'), findsOneWidget);
    });

    testWidgets('your own icons and footer buttons', (tester) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(
        app(
          NavigationBanner(
            controller: d.nav,
            iconBuilder: (context, step, color, size, stop) =>
                Text('icon:${step.modifier}'),
            footerActions: [
              IconButton(icon: const Icon(Icons.close), onPressed: d.nav.stop),
            ],
          ),
        ),
      );
      expect(find.text('icon:left'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-banner')), findsNothing);
    });
  });

  // This file imports material_ui only, so there is no Theme, Material or
  // MaterialLocalizations of the framework's anywhere in these trees. A
  // banner still on the framework's Material would not find the theme
  // extension, and its IconButton and InkWell would throw for the missing
  // Material ancestor.
  group('material_ui', () {
    const banner = Color(0xFF101820);
    const onBanner = Color(0xFFFEE715);
    const then = Color(0xFF2D2926);
    const onThen = Color(0xFFE94B3C);
    const voiceTap = Color(0xFF00539C);
    const footer = Color(0xFFF2AA4C);

    testWidgets('a NavigationStyle in ThemeData.extensions is what the '
        'banner draws with', (tester) async {
      final d = Drive()..hold = true;
      d.start(
        navRoute(trackStart, [
          (90, 600, 'Egnatia'),
          (0, 100, 'Agias Sofias'),
          (90, 400, 'Ermou'),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            extensions: const [
              NavigationStyle(
                bannerColor: banner,
                onBannerColor: onBanner,
                thenColor: then,
                onThenColor: onThen,
                voiceTapColor: voiceTap,
                footerColor: footer,
              ),
            ],
          ),
          home: Scaffold(body: NavigationBanner(controller: d.nav)),
        ),
      );
      await tester.runAsync(
        () => d.feed(
          drive(legs(trackStart, [(90, 600), (0, 100), (90, 400)])).take(5),
        ),
      );
      d.voice.current = VoiceState.needsTap;
      d.nav.voiceEnabled = false;
      d.nav.voiceEnabled = true;
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(boxColor(tester, 'nav-banner'), banner);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('nav-distance')))
            .style
            ?.color,
        onBanner,
      );
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('nav-then'))).color,
        then,
      );
      expect(
        tester.widget<Text>(find.text('Turn right onto Ermou')).style?.color,
        onThen,
      );
      expect(
        tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('nav-voice-tap-text')),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        voiceTap,
      );
      expect(
        tester.widget<Material>(find.byKey(const ValueKey('nav-banner'))).color,
        footer,
      );
    });

    testWidgets('the banner builds and taps under a material_ui MaterialApp', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NavigationBanner(controller: d.nav)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('nav-banner')), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-voice')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(d.nav.voiceEnabled, isFalse);
    });
  });

  group('NavigationMap options', () {
    testWidgets('stop and destination markers stay upright', (tester) async {
      final d = Drive();
      d.start(
        navRoute(
          trackStart,
          [(90, 600, 'A'), (0, 500, 'B'), (90, 400, 'C')],
          stopsAfter: {0},
        ),
      );
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            stopBuilder: (context, i, p) => const Text('stop'),
          ),
        ),
      );
      await tester.pump();
      final layer = tester.widget<MarkerLayer>(
        find.descendant(
          of: find.byType(NavigationStopsLayer),
          matching: find.byType(MarkerLayer),
        ),
      );
      expect(layer.markers, hasLength(2));
      expect(layer.markers.every((m) => m.rotate == true), isTrue);
    });

    testWidgets('takes a projection and a camera constraint', (tester) async {
      final d = Drive();
      final bounds = LatLngBounds(
        const LatLng(40.5, 22.8),
        const LatLng(40.8, 23.1),
      );
      final constraint = CameraConstraint.contain(bounds: bounds);
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            crs: const Epsg4326(),
            cameraConstraint: constraint,
          ),
        ),
      );
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.crs, isA<Epsg4326>());
      expect(options.cameraConstraint, same(constraint));

      await tester.pumpWidget(
        app(NavigationMap(controller: d.nav, initialCenter: trackStart)),
      );
      final plain = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
      expect(plain.crs, isA<Epsg3857>(), reason: 'unchanged by default');
    });

    testWidgets('a new positionAt moves the camera without a new fix', (
      tester,
    ) async {
      final d = Drive();
      Widget map(double at) => app(
        NavigationMap(
          controller: d.nav,
          initialCenter: trackStart,
          positionAt: at,
        ),
      );
      await tester.pumpWidget(map(0.7));
      await tester.pump();
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(3)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      double carAt() {
        final cam = MapCamera.of(
          tester.element(find.byType(NavigationPositionLayer)),
        );
        return cam.latLngToScreenOffset(d.nav.displayPosition!).dy /
            cam.nonRotatedSize.height;
      }

      expect(carAt(), closeTo(0.7, 0.02));
      await tester.pumpWidget(map(0.4));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(carAt(), closeTo(0.4, 0.02));
    });
  });

  group('NavigationMap when not navigating', () {
    MapCamera camera(WidgetTester tester) =>
        MapCamera.of(tester.element(find.byType(NavigationPositionLayer)));

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('turns with the heading when moving, holds it when slow', (
      tester,
    ) async {
      final d = Drive();
      await tester.pumpWidget(
        app(NavigationMap(controller: d.nav, initialCenter: trackStart)),
      );
      await tester.pump();
      // 36 km/h east, above headingKmh.
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(5)),
      );
      await settle(tester);
      expect(camera(tester).rotation, closeTo(-90, 1));
      // Creeping at 3.6 km/h with the heading swinging: the map holds.
      await tester.runAsync(
        () => d.feed([
          SimFix(offsetBy(trackStart, 90, 52), speed: 1, heading: 200),
          SimFix(offsetBy(trackStart, 90, 53), speed: 1, heading: 330),
        ]),
      );
      await settle(tester);
      expect(camera(tester).rotation, closeTo(-90, 1));
    });

    testWidgets('idleHeadingUp false keeps north up', (tester) async {
      final d = Drive();
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            idleHeadingUp: false,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(5)),
      );
      await settle(tester);
      expect(camera(tester).rotation, closeTo(0, 0.01));
    });

    testWidgets('zooms with the speed and keeps the car low', (tester) async {
      final d = Drive();
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            initialZoom: 14,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(3)),
      );
      await settle(tester);
      final cam = camera(tester);
      // 36 km/h: 16 of the 70 km/h between slowKmh and fastKmh.
      expect(cam.zoom, closeTo(17.5 - 2 * 16 / 70, 0.02));
      final car = cam.latLngToScreenOffset(d.nav.displayPosition!);
      expect(car.dy / cam.nonRotatedSize.height, closeTo(0.7, 0.02));
    });

    testWidgets('comes back to following after a pan', (tester) async {
      final d = Drive();
      final changes = <bool>[];
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            recenterAfter: const Duration(seconds: 3),
            onFollowingChanged: changes.add,
          ),
        ),
      );
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(3)),
      );
      await settle(tester);
      await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-recenter')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('nav-recenter')), findsNothing);
      expect(changes, [false, true]);
    });

    testWidgets('shows the speed once there is a fix', (tester) async {
      final d = Drive();
      await tester.pumpWidget(
        app(NavigationMap(controller: d.nav, initialCenter: trackStart)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsNothing);
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(2)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-speed-limit')), findsNothing);

      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            speedOnlyWhileNavigating: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsNothing);
    });

    testWidgets('takes its size in a loose box with an empty overlay', (
      tester,
    ) async {
      final d = Drive();
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints.loose(const Size(300, 400)),
              child: NavigationMap(
                controller: d.nav,
                initialCenter: trackStart,
                overlays: const [SizedBox.shrink()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(NavigationMap)), const Size(300, 400));
      expect(tester.getSize(find.byType(FlutterMap)), const Size(300, 400));
    });

    testWidgets('showPoint stops following, moves there, and comes back', (
      tester,
    ) async {
      final d = Drive();
      final key = GlobalKey<NavigationMapState>();
      await tester.pumpWidget(
        app(
          NavigationMap(
            key: key,
            controller: d.nav,
            initialCenter: trackStart,
            recenterAfter: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.runAsync(
        () => d.feed(drive(legs(trackStart, [(90, 100)])).take(3)),
      );
      await settle(tester);
      final there = offsetBy(trackStart, 0, 800);
      key.currentState!.showPoint(there, zoom: 15);
      await settle(tester);
      expect(key.currentState!.following, isFalse);
      expect(find.byKey(const ValueKey('nav-recenter')), findsOneWidget);
      expect(metresBetween(camera(tester).center, there), lessThan(5));
      expect(camera(tester).zoom, closeTo(15, 0.01));
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(key.currentState!.following, isTrue);
    });
  });

  group('speed limit sign, stops and following', () {
    NavRoute limited(double kmh) {
      final r = testRoute();
      return NavRoute(
        points: r.points,
        steps: r.steps,
        speedLimitsKmh: [for (var i = 0; i < r.points.length - 1; i++) kmh],
      );
    }

    testWidgets('the sign shows with a limit, the badge turns when speeding', (
      tester,
    ) async {
      final d = Drive();
      d.start(limited(30));
      await tester.pumpWidget(app(NavigationSpeedometer(controller: d.nav)));
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed-limit')), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      final badge = tester.widget<Material>(
        find.byKey(const ValueKey('nav-speed')),
      );
      final error = Theme.of(tester.element(find.byType(Scaffold)))
          .colorScheme
          .error;
      expect(badge.color, error, reason: '36 km/h in a 30');

      await tester.pumpWidget(
        app(NavigationSpeedometer(controller: d.nav, showSpeedLimit: false)),
      );
      expect(find.byKey(const ValueKey('nav-speed-limit')), findsNothing);
    });

    testWidgets('no limit: only the speed', (tester) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(app(NavigationSpeedometer(controller: d.nav)));
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-speed-limit')), findsNothing);
    });

    testWidgets('your own stop and destination widgets', (tester) async {
      final d = Drive();
      d.start(
        navRoute(
          trackStart,
          [(90, 600, 'A'), (0, 500, 'B'), (90, 400, 'C')],
          stopsAfter: {0},
        ),
      );
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            initialZoom: 14,
            stopBuilder: (context, i, p) => Text('stop $i'),
            destinationBuilder: (context, p) => const Text('home'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('stop 0'), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('following changes are reported, recenter from a key', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      final changes = <bool>[];
      final key = GlobalKey<NavigationMapState>();
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pumpWidget(
        app(
          NavigationMap(
            key: key,
            controller: d.nav,
            initialCenter: trackStart,
            onFollowingChanged: changes.add,
          ),
        ),
      );
      await tester.pump();
      expect(key.currentState!.following, isTrue);
      await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
      await tester.pump();
      expect(changes, [false]);
      key.currentState!.recenter();
      await tester.pump(const Duration(seconds: 1));
      expect(changes, [false, true]);
      expect(key.currentState!.following, isTrue);
    });
  });

  group('NavigationSpeedometer', () {
    testWidgets('km/h, mph and the language, only while navigating', (
      tester,
    ) async {
      final d = Drive();
      await tester.pumpWidget(app(NavigationSpeedometer(controller: d.nav)));
      expect(find.byKey(const ValueKey('nav-speed')), findsNothing);
      d.start(testRoute());
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pump();
      expect(find.text('36'), findsOneWidget, reason: '10 m/s');
      expect(find.text('km/h'), findsOneWidget);

      d.nav.settings = const NavigationSettings(units: DistanceUnits.imperial);
      await tester.pump();
      expect(find.text('22'), findsOneWidget);
      expect(find.text('mph'), findsOneWidget);

      d.nav.settings = const NavigationSettings();
      d.nav.strings = const GreekNavigationStrings();
      await tester.pump();
      expect(find.text('χλμ/ώ'), findsOneWidget);

      d.nav.stop();
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsNothing);
    });

    testWidgets('banner, speed and re-center take padding and insets', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            overlayInsets: const EdgeInsets.only(top: 40, bottom: 100),
            bannerPadding: const EdgeInsets.only(top: 10),
            speedPadding: const EdgeInsets.only(left: 20, bottom: 30),
            recenterAlignment: AlignmentDirectional.topEnd,
            recenterPadding: const EdgeInsets.only(top: 200, right: 8),
          ),
        ),
      );
      await tester.pump();
      final screen = tester.getSize(find.byType(NavigationMap));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('nav-banner'))).dy,
        50,
      );
      final speed = tester.getBottomLeft(
        find.byKey(const ValueKey('nav-speed')),
      );
      expect(speed.dx, 20);
      expect(speed.dy, screen.height - 130);

      await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
      await tester.pump();
      final recenter = tester.getTopRight(
        find.byKey(const ValueKey('nav-recenter')),
      );
      expect(recenter.dy, 240);
      expect(recenter.dx, screen.width - 8);
    });

    testWidgets('NavigationMap shows it by default and can hide it', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.runAsync(() => d.feed(drive(routePath()).take(2)));
      await tester.pumpWidget(
        app(NavigationMap(controller: d.nav, initialCenter: trackStart)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsOneWidget);
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            showSpeed: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-speed')), findsNothing);
    });
  });

  group('NavigationMap', () {
    testWidgets('draws the route and the position, follows, re-centers', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            style: const NavigationStyle(routeColor: Colors.green),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() => d.feed(drive(routePath()).take(10)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey('nav-banner')), findsOneWidget);
      final route = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(route.polylines.single.color, Colors.green);
      expect(find.byType(NavigationPositionLayer), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-recenter')), findsNothing);

      final camera = MapCamera.of(tester.element(find.byType(PolylineLayer)));
      expect(camera.rotation, closeTo(-90, 1), reason: 'heading up, east');

      await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-recenter')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-recenter')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('nav-recenter')), findsNothing);
    });

    testWidgets('comes back to following on its own after the wait', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(
        app(
          NavigationMap(
            controller: d.nav,
            initialCenter: trackStart,
            recenterAfter: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.runAsync(() => d.feed(drive(routePath()).take(3)));
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
      await tester.pump();
      expect(find.byKey(const ValueKey('nav-recenter')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('nav-recenter')), findsNothing);
    });

    testWidgets('mid glide the line starts right at the marker, on the road', (
      tester,
    ) async {
      final d = Drive();
      d.start(testRoute());
      await tester.pumpWidget(
        app(NavigationMap(controller: d.nav, initialCenter: trackStart)),
      );
      final track = drive(routePath());
      // Up to 20 m before the corner, then one fix 20 m past it.
      await tester.runAsync(() => d.feed(track.take(58)));
      // A glide starts on the next frame and takes 900 ms.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => d.feed([track[61]]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final marker = tester
          .widget<NavigationPositionLayer>(find.byType(NavigationPositionLayer))
          .position!;
      final line = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points;
      expect(metresBetween(marker, line.first), lessThan(0.5));
      // Halfway through the glide it is at the corner, not cutting across.
      expect(metresBetween(marker, cornerA), lessThan(3));
    });
  });
}
