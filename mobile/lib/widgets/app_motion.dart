import 'package:flutter/material.dart';

/// Page enter animation (Fade + Slide)
class PageMotion extends StatelessWidget {
  final Widget child;
  const PageMotion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final offsetY = (1 - value) * 20;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: child,
          ),
        );
      },
    );
  }
}

/// List item stagger animation
class StaggerItem extends StatelessWidget {
  final Widget child;
  final int index;

  const StaggerItem({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 40 * index.clamp(0, 6));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final offsetY = (1 - value) * 16;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: child,
          ),
        );
      },
      child: FutureBuilder(
        future: Future.delayed(delay),
        builder: (_, snap) =>
            snap.connectionState == ConnectionState.done
                ? child
                : const SizedBox.shrink(),
      ),
    );
  }
}