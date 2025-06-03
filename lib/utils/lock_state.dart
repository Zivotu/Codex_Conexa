// lock_state.dart
import 'package:flutter/material.dart';

class LockState extends InheritedWidget {
  final bool isLocked;
  final Function toggleLock;

  const LockState({
    super.key,
    required this.isLocked,
    required this.toggleLock,
    required super.child,
  });

  static LockState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LockState>();
  }

  @override
  bool updateShouldNotify(covariant LockState oldWidget) {
    return oldWidget.isLocked != isLocked;
  }
}
