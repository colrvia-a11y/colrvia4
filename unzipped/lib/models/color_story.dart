import 'dart:convert';

class ColorUsageItem {
  final String role, hex, name, brandName, code, surface, finishRecommendation, sheen, howToUse;
  ColorUsageItem.fromMap(Map<String, dynamic> m)
    : role = m['role'], hex = m['hex'], name = m['name'], brandName = m['brandName'],
      code = m['code'], surface = m['surface'], finishRecommendation = m['finishRecommendation'],
      sheen = m['sheen'], howToUse = m['howToUse'];
}

class ColorStory {
  final String id, ownerId, status, access, narration, heroImageUrl, audioUrl, heroPrompt;
  final String storyText; // Raw story text for fallback
  final List<String> vibeWords;
  final String room, style;
  final double progress;
  final String progressMessage;
  final Map<String, dynamic> processing;
  final List<ColorUsageItem> usageGuide;
  final String fallbackHero; // Gradient SVG data URI for instant fallback

  ColorStory.fromSnap(String id, Map<String, dynamic> d)
    : id = id,
      ownerId = d['ownerId'] ?? '',
      status = d['status'] ?? 'processing',
      access = d['access'] ?? 'private',
      narration = d['narration'] ?? d['storyText'] ?? '', // Support both field names
      storyText = d['storyText'] ?? d['narration'] ?? '', // Support both field names  
      heroImageUrl = d['heroImageUrl'] ?? '',
      audioUrl = d['audioUrl'] ?? '',
      heroPrompt = d['heroPrompt'] ?? '',
      vibeWords = List<String>.from(d['vibeWords'] ?? const []),
      room = d['room'] ?? '',
      style = d['style'] ?? '',
      progress = (d['progress'] ?? 0.0).toDouble(),
      progressMessage = d['progressMessage'] ?? '',
      processing = d['processing'] as Map<String, dynamic>? ?? {},
      usageGuide = (d['usageGuide'] as List<dynamic>? ?? const [])
        .map((m) => ColorUsageItem.fromMap(Map<String, dynamic>.from(m))).toList(),
      fallbackHero = d['fallbackHero'] ?? _generateFallbackFromUsageGuide(d);
      
  /// Generate fallback hero from usage guide colors
  static String _generateFallbackFromUsageGuide(Map<String, dynamic> data) {
    final usageGuide = data['usageGuide'] as List<dynamic>? ?? [];
    final colors = <String>[];
    
    // Extract first two valid colors from usage guide
    for (final item in usageGuide) {
      if (item is Map<String, dynamic> && item['hex'] is String) {
        final hex = item['hex'] as String;
        if (hex.isNotEmpty && _isValidHex(hex)) {
          colors.add(hex);
          if (colors.length >= 2) break;
        }
      }
    }
    
    // Use default colors if not enough found
    if (colors.isEmpty) colors.add('#6366F1');
    if (colors.length == 1) colors.add('#8B5CF6');
    
    return _generateGradientDataUri(colors[0], colors[1]);
  }
  
  /// Validate hex color format
  static bool _isValidHex(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleanHex);
  }
  
  /// Generate gradient SVG data URI
  static String _generateGradientDataUri(String colorA, String colorB) {
    final hexA = colorA.startsWith('#') ? colorA : '#$colorA';
    final hexB = colorB.startsWith('#') ? colorB : '#$colorB';
    
    final svgContent = '''<svg width="1200" height="800" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="$hexA"/>
    <stop offset="100%" stop-color="$hexB"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>''';
    
    final encoded = base64Encode(utf8.encode(svgContent));
    return 'data:image/svg+xml;base64,$encoded';
  }
}