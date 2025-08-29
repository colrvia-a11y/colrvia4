import 'package:flutter/material.dart';

/// A parallax container that respects motion sensitivity preferences
class MotionAwareParallax extends StatelessWidget {
  final Widget child;
  final bool reduceMotion;
  final double parallaxFactor;
  final double maxOffset;

  const MotionAwareParallax({
    super.key,
    required this.child,
    required this.reduceMotion,
    this.parallaxFactor = 0.08,
    this.maxOffset = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    // If motion is reduced, just return the child without any animation
    if (reduceMotion) {
      return child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => false, // Don't consume the scroll notification
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Try to get the scroll position from the nearest scrollable
          final scrollable = Scrollable.maybeOf(context);
          
          if (scrollable == null) {
            // No scrollable found, return static child
            return child;
          }

          return AnimatedBuilder(
            animation: scrollable.position,
            builder: (context, _) {
              // Calculate the parallax offset based on scroll position
              final scrollPixels = scrollable.position.pixels;
              final offset = scrollPixels * parallaxFactor;
              
              // Clamp the offset to prevent excessive movement
              final clampedOffset = offset.clamp(-maxOffset, maxOffset);
              
              return Transform.translate(
                offset: Offset(0, clampedOffset),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

/// Enhanced version with fade effect and more control
class EnhancedMotionAwareParallax extends StatelessWidget {
  final Widget child;
  final bool reduceMotion;
  final double parallaxFactor;
  final double maxOffset;
  final bool enableFade;
  final double fadeStart;
  final double fadeEnd;

  const EnhancedMotionAwareParallax({
    super.key,
    required this.child,
    required this.reduceMotion,
    this.parallaxFactor = 0.08,
    this.maxOffset = 8.0,
    this.enableFade = false,
    this.fadeStart = 0.0,
    this.fadeEnd = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    // If motion is reduced, just return the child without any animation
    if (reduceMotion) {
      return child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollable = Scrollable.maybeOf(context);
          
          if (scrollable == null) {
            return child;
          }

          return AnimatedBuilder(
            animation: scrollable.position,
            builder: (context, _) {
              final scrollPixels = scrollable.position.pixels;
              
              // Calculate parallax offset
              final offset = scrollPixels * parallaxFactor;
              final clampedOffset = offset.clamp(-maxOffset, maxOffset);
              
              Widget transformedChild = Transform.translate(
                offset: Offset(0, clampedOffset),
                child: child,
              );
              
              // Apply fade effect if enabled
              if (enableFade) {
                double opacity = 1.0;
                if (scrollPixels >= fadeStart) {
                  final fadeRange = fadeEnd - fadeStart;
                  final fadeProgress = (scrollPixels - fadeStart) / fadeRange;
                  opacity = (1.0 - fadeProgress.clamp(0.0, 1.0));
                }
                
                transformedChild = Opacity(
                  opacity: opacity,
                  child: transformedChild,
                );
              }
              
              return transformedChild;
            },
          );
        },
      ),
    );
  }
}