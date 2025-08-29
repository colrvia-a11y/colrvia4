import 'package:flutter/material.dart';
import '../models/color_story.dart';
import '../utils/color_utils.dart';

enum ContrastLevel { fail, aa, aaa }

class ContrastEvaluation {
  final String pairDescription;
  final Color color1;
  final Color color2;
  final double ratio;
  final ContrastLevel level;
  final String role1;
  final String role2;

  ContrastEvaluation({
    required this.pairDescription,
    required this.color1,
    required this.color2,
    required this.ratio,
    required this.level,
    required this.role1,
    required this.role2,
  });
}

class ContrastSuggestion {
  final String currentRole;
  final String suggestedRole;
  final Color currentColor;
  final Color suggestedColor;
  final double improvedRatio;
  final ContrastLevel improvedLevel;

  ContrastSuggestion({
    required this.currentRole,
    required this.suggestedRole,
    required this.currentColor,
    required this.suggestedColor,
    required this.improvedRatio,
    required this.improvedLevel,
  });
}

class ContrastCoachingService {
  static ContrastLevel _evaluateContrast(double ratio) {
    if (ratio >= 7.0) return ContrastLevel.aaa;
    if (ratio >= 4.5) return ContrastLevel.aa;
    return ContrastLevel.fail;
  }

  static List<ContrastEvaluation> evaluateKeyPairings(ColorStory story) {
    final evaluations = <ContrastEvaluation>[];
    final roleColors = <String, Color>{};

    // Build role-to-color mapping from usage guide
    for (final usageItem in story.usageGuide) {
      roleColors[usageItem.role] = ColorUtils.hexToColor(usageItem.hex);
    }

    // Define key pairings to evaluate
    final keyPairings = [
      {'role1': 'trim', 'role2': 'walls', 'description': 'Trim vs Walls'},
      {'role1': 'door', 'role2': 'walls', 'description': 'Door vs Walls'},
      {'role1': 'cabinets', 'role2': 'walls', 'description': 'Cabinets vs Walls'},
      {'role1': 'accent', 'role2': 'walls', 'description': 'Accent vs Walls'},
    ];

    for (final pairing in keyPairings) {
      final role1 = pairing['role1']!;
      final role2 = pairing['role2']!;
      final description = pairing['description']!;

      if (roleColors.containsKey(role1) && roleColors.containsKey(role2)) {
        final color1 = roleColors[role1]!;
        final color2 = roleColors[role2]!;
        final ratio = contrastRatio(color1, color2);
        final level = _evaluateContrast(ratio);

        evaluations.add(ContrastEvaluation(
          pairDescription: description,
          color1: color1,
          color2: color2,
          ratio: ratio,
          level: level,
          role1: role1,
          role2: role2,
        ));
      }
    }

    return evaluations;
  }

  static List<ContrastSuggestion> suggestImprovements(
    ContrastEvaluation evaluation,
    ColorStory story,
  ) {
    final suggestions = <ContrastSuggestion>[];
    final roleColors = <String, Color>{};
    
    // Build role-to-color mapping from usage guide
    for (final usageItem in story.usageGuide) {
      roleColors[usageItem.role] = ColorUtils.hexToColor(usageItem.hex);
    }

    // Try swapping each role with available colors
    final availableRoles = roleColors.keys.toList();
    
    for (final availableRole in availableRoles) {
      if (availableRole == evaluation.role1 || availableRole == evaluation.role2) continue;
      
      final availableColor = roleColors[availableRole]!;
      
      // Try replacing role1 with available color
      final ratio1 = contrastRatio(availableColor, evaluation.color2);
      final level1 = _evaluateContrast(ratio1);
      
      if (level1.index > evaluation.level.index) {
        suggestions.add(ContrastSuggestion(
          currentRole: evaluation.role1,
          suggestedRole: availableRole,
          currentColor: evaluation.color1,
          suggestedColor: availableColor,
          improvedRatio: ratio1,
          improvedLevel: level1,
        ));
      }
      
      // Try replacing role2 with available color
      final ratio2 = contrastRatio(evaluation.color1, availableColor);
      final level2 = _evaluateContrast(ratio2);
      
      if (level2.index > evaluation.level.index) {
        suggestions.add(ContrastSuggestion(
          currentRole: evaluation.role2,
          suggestedRole: availableRole,
          currentColor: evaluation.color2,
          suggestedColor: availableColor,
          improvedRatio: ratio2,
          improvedLevel: level2,
        ));
      }
    }

    // Sort by improvement level (best improvements first)
    suggestions.sort((a, b) => b.improvedLevel.index.compareTo(a.improvedLevel.index));
    
    return suggestions.take(3).toList(); // Return top 3 suggestions
  }
}