import 'dart:math';
import 'package:flutter/material.dart';
import '../firestore/firestore_data_schema.dart' show Paint;

// Core color utility functions
double _lin(double c) => c <= 0.04045 ? c/12.92 : pow((c + 0.055)/1.055, 2.4).toDouble();

double luminance(Color c){
  final r=_lin(c.red/255), g=_lin(c.green/255), b=_lin(c.blue/255);
  return 0.2126*r + 0.7152*g + 0.0722*b;
}

double contrastRatio(Color a, Color b){
  final L1 = luminance(a), L2 = luminance(b);
  final hi = max(L1, L2), lo = min(L1, L2);
  return (hi + 0.05) / (lo + 0.05);
}

Color bestTextOn(Color bg) => contrastRatio(bg, Colors.black) >= 4.5 ? Colors.black : Colors.white;

// Approximate simulations
Color simulateProtanopia(Color c){
  final r=c.red.toDouble(), g=c.green.toDouble(), b=c.blue.toDouble();
  final nr = 0.567*r + 0.433*g;
  final ng = 0.558*r + 0.442*g;
  final nb = 0.0*r   + 0.242*g + 0.758*b;
  return Color.fromARGB(c.alpha, nr.toInt(), ng.toInt(), nb.toInt());
}

Color simulateDeuteranopia(Color c){
  final r=c.red.toDouble(), g=c.green.toDouble(), b=c.blue.toDouble();
  final nr = 0.625*r + 0.375*g;
  final ng = 0.7*r   + 0.3*g;
  final nb = 0.0*r   + 0.3*g   + 0.7*b;
  return Color.fromARGB(c.alpha, nr.toInt(), ng.toInt(), nb.toInt());
}

// Additional utility class for compatibility with existing code
class ColorUtils {
  // Hex to RGB conversion
  static List<int> hexToRgb(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    final value = int.parse(cleanHex, radix: 16);
    return [
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
  
  // RGB to LAB conversion (simplified)
  static List<double> rgbToLab(int r, int g, int b) {
    // Convert RGB to XYZ
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;
    
    // Apply gamma correction
    rNorm = (rNorm > 0.04045) ? pow((rNorm + 0.055) / 1.055, 2.4).toDouble() : rNorm / 12.92;
    gNorm = (gNorm > 0.04045) ? pow((gNorm + 0.055) / 1.055, 2.4).toDouble() : gNorm / 12.92;
    bNorm = (bNorm > 0.04045) ? pow((bNorm + 0.055) / 1.055, 2.4).toDouble() : bNorm / 12.92;
    
    // Convert to XYZ
    double x = rNorm * 0.4124564 + gNorm * 0.3575761 + bNorm * 0.1804375;
    double y = rNorm * 0.2126729 + gNorm * 0.7151522 + bNorm * 0.0721750;
    double z = rNorm * 0.0193339 + gNorm * 0.1191920 + bNorm * 0.9503041;
    
    // Normalize for D65 illuminant
    x = x / 0.95047;
    y = y / 1.00000;
    z = z / 1.08883;
    
    // Convert XYZ to LAB
    x = (x > 0.008856) ? pow(x, 1/3).toDouble() : (7.787 * x + 16/116);
    y = (y > 0.008856) ? pow(y, 1/3).toDouble() : (7.787 * y + 16/116);
    z = (z > 0.008856) ? pow(z, 1/3).toDouble() : (7.787 * z + 16/116);
    
    double l = (116 * y) - 16;
    double a = 500 * (x - y);
    double bLab = 200 * (y - z);
    
    return [l, a, bLab];
  }
  
  // Color distance calculation using Delta E
  static double deltaE(List<double> lab1, List<double> lab2) {
    final dl = lab1[0] - lab2[0];
    final da = lab1[1] - lab2[1];
    final db = lab1[2] - lab2[2];
    return sqrt(dl * dl + da * da + db * db);
  }
  
  // LRV calculation helper
  static double computeLrv(String hex) {
    final rgb = hexToRgb(hex);
    final color = Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
    return luminance(color) * 100; // Convert to percentage
  }
  
  // Convert hex to Flutter Color
  static Color hexToColor(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
  
  // Get paint color (wrapper for hexToColor)
  static Color getPaintColor(String hex) {
    return hexToColor(hex);
  }
  
  // Delta E 2000 calculation (simplified)
  static double deltaE2000(List<double> lab1, List<double> lab2) {
    // Simplified Delta E calculation - in production use proper Delta E 2000
    return deltaE(lab1, lab2);
  }
  
  // Convert LAB to LCH
  static List<double> labToLch(List<double> lab) {
    final l = lab[0];
    final a = lab[1];
    final b = lab[2];
    
    final c = sqrt(a * a + b * b);
    final h = atan2(b, a) * 180 / pi;
    
    return [l, c, h < 0 ? h + 360 : h];
  }
  
  // Analyze undertone tags from LAB values
  static List<String> undertoneTags(List<double> lab) {
    final List<String> tags = [];
    
    if (lab.length < 3) return tags;
    
    final l = lab[0]; // Lightness
    final a = lab[1]; // Green-Red axis
    final b = lab[2]; // Blue-Yellow axis
    
    // Undertone analysis based on a* and b* values
    if (a > 5) {
      tags.add('red undertone');
    } else if (a < -5) {
      tags.add('green undertone');
    }
    
    if (b > 10) {
      tags.add('yellow undertone');
    } else if (b < -10) {
      tags.add('blue undertone');
    }
    
    // Additional undertone combinations
    if (a > 2 && b > 2) {
      tags.add('warm');
    } else if (a < -2 && b < -2) {
      tags.add('cool');
    }
    
    // Neutral undertones
    if (a.abs() < 3 && b.abs() < 3) {
      tags.add('neutral');
    }
    
    return tags;
  }
  
  // Missing methods for palette generation and color processing
  static Paint? nearestByDeltaE(List<double> targetLab, List<Paint> paints) {
    if (paints.isEmpty) return null;
    
    Paint? nearest;
    double minDistance = double.infinity;
    
    for (final paint in paints) {
      final distance = deltaE(targetLab, paint.lab);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = paint;
      }
    }
    
    return nearest;
  }
  
  static Paint? nearestByDeltaEMultipleHueWindow(List<double> targetLab, List<Paint> paints, {double hueWindow = 30.0}) {
    if (paints.isEmpty) return null;
    
    final targetLch = labToLch(targetLab);
    final targetHue = targetLch[2];
    
    // Filter paints within hue window
    final filteredPaints = paints.where((paint) {
      final paintLch = labToLch(paint.lab);
      final hue = paintLch[2];
      final hueDiff = (hue - targetHue).abs();
      return hueDiff <= hueWindow || hueDiff >= (360 - hueWindow);
    }).toList();
    
    return nearestByDeltaE(targetLab, filteredPaints);
  }
  
  static Color processColor(Color color) {
    // Simple color processing - adjust brightness or saturation if needed
    return color;
  }
}

// LRV helper function for paint data
double lrvForPaint({double? paintLrv, required String hex}) {
  if (paintLrv != null) return paintLrv;
  return ColorUtils.computeLrv(hex);
}