import 'package:flutter/material.dart';

import '../controller.dart';
import '../route.dart';
import '../voice/voice.dart';
import 'maneuver_icon.dart';
import 'style.dart';

/// The banner over the map while navigating.
///
/// The next maneuver (its icon, how far, the instruction) on a strong
/// color, the maneuver right after it when it comes close, a line while off
/// the route, and a footer with the time and distance left and the arrival
/// time. While a new route is on its way it says so, and at the end it says
/// the user is there. The voice button mutes and unmutes, asks for the tap a
/// browser needs, or shows that the device has no voice.
///
/// It rebuilds itself from [controller] and takes no space when not
/// navigating.
class NavigationBanner extends StatelessWidget {
  /// Creates the banner.
  const NavigationBanner({
    super.key,
    required this.controller,
    this.style,
    this.showVoiceButton = true,
    this.showFooter = true,
    this.footerActions = const [],
    this.iconBuilder,
  });

  /// The navigation to show.
  final NavigationController controller;

  /// Colors over the theme's. See [NavigationStyle].
  final NavigationStyle? style;

  /// Show the mute button.
  final bool showVoiceButton;

  /// Show the time and distance left.
  final bool showFooter;

  /// Extra buttons at the end of the footer (stop, open in another app).
  final List<Widget> footerActions;

  /// Your own maneuver icons. [stop] is true for the arrival at a stop.
  final Widget Function(BuildContext context, NavStep step, Color color,
      double size, bool stop)? iconBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final step = controller.upcomingStep;
        if (!controller.isActive || step == null) {
          return const SizedBox.shrink();
        }
        return _build(context, step);
      },
    );
  }

  Widget _icon(
      BuildContext context, NavStep step, Color color, double size, bool stop) {
    final custom = iconBuilder;
    if (custom != null) return custom(context, step, color, size, stop);
    return Icon(maneuverIcon(step, stop: stop), color: color, size: size);
  }

  /// The time in the navigation's language, not the app's: a Greek banner
  /// in an English app says 17:14, not 5:14 PM.
  String _clock(BuildContext context, DateTime time) =>
      controller.strings.clockTime(time,
          use24h: MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false);

  Widget _build(BuildContext context, NavStep step) {
    final s = NavigationStyle.resolve(context, style);
    final c = controller;
    final strings = c.strings;
    final units = c.settings.units;
    final on = s.onBannerColor;
    final arrived = c.arrived;
    final recalculating = c.recalculating;
    final then = arrived || recalculating ? null : c.thenStep;
    final stop = step.isArrive && c.upcomingIndex < c.steps.length - 1;

    Widget? voiceButton;
    if (showVoiceButton) {
      final state = c.voiceState;
      if (state == VoiceState.unavailable) {
        voiceButton = IconButton(
          key: const ValueKey('nav-voice-none'),
          icon: Icon(Icons.voice_over_off, color: on.withValues(alpha: 0.6)),
          tooltip: strings.voiceUnavailable,
          onPressed: null,
        );
      } else if (state == VoiceState.needsTap && c.voiceEnabled) {
        voiceButton = IconButton(
          key: const ValueKey('nav-voice-tap'),
          icon: Icon(Icons.touch_app, color: on),
          tooltip: strings.voiceTapHint,
          onPressed: c.unlockVoice,
        );
      } else {
        voiceButton = IconButton(
          key: const ValueKey('nav-voice'),
          icon: Icon(c.voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: c.voiceEnabled ? on : on.withValues(alpha: 0.6)),
          tooltip: c.voiceEnabled ? strings.mute : strings.unmute,
          onPressed: () => c.voiceEnabled = !c.voiceEnabled,
        );
      }
    }

    final titleStyle = s.instructionTextStyle
        .copyWith(color: on, fontWeight: FontWeight.w700, fontSize: 18);
    final Widget main;
    if (recalculating) {
      main = Row(
        key: const ValueKey('nav-recalculating'),
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: on),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(strings.recalculating,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle),
          ),
        ],
      );
    } else if (arrived) {
      main = Row(
        key: const ValueKey('nav-arrived'),
        children: [
          Icon(Icons.flag, color: on, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.arrived(c.arrival),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle),
                if ((c.destinationName ?? '').isNotEmpty)
                  Text(c.destinationName!,
                      key: const ValueKey('nav-arrived-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: s.instructionTextStyle
                          .copyWith(color: on.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      );
    } else {
      main = Row(
        key: const ValueKey('nav-turn'),
        children: [
          _icon(context, step, on, 40, stop),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.shortDistance(c.distanceToNextStep, units),
                  key: const ValueKey('nav-distance'),
                  maxLines: 1,
                  style: s.distanceTextStyle.copyWith(
                    color: on,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.1,
                  ),
                ),
                Text(
                  c.upcomingInstruction ?? '',
                  key: const ValueKey('nav-instruction'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: s.instructionTextStyle
                      .copyWith(color: on, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final labelStyle =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final eta = c.estimatedArrival;
    final dot = TextSpan(
        text: '  ·  ',
        style:
            TextStyle(color: s.footerMutedColor, fontWeight: FontWeight.w800));
    final Widget? footerText = !showFooter ||
            arrived ||
            c.remainingDistance <= 0
        ? null
        : Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: strings
                      .shortDuration(c.remainingDuration.inSeconds.toDouble()),
                  style: TextStyle(
                      color: s.footerAccentColor, fontWeight: FontWeight.w800)),
              dot,
              TextSpan(text: strings.shortDistance(c.remainingDistance, units)),
              if (eta != null) ...[
                dot,
                TextSpan(text: strings.arrivalTime(_clock(context, eta))),
              ],
            ]),
            key: const ValueKey('nav-eta'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: s.footerTextStyle.copyWith(
              color: s.onFooterColor,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    final footerRow = footerText != null;
    final needsTap = c.voiceEnabled &&
        c.voiceState == VoiceState.needsTap &&
        showVoiceButton;

    return Material(
      key: const ValueKey('nav-banner'),
      elevation: s.bannerElevation,
      borderRadius: s.bannerBorderRadius,
      clipBehavior: Clip.antiAlias,
      color: s.footerColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: s.bannerColor,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 4, 10),
              child: Row(children: [
                Expanded(child: main),
                if (voiceButton != null) voiceButton,
                // Nothing to show below (arrived): the buttons come up here
                // instead of sitting alone on an empty strip.
                if (!footerRow && footerActions.isNotEmpty)
                  IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(foregroundColor: on),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(color: on),
                      child: Row(
                        key: const ValueKey('nav-actions-top'),
                        mainAxisSize: MainAxisSize.min,
                        children: footerActions,
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          if (then != null)
            ColoredBox(
              key: const ValueKey('nav-then'),
              color: s.thenColor,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(strings.thenLabel,
                        style: labelStyle.copyWith(color: s.onThenColor)),
                    const SizedBox(width: 8),
                    _icon(context, then, s.onThenColor, 20, false),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.thenInstruction ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle.copyWith(color: s.onThenColor)),
                    ),
                  ],
                ),
              ),
            ),
          if (c.offRoute && !recalculating && !arrived)
            ColoredBox(
              key: const ValueKey('nav-off-route'),
              color: s.offRouteColor,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(strings.offRoute,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle.copyWith(color: s.onOffRouteColor)),
              ),
            ),
          if (needsTap)
            Material(
              color: s.voiceTapColor,
              child: InkWell(
                key: const ValueKey('nav-voice-tap-text'),
                onTap: c.unlockVoice,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over,
                          size: 18, color: s.onVoiceTapColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(strings.voiceTap,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                labelStyle.copyWith(color: s.onVoiceTapColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (footerRow)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(child: footerText),
                    ...footerActions,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
