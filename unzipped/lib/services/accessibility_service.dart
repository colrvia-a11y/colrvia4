import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to detect platform accessibility settings like reduce motion
class AccessibilityService {
  static AccessibilityService? _instance;
  static AccessibilityService get instance => _instance ??= AccessibilityService._internal();
  
  AccessibilityService._internal();
  
  /// Platform-specific method channel for accessibility detection
  static const MethodChannel _channel = MethodChannel('com.colorcanvas.accessibility');
  
  bool _reduceMotionCache = false;
  bool _hasQueriedReduceMotion = false;
  
  /// Check if reduce motion is enabled at the OS level
  Future<bool> isReduceMotionEnabled() async {
    if (_hasQueriedReduceMotion) {
      return _reduceMotionCache;
    }
    
    try {
      // Try to get the OS-level reduce motion setting
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, we can check for reduce motion
        final result = await _channel.invokeMethod<bool>('isReduceMotionEnabled');
        _reduceMotionCache = result ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, check for animation scale settings
        final result = await _channel.invokeMethod<bool>('isAnimationDisabled');
        _reduceMotionCache = result ?? false;
      } else {
        // For web and other platforms, fall back to media query
        _reduceMotionCache = await _checkWebReduceMotion();
      }
      
      _hasQueriedReduceMotion = true;
      debugPrint('🎭 Reduce motion detected: $_reduceMotionCache');
    } catch (e) {
      // If platform channel fails, assume false
      debugPrint('🎭 Failed to detect reduce motion, defaulting to false: $e');
      _reduceMotionCache = false;
      _hasQueriedReduceMotion = true;
    }
    
    return _reduceMotionCache;
  }
  
  /// Check for reduce motion on web platforms using media query
  Future<bool> _checkWebReduceMotion() async {
    if (kIsWeb) {
      try {
        // Try to use the web-specific approach to detect prefers-reduced-motion
        // This would need to be implemented with dart:html or js interop
        return false; // Default to false for now
      } catch (e) {
        return false;
      }
    }
    return false;
  }
  
  /// Clear the cache to force a fresh check next time
  void clearCache() {
    _hasQueriedReduceMotion = false;
    _reduceMotionCache = false;
  }
  
  /// Check if animations should be reduced based on both OS and user preferences
  bool shouldReduceMotion({bool? userPreference}) {
    // User preference takes precedence
    if (userPreference == true) {
      return true;
    }
    
    // Fall back to OS-level setting
    return _reduceMotionCache;
  }
}