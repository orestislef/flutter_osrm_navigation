import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colors and sizes of the navigation widgets.
///
/// Every field is optional. What you leave out comes from the app's
/// [ColorScheme], so the widgets match your theme with no setup. Set it app
/// wide as a theme extension, or per widget with their `style` parameter
/// (which wins over the theme):
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       NavigationStyle(bannerColor: Colors.black, routeColor: Colors.teal),
///     ],
///   ),
/// )
/// ```
@immutable
class NavigationStyle extends ThemeExtension<NavigationStyle> {
  /// Creates a style. Leave a field out to take it from the theme.
  const NavigationStyle({
    this.bannerColor,
    this.onBannerColor,
    this.thenColor,
    this.onThenColor,
    this.offRouteColor,
    this.onOffRouteColor,
    this.voiceTapColor,
    this.onVoiceTapColor,
    this.footerColor,
    this.onFooterColor,
    this.footerAccentColor,
    this.footerMutedColor,
    this.bannerBorderRadius,
    this.bannerElevation,
    this.distanceTextStyle,
    this.instructionTextStyle,
    this.footerTextStyle,
    this.routeColor,
    this.routeBorderColor,
    this.routeWidth,
    this.routeBorderWidth,
    this.traveledColor,
    this.offRouteLineColor,
    this.puckColor,
    this.puckBorderColor,
    this.puckArrowColor,
    this.puckSize,
    this.accuracyColor,
    this.destinationColor,
    this.stopColor,
    this.onMarkerColor,
    this.buttonColor,
    this.onButtonColor,
    this.speedColor,
    this.onSpeedColor,
    this.speedingColor,
    this.onSpeedingColor,
    this.speedLimitColor,
  });

  /// Background of the banner's main row. Default: primary.
  final Color? bannerColor;

  /// Text and icons on [bannerColor]. Default: onPrimary.
  final Color? onBannerColor;

  /// Background of the "then" row. Default: primaryContainer.
  final Color? thenColor;

  /// Text and icons on [thenColor]. Default: onPrimaryContainer.
  final Color? onThenColor;

  /// Background of the off route row. Default: errorContainer.
  final Color? offRouteColor;

  /// Text on [offRouteColor]. Default: onErrorContainer.
  final Color? onOffRouteColor;

  /// Background of the "tap for voice" row. Default: tertiaryContainer.
  final Color? voiceTapColor;

  /// Text and icons on [voiceTapColor]. Default: onTertiaryContainer.
  final Color? onVoiceTapColor;

  /// Background of the footer with the time and distance left. Default:
  /// surface.
  final Color? footerColor;

  /// Text in the footer. Default: onSurface.
  final Color? onFooterColor;

  /// The time left in the footer. Default: primary.
  final Color? footerAccentColor;

  /// Separators in the footer. Default: onSurfaceVariant.
  final Color? footerMutedColor;

  /// Corners of the banner. Default: 16.
  final BorderRadius? bannerBorderRadius;

  /// Shadow of the banner. Default: 6.
  final double? bannerElevation;

  /// Distance to the next maneuver, merged over headlineSmall.
  final TextStyle? distanceTextStyle;

  /// The instruction, merged over titleSmall.
  final TextStyle? instructionTextStyle;

  /// The footer, merged over bodyMedium.
  final TextStyle? footerTextStyle;

  /// The route ahead. Default: primary.
  final Color? routeColor;

  /// Edge of the route line. Default: surface.
  final Color? routeBorderColor;

  /// Width of the route line. Default: 8.
  final double? routeWidth;

  /// Width of its edge. Default: 2.
  final double? routeBorderWidth;

  /// The part already driven. Default: not drawn.
  final Color? traveledColor;

  /// The route while off it. Default: [routeColor] at half strength.
  final Color? offRouteLineColor;

  /// The position marker. Default: primary.
  final Color? puckColor;

  /// Ring around the position marker. Default: white.
  final Color? puckBorderColor;

  /// The arrow inside the position marker. Default: white.
  final Color? puckArrowColor;

  /// Size of the position marker. Default: 40.
  final double? puckSize;

  /// The GPS accuracy circle. Default: primary at 15%.
  final Color? accuracyColor;

  /// The destination marker. Default: error.
  final Color? destinationColor;

  /// Stop markers. Default: tertiary.
  final Color? stopColor;

  /// Icons and numbers on markers. Default: white.
  final Color? onMarkerColor;

  /// Map buttons such as re-center. Default: surface.
  final Color? buttonColor;

  /// Icons on map buttons. Default: primary.
  final Color? onButtonColor;

  /// The speed badge. Default: surface.
  final Color? speedColor;

  /// The number on the speed badge. Default: onSurface.
  final Color? onSpeedColor;

  /// The speed badge while over the limit. Default: error.
  final Color? speedingColor;

  /// The number on it while over the limit. Default: onError.
  final Color? onSpeedingColor;

  /// The ring of the speed limit sign. Default: a road sign red.
  final Color? speedLimitColor;

  /// The style for [context]: [local] over the theme's extension over the
  /// color scheme.
  static ResolvedNavigationStyle resolve(
    BuildContext context, [
    NavigationStyle? local,
  ]) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = theme.extension<NavigationStyle>();
    final s = t == null ? (local ?? const NavigationStyle()) : t.merge(local);
    final route = s.routeColor ?? cs.primary;
    return ResolvedNavigationStyle(
      bannerColor: s.bannerColor ?? cs.primary,
      onBannerColor: s.onBannerColor ?? cs.onPrimary,
      thenColor: s.thenColor ?? cs.primaryContainer,
      onThenColor: s.onThenColor ?? cs.onPrimaryContainer,
      offRouteColor: s.offRouteColor ?? cs.errorContainer,
      onOffRouteColor: s.onOffRouteColor ?? cs.onErrorContainer,
      voiceTapColor: s.voiceTapColor ?? cs.tertiaryContainer,
      onVoiceTapColor: s.onVoiceTapColor ?? cs.onTertiaryContainer,
      footerColor: s.footerColor ?? cs.surface,
      onFooterColor: s.onFooterColor ?? cs.onSurface,
      footerAccentColor: s.footerAccentColor ?? cs.primary,
      footerMutedColor: s.footerMutedColor ?? cs.onSurfaceVariant,
      bannerBorderRadius:
          s.bannerBorderRadius ?? const BorderRadius.all(Radius.circular(16)),
      bannerElevation: s.bannerElevation ?? 6,
      distanceTextStyle: (theme.textTheme.headlineSmall ?? const TextStyle())
          .merge(s.distanceTextStyle),
      instructionTextStyle: (theme.textTheme.titleSmall ?? const TextStyle())
          .merge(s.instructionTextStyle),
      footerTextStyle: (theme.textTheme.bodyMedium ?? const TextStyle()).merge(
        s.footerTextStyle,
      ),
      routeColor: route,
      routeBorderColor: s.routeBorderColor ?? cs.surface,
      routeWidth: s.routeWidth ?? 8,
      routeBorderWidth: s.routeBorderWidth ?? 2,
      traveledColor: s.traveledColor,
      offRouteLineColor:
          s.offRouteLineColor ?? route.withValues(alpha: route.a * 0.5),
      puckColor: s.puckColor ?? cs.primary,
      puckBorderColor: s.puckBorderColor ?? Colors.white,
      puckArrowColor: s.puckArrowColor ?? Colors.white,
      puckSize: s.puckSize ?? 40,
      accuracyColor: s.accuracyColor ?? cs.primary.withValues(alpha: 0.15),
      destinationColor: s.destinationColor ?? cs.error,
      stopColor: s.stopColor ?? cs.tertiary,
      onMarkerColor: s.onMarkerColor ?? Colors.white,
      buttonColor: s.buttonColor ?? cs.surface,
      onButtonColor: s.onButtonColor ?? cs.primary,
      speedColor: s.speedColor ?? cs.surface,
      onSpeedColor: s.onSpeedColor ?? cs.onSurface,
      speedingColor: s.speedingColor ?? cs.error,
      onSpeedingColor: s.onSpeedingColor ?? cs.onError,
      speedLimitColor: s.speedLimitColor ?? const Color(0xFFD32F2F),
    );
  }

  /// This style with the fields [other] sets taking over.
  NavigationStyle merge(NavigationStyle? other) {
    if (other == null) return this;
    return copyWith(
      bannerColor: other.bannerColor,
      onBannerColor: other.onBannerColor,
      thenColor: other.thenColor,
      onThenColor: other.onThenColor,
      offRouteColor: other.offRouteColor,
      onOffRouteColor: other.onOffRouteColor,
      voiceTapColor: other.voiceTapColor,
      onVoiceTapColor: other.onVoiceTapColor,
      footerColor: other.footerColor,
      onFooterColor: other.onFooterColor,
      footerAccentColor: other.footerAccentColor,
      footerMutedColor: other.footerMutedColor,
      bannerBorderRadius: other.bannerBorderRadius,
      bannerElevation: other.bannerElevation,
      distanceTextStyle:
          distanceTextStyle?.merge(other.distanceTextStyle) ??
          other.distanceTextStyle,
      instructionTextStyle:
          instructionTextStyle?.merge(other.instructionTextStyle) ??
          other.instructionTextStyle,
      footerTextStyle:
          footerTextStyle?.merge(other.footerTextStyle) ??
          other.footerTextStyle,
      routeColor: other.routeColor,
      routeBorderColor: other.routeBorderColor,
      routeWidth: other.routeWidth,
      routeBorderWidth: other.routeBorderWidth,
      traveledColor: other.traveledColor,
      offRouteLineColor: other.offRouteLineColor,
      puckColor: other.puckColor,
      puckBorderColor: other.puckBorderColor,
      puckArrowColor: other.puckArrowColor,
      puckSize: other.puckSize,
      accuracyColor: other.accuracyColor,
      destinationColor: other.destinationColor,
      stopColor: other.stopColor,
      onMarkerColor: other.onMarkerColor,
      buttonColor: other.buttonColor,
      onButtonColor: other.onButtonColor,
      speedColor: other.speedColor,
      onSpeedColor: other.onSpeedColor,
      speedingColor: other.speedingColor,
      onSpeedingColor: other.onSpeedingColor,
      speedLimitColor: other.speedLimitColor,
    );
  }

  @override
  NavigationStyle copyWith({
    Color? bannerColor,
    Color? onBannerColor,
    Color? thenColor,
    Color? onThenColor,
    Color? offRouteColor,
    Color? onOffRouteColor,
    Color? voiceTapColor,
    Color? onVoiceTapColor,
    Color? footerColor,
    Color? onFooterColor,
    Color? footerAccentColor,
    Color? footerMutedColor,
    BorderRadius? bannerBorderRadius,
    double? bannerElevation,
    TextStyle? distanceTextStyle,
    TextStyle? instructionTextStyle,
    TextStyle? footerTextStyle,
    Color? routeColor,
    Color? routeBorderColor,
    double? routeWidth,
    double? routeBorderWidth,
    Color? traveledColor,
    Color? offRouteLineColor,
    Color? puckColor,
    Color? puckBorderColor,
    Color? puckArrowColor,
    double? puckSize,
    Color? accuracyColor,
    Color? destinationColor,
    Color? stopColor,
    Color? onMarkerColor,
    Color? buttonColor,
    Color? onButtonColor,
    Color? speedColor,
    Color? onSpeedColor,
    Color? speedingColor,
    Color? onSpeedingColor,
    Color? speedLimitColor,
  }) {
    return NavigationStyle(
      bannerColor: bannerColor ?? this.bannerColor,
      onBannerColor: onBannerColor ?? this.onBannerColor,
      thenColor: thenColor ?? this.thenColor,
      onThenColor: onThenColor ?? this.onThenColor,
      offRouteColor: offRouteColor ?? this.offRouteColor,
      onOffRouteColor: onOffRouteColor ?? this.onOffRouteColor,
      voiceTapColor: voiceTapColor ?? this.voiceTapColor,
      onVoiceTapColor: onVoiceTapColor ?? this.onVoiceTapColor,
      footerColor: footerColor ?? this.footerColor,
      onFooterColor: onFooterColor ?? this.onFooterColor,
      footerAccentColor: footerAccentColor ?? this.footerAccentColor,
      footerMutedColor: footerMutedColor ?? this.footerMutedColor,
      bannerBorderRadius: bannerBorderRadius ?? this.bannerBorderRadius,
      bannerElevation: bannerElevation ?? this.bannerElevation,
      distanceTextStyle: distanceTextStyle ?? this.distanceTextStyle,
      instructionTextStyle: instructionTextStyle ?? this.instructionTextStyle,
      footerTextStyle: footerTextStyle ?? this.footerTextStyle,
      routeColor: routeColor ?? this.routeColor,
      routeBorderColor: routeBorderColor ?? this.routeBorderColor,
      routeWidth: routeWidth ?? this.routeWidth,
      routeBorderWidth: routeBorderWidth ?? this.routeBorderWidth,
      traveledColor: traveledColor ?? this.traveledColor,
      offRouteLineColor: offRouteLineColor ?? this.offRouteLineColor,
      puckColor: puckColor ?? this.puckColor,
      puckBorderColor: puckBorderColor ?? this.puckBorderColor,
      puckArrowColor: puckArrowColor ?? this.puckArrowColor,
      puckSize: puckSize ?? this.puckSize,
      accuracyColor: accuracyColor ?? this.accuracyColor,
      destinationColor: destinationColor ?? this.destinationColor,
      stopColor: stopColor ?? this.stopColor,
      onMarkerColor: onMarkerColor ?? this.onMarkerColor,
      buttonColor: buttonColor ?? this.buttonColor,
      onButtonColor: onButtonColor ?? this.onButtonColor,
      speedColor: speedColor ?? this.speedColor,
      onSpeedColor: onSpeedColor ?? this.onSpeedColor,
      speedingColor: speedingColor ?? this.speedingColor,
      onSpeedingColor: onSpeedingColor ?? this.onSpeedingColor,
      speedLimitColor: speedLimitColor ?? this.speedLimitColor,
    );
  }

  @override
  NavigationStyle lerp(covariant NavigationStyle? other, double t) {
    if (other == null) return this;
    Color? c(Color? a, Color? b) => Color.lerp(a, b, t);
    double? d(double? a, double? b) => lerpDouble(a, b, t);
    return NavigationStyle(
      bannerColor: c(bannerColor, other.bannerColor),
      onBannerColor: c(onBannerColor, other.onBannerColor),
      thenColor: c(thenColor, other.thenColor),
      onThenColor: c(onThenColor, other.onThenColor),
      offRouteColor: c(offRouteColor, other.offRouteColor),
      onOffRouteColor: c(onOffRouteColor, other.onOffRouteColor),
      voiceTapColor: c(voiceTapColor, other.voiceTapColor),
      onVoiceTapColor: c(onVoiceTapColor, other.onVoiceTapColor),
      footerColor: c(footerColor, other.footerColor),
      onFooterColor: c(onFooterColor, other.onFooterColor),
      footerAccentColor: c(footerAccentColor, other.footerAccentColor),
      footerMutedColor: c(footerMutedColor, other.footerMutedColor),
      bannerBorderRadius: BorderRadius.lerp(
        bannerBorderRadius,
        other.bannerBorderRadius,
        t,
      ),
      bannerElevation: d(bannerElevation, other.bannerElevation),
      distanceTextStyle: TextStyle.lerp(
        distanceTextStyle,
        other.distanceTextStyle,
        t,
      ),
      instructionTextStyle: TextStyle.lerp(
        instructionTextStyle,
        other.instructionTextStyle,
        t,
      ),
      footerTextStyle: TextStyle.lerp(
        footerTextStyle,
        other.footerTextStyle,
        t,
      ),
      routeColor: c(routeColor, other.routeColor),
      routeBorderColor: c(routeBorderColor, other.routeBorderColor),
      routeWidth: d(routeWidth, other.routeWidth),
      routeBorderWidth: d(routeBorderWidth, other.routeBorderWidth),
      traveledColor: c(traveledColor, other.traveledColor),
      offRouteLineColor: c(offRouteLineColor, other.offRouteLineColor),
      puckColor: c(puckColor, other.puckColor),
      puckBorderColor: c(puckBorderColor, other.puckBorderColor),
      puckArrowColor: c(puckArrowColor, other.puckArrowColor),
      puckSize: d(puckSize, other.puckSize),
      accuracyColor: c(accuracyColor, other.accuracyColor),
      destinationColor: c(destinationColor, other.destinationColor),
      stopColor: c(stopColor, other.stopColor),
      onMarkerColor: c(onMarkerColor, other.onMarkerColor),
      buttonColor: c(buttonColor, other.buttonColor),
      onButtonColor: c(onButtonColor, other.onButtonColor),
      speedColor: c(speedColor, other.speedColor),
      onSpeedColor: c(onSpeedColor, other.onSpeedColor),
      speedingColor: c(speedingColor, other.speedingColor),
      onSpeedingColor: c(onSpeedingColor, other.onSpeedingColor),
      speedLimitColor: c(speedLimitColor, other.speedLimitColor),
    );
  }
}

/// A [NavigationStyle] with every value filled in, from
/// [NavigationStyle.resolve]. Handy when you build your own widgets around
/// the controller and want them to match.
@immutable
class ResolvedNavigationStyle {
  /// Creates a resolved style. Use [NavigationStyle.resolve] instead.
  const ResolvedNavigationStyle({
    required this.bannerColor,
    required this.onBannerColor,
    required this.thenColor,
    required this.onThenColor,
    required this.offRouteColor,
    required this.onOffRouteColor,
    required this.voiceTapColor,
    required this.onVoiceTapColor,
    required this.footerColor,
    required this.onFooterColor,
    required this.footerAccentColor,
    required this.footerMutedColor,
    required this.bannerBorderRadius,
    required this.bannerElevation,
    required this.distanceTextStyle,
    required this.instructionTextStyle,
    required this.footerTextStyle,
    required this.routeColor,
    required this.routeBorderColor,
    required this.routeWidth,
    required this.routeBorderWidth,
    required this.traveledColor,
    required this.offRouteLineColor,
    required this.puckColor,
    required this.puckBorderColor,
    required this.puckArrowColor,
    required this.puckSize,
    required this.accuracyColor,
    required this.destinationColor,
    required this.stopColor,
    required this.onMarkerColor,
    required this.buttonColor,
    required this.onButtonColor,
    required this.speedColor,
    required this.onSpeedColor,
    required this.speedingColor,
    required this.onSpeedingColor,
    required this.speedLimitColor,
  });

  /// See [NavigationStyle.bannerColor].
  final Color bannerColor;

  /// See [NavigationStyle.onBannerColor].
  final Color onBannerColor;

  /// See [NavigationStyle.thenColor].
  final Color thenColor;

  /// See [NavigationStyle.onThenColor].
  final Color onThenColor;

  /// See [NavigationStyle.offRouteColor].
  final Color offRouteColor;

  /// See [NavigationStyle.onOffRouteColor].
  final Color onOffRouteColor;

  /// See [NavigationStyle.voiceTapColor].
  final Color voiceTapColor;

  /// See [NavigationStyle.onVoiceTapColor].
  final Color onVoiceTapColor;

  /// See [NavigationStyle.footerColor].
  final Color footerColor;

  /// See [NavigationStyle.onFooterColor].
  final Color onFooterColor;

  /// See [NavigationStyle.footerAccentColor].
  final Color footerAccentColor;

  /// See [NavigationStyle.footerMutedColor].
  final Color footerMutedColor;

  /// See [NavigationStyle.bannerBorderRadius].
  final BorderRadius bannerBorderRadius;

  /// See [NavigationStyle.bannerElevation].
  final double bannerElevation;

  /// See [NavigationStyle.distanceTextStyle].
  final TextStyle distanceTextStyle;

  /// See [NavigationStyle.instructionTextStyle].
  final TextStyle instructionTextStyle;

  /// See [NavigationStyle.footerTextStyle].
  final TextStyle footerTextStyle;

  /// See [NavigationStyle.routeColor].
  final Color routeColor;

  /// See [NavigationStyle.routeBorderColor].
  final Color routeBorderColor;

  /// See [NavigationStyle.routeWidth].
  final double routeWidth;

  /// See [NavigationStyle.routeBorderWidth].
  final double routeBorderWidth;

  /// See [NavigationStyle.traveledColor]. Null when not drawn.
  final Color? traveledColor;

  /// See [NavigationStyle.offRouteLineColor].
  final Color offRouteLineColor;

  /// See [NavigationStyle.puckColor].
  final Color puckColor;

  /// See [NavigationStyle.puckBorderColor].
  final Color puckBorderColor;

  /// See [NavigationStyle.puckArrowColor].
  final Color puckArrowColor;

  /// See [NavigationStyle.puckSize].
  final double puckSize;

  /// See [NavigationStyle.accuracyColor].
  final Color accuracyColor;

  /// See [NavigationStyle.destinationColor].
  final Color destinationColor;

  /// See [NavigationStyle.stopColor].
  final Color stopColor;

  /// See [NavigationStyle.onMarkerColor].
  final Color onMarkerColor;

  /// See [NavigationStyle.buttonColor].
  final Color buttonColor;

  /// See [NavigationStyle.onButtonColor].
  final Color onButtonColor;

  /// See [NavigationStyle.speedColor].
  final Color speedColor;

  /// See [NavigationStyle.onSpeedColor].
  final Color onSpeedColor;

  /// See [NavigationStyle.speedingColor].
  final Color speedingColor;

  /// See [NavigationStyle.onSpeedingColor].
  final Color onSpeedingColor;

  /// See [NavigationStyle.speedLimitColor].
  final Color speedLimitColor;
}
