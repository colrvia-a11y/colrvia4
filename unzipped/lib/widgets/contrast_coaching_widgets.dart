import 'package:flutter/material.dart';
import '../services/contrast_coaching_service.dart';
import '../models/color_story.dart';

class ContrastStatusChip extends StatelessWidget {
  final ContrastLevel level;
  final double ratio;

  const ContrastStatusChip({
    super.key,
    required this.level,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color chipColor;
    String label;
    IconData icon;
    
    switch (level) {
      case ContrastLevel.aaa:
        chipColor = Colors.green;
        label = 'AAA';
        icon = Icons.check_circle;
        break;
      case ContrastLevel.aa:
        chipColor = Colors.orange;
        label = 'AA';
        icon = Icons.check;
        break;
      case ContrastLevel.fail:
        chipColor = Colors.red;
        label = 'Fail';
        icon = Icons.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${ratio.toStringAsFixed(1)}:1',
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class ContrastEvaluationCard extends StatelessWidget {
  final ContrastEvaluation evaluation;
  final VoidCallback? onTapSuggestions;

  const ContrastEvaluationCard({
    super.key,
    required this.evaluation,
    this.onTapSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Color swatches
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: evaluation.color1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.compare_arrows, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: evaluation.color2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    evaluation.pairDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ContrastStatusChip(
                  level: evaluation.level,
                  ratio: evaluation.ratio,
                ),
              ],
            ),
            if (evaluation.level == ContrastLevel.fail && onTapSuggestions != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTapSuggestions,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('View Suggestions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ContrastSuggestionCard extends StatelessWidget {
  final ContrastSuggestion suggestion;
  final VoidCallback onApply;

  const ContrastSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Swap ${suggestion.currentRole} → ${suggestion.suggestedRole}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                ContrastStatusChip(
                  level: suggestion.improvedLevel,
                  ratio: suggestion.improvedRatio,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Current color
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: suggestion.currentColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                // Suggested color
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: suggestion.suggestedColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContrastCoachingSection extends StatefulWidget {
  final ColorStory story;
  final Function(String fromRole, String toRole) onApplySwap;

  const ContrastCoachingSection({
    super.key,
    required this.story,
    required this.onApplySwap,
  });

  @override
  State<ContrastCoachingSection> createState() => _ContrastCoachingSectionState();
}

class _ContrastCoachingSectionState extends State<ContrastCoachingSection> {
  ContrastEvaluation? _selectedEvaluation;
  List<ContrastSuggestion>? _suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final evaluations = ContrastCoachingService.evaluateKeyPairings(widget.story);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.accessibility_new, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Contrast Coaching',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'WCAG accessibility compliance for key color pairings',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        
        if (evaluations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('No key pairings found to evaluate. Try assigning colors to trim, doors, or accent roles.'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Evaluations list
          for (final evaluation in evaluations)
            ContrastEvaluationCard(
              evaluation: evaluation,
              onTapSuggestions: evaluation.level == ContrastLevel.fail ? () {
                setState(() {
                  _selectedEvaluation = evaluation;
                  _suggestions = ContrastCoachingService.suggestImprovements(evaluation, widget.story);
                });
              } : null,
            ),
          
          // Suggestions section
          if (_selectedEvaluation != null && _suggestions != null) ...[
            const SizedBox(height: 16),
            Text(
              'Suggestions for ${_selectedEvaluation!.pairDescription}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_suggestions!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('No suitable swaps found with current palette. Consider adding more contrasting colors.'),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final suggestion in _suggestions!)
                ContrastSuggestionCard(
                  suggestion: suggestion,
                  onApply: () {
                    widget.onApplySwap(suggestion.currentRole, suggestion.suggestedRole);
                    setState(() {
                      _selectedEvaluation = null;
                      _suggestions = null;
                    });
                  },
                ),
            
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedEvaluation = null;
                  _suggestions = null;
                });
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Close Suggestions'),
            ),
          ],
        ],
      ],
    );
  }
}