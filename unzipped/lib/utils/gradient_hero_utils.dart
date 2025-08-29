import 'dart:convert';
import 'package:flutter/material.dart';

class GradientHeroUtils {
  /// Generate a deterministic gradient SVG from two colors
  static String generateGradientSvg(String colorA, String colorB) {
    // Ensure colors are hex format
    final hexA = colorA.startsWith('#') ? colorA : '#$colorA';
    final hexB = colorB.startsWith('#') ? colorB : '#$colorB';
    
    return '''
<svg width="1200" height="800" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="$hexA"/>
    <stop offset="100%" stop-color="$hexB"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>''';
  }
  
  /// Generate a data URI for the gradient SVG
  static String generateGradientDataUri(String colorA, String colorB) {
    final svgContent = generateGradientSvg(colorA, colorB);
    final encoded = base64Encode(utf8.encode(svgContent));
    return 'data:image/svg+xml;base64,$encoded';
  }
  
  /// Extract first two colors from a usage guide for gradient generation
  static List<String> extractColorsFromUsageGuide(List<dynamic> usageGuide) {
    final colors = <String>[];
    
    for (final item in usageGuide) {
      if (item is Map<String, dynamic> && item['hex'] is String) {
        final hex = item['hex'] as String;
        if (hex.isNotEmpty && _isValidHex(hex)) {
          colors.add(hex);
          if (colors.length >= 2) break;
        }
      }
    }
    
    // Fill with defaults if not enough colors
    while (colors.length < 2) {
      if (colors.isEmpty) {
        colors.add('#6366F1'); // Indigo
      } else {
        colors.add('#8B5CF6'); // Purple
      }
    }
    
    return colors;
  }
  
  /// Validate hex color format
  static bool _isValidHex(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleanHex);
  }
  
  /// Create a deterministic gradient from palette data
  static String createFallbackHero(Map<String, dynamic> storyData) {
    // Try to get colors from usage guide first
    final usageGuide = storyData['usageGuide'] as List<dynamic>? ?? [];
    final colors = extractColorsFromUsageGuide(usageGuide);
    
    return generateGradientDataUri(colors[0], colors[1]);
  }
  
  /// Widget builder for gradient fallback with loading state
  static Widget buildGradientFallback({
    required String colorA,
    required String colorB,
    double height = 280,
    BorderRadius? borderRadius,
    Widget? child,
  }) {
    final colors = [colorA, colorB].map((hex) {
      try {
        final cleanHex = hex.replaceAll('#', '');
        return Color(int.parse(cleanHex, radix: 16) + 0xFF000000);
      } catch (e) {
        return Colors.grey;
      }
    }).toList();
    
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
  
  /// Cross-fade animation widget for hero image transition
  static Widget buildCrossFadeHero({
    required String? heroImageUrl,
    required String fallbackColorA,
    required String fallbackColorB,
    double height = 280,
    BorderRadius? borderRadius,
    Duration crossFadeDuration = const Duration(milliseconds: 300),
  }) {
    final hasHeroImage = heroImageUrl != null && heroImageUrl.isNotEmpty;
    
    return AnimatedCrossFade(
      duration: crossFadeDuration,
      crossFadeState: hasHeroImage 
        ? CrossFadeState.showSecond 
        : CrossFadeState.showFirst,
      firstChild: buildGradientFallback(
        colorA: fallbackColorA,
        colorB: fallbackColorB,
        height: height,
        borderRadius: borderRadius,
        child: Center(
          child: Icon(
            Icons.palette,
            color: Colors.white.withOpacity(0.6),
            size: 48,
          ),
        ),
      ),
      secondChild: hasHeroImage
        ? ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.network(
              heroImageUrl!,
              fit: BoxFit.cover,
              height: height,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return buildGradientFallback(
                  colorA: fallbackColorA,
                  colorB: fallbackColorB,
                  height: height,
                  borderRadius: borderRadius,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return buildGradientFallback(
                  colorA: fallbackColorA,
                  colorB: fallbackColorB,
                  height: height,
                  borderRadius: borderRadius,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white.withOpacity(0.6),
                      size: 48,
                    ),
                  ),
                );
              },
            ),
          )
        : buildGradientFallback(
            colorA: fallbackColorA,
            colorB: fallbackColorB,
            height: height,
            borderRadius: borderRadius,
          ),
    );
  }
}