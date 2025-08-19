import 'package:flutter/material.dart';

class SlideFadeRoute extends PageRouteBuilder {
  final Widget page;
  final AxisDirection direction;

  SlideFadeRoute({required this.page, this.direction = AxisDirection.left})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const curve = Curves.easeInOut;

      // Fade Animation
      final opacityAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      // Slide Animation
      Offset begin;
      switch (direction) {
        case AxisDirection.left:
          begin = const Offset(1.0, 0.0);
          break;
        case AxisDirection.right:
          begin = const Offset(-1.0, 0.0);
          break;
        case AxisDirection.up:
          begin = const Offset(0.0, 1.0);
          break;
        case AxisDirection.down:
          begin = const Offset(0.0, -1.0);
          break;
      }

      final slideAnimation = Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: curve));

      return FadeTransition(
        opacity: opacityAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}