import 'dart:async';
import 'package:flutter/material.dart';

class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onInactivity;
  final Duration timeout;

  const InactivityWrapper({
    super.key,
    required this.child,
    required this.onInactivity,
    this.timeout = const Duration(minutes: 5),
  });

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, widget.onInactivity);
  }

  void _handleInteraction([_]) {
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleInteraction,
      onPointerMove: _handleInteraction,
      onPointerUp: _handleInteraction,
      onPointerHover: _handleInteraction,
      onPointerSignal: _handleInteraction,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
