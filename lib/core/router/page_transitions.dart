import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Refund Radar M3 motion vocabulary.
///
/// The app ships with default platform transitions (right-swipe on Android).
/// That reads as generic. Instead we use two curated patterns:
///
///  * [fadeThroughPage] — for lateral / top-level moves (shell tabs already
///    swap instantly; onboarding slides use their own PageView).
///  * [sharedAxisYPage] — for forward "compose / detail" pushes (create,
///    dispute detail, escalate, wizard, paywall). Content slides up + fades
///    in, which matches Material 3's shared-axis-Y "entering a new level"
///    metaphor and feels like a designed flow rather than a screen swap.
///
/// Durations follow M3 guidance (incoming 300ms / outgoing short). Curves are
/// `emphasized` decelerate/accelerate for a premium, snappy feel.
CustomTransitionPage<T> sharedAxisYPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

/// Fade-through for neutral lateral moves where a directional slide would
/// imply hierarchy that doesn't exist.
CustomTransitionPage<T> fadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
