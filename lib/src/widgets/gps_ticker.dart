import 'dart:async';

import 'package:flutter/widgets.dart';

import '../controller.dart';

/// Calls [NavigationController.checkGps] every second while it is in the
/// tree, so a GPS that went quiet is noticed. Not exported: the banner and
/// the map use it.
class GpsTicker extends StatefulWidget {
  /// Creates the ticker around [child].
  const GpsTicker({super.key, required this.controller, required this.child});

  /// The navigation to check.
  final NavigationController controller;

  /// What it wraps.
  final Widget child;

  @override
  State<GpsTicker> createState() => _GpsTickerState();
}

class _GpsTickerState extends State<GpsTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.controller.isActive) widget.controller.checkGps();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
