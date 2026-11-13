import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'off_route.dart';

/// What [NavigationLocation.ensurePermission] found.
enum LocationAccess {
  /// Location can be used.
  granted,

  /// The user said no, they can be asked again.
  denied,

  /// The user said no for good. Only the system settings can change it, see
  /// [NavigationLocation.openSettings].
  deniedForever,

  /// Location is switched off on the device.
  serviceDisabled,
}

/// GPS fixes for navigation, through geolocator, set up to keep coming with
/// the app in the background.
///
/// On Android the stream runs as a foreground service with a notification,
/// which keeps fixes coming with the app in the background or the screen
/// off. It only needs the "while using the app" permission as long as the
/// stream starts while the app is on screen.
///
/// On iOS it asks for automotive navigation accuracy and does not let iOS
/// pause the updates at a red light. With the `location` background mode in
/// Info.plist it keeps going in the background (with the blue indicator).
///
/// Everything the platforms need in their manifests is in the README.
class NavigationLocation {
  NavigationLocation._();

  /// Checks that location is on and allowed, and asks for permission when
  /// it can.
  static Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  /// Opens the app's settings page, where a permission denied for good can
  /// be given again.
  static Future<bool> openSettings() => Geolocator.openAppSettings();

  /// Opens the device's location settings, for when location is off.
  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  /// A stream of fixes for navigation.
  ///
  /// With [background] true (the default) fixes keep coming with the app in
  /// the background. On Android that shows a notification with
  /// [notificationTitle] and [notificationText] while the stream is
  /// listened to; [notificationIcon] is a drawable or mipmap resource of
  /// your app.
  static Stream<NavFix> stream({
    bool background = true,
    Duration interval = const Duration(seconds: 1),
    String notificationTitle = 'Navigation',
    String notificationText = 'Directions are on',
    String notificationChannelName = 'Navigation',
    AndroidResource notificationIcon =
        const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  }) {
    return Geolocator.getPositionStream(
      locationSettings: settings(
        background: background,
        interval: interval,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        notificationChannelName: notificationChannelName,
        notificationIcon: notificationIcon,
      ),
    ).map(fromPosition);
  }

  /// The geolocator settings [stream] uses, for when you run geolocator
  /// yourself.
  static LocationSettings settings({
    bool background = true,
    Duration interval = const Duration(seconds: 1),
    String notificationTitle = 'Navigation',
    String notificationText = 'Directions are on',
    String notificationChannelName = 'Navigation',
    AndroidResource notificationIcon =
        const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
  }) {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        maximumAge: Duration.zero,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: interval,
          foregroundNotificationConfig: background
              ? ForegroundNotificationConfig(
                  notificationTitle: notificationTitle,
                  notificationText: notificationText,
                  notificationChannelName: notificationChannelName,
                  notificationIcon: notificationIcon,
                  enableWakeLock: true,
                  setOngoing: true,
                )
              : null,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: background,
          allowBackgroundLocationUpdates: background,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
    }
  }

  /// A geolocator [Position] as a [NavFix]. Unknown speed and heading
  /// (negative on iOS) become null.
  static NavFix fromPosition(Position p) => NavFix(
        LatLng(p.latitude, p.longitude),
        accuracyM: p.accuracy > 0 ? p.accuracy : null,
        speedMps: p.speed >= 0 ? p.speed : null,
        headingDeg: p.heading >= 0 ? p.heading : null,
      );
}
