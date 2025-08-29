import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';

/// Widget to display the AI-generated usage guide with paint application instructions
class UsageGuideWidget extends StatelessWidget {
  final List<ColorUsageGuideItem> usageGuide;
  final VoidCallback? onUseInRoller;

  const UsageGuideWidget({
    super.key,
    required this.usageGuide,
    this.onUseInRoller,
  });

  @override
  Widget build(BuildContext context) {
    if (usageGuide.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.palette, size: 20),
            const SizedBox(width: 8),
            Text(
              'How to Use These Colors',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Usage guide cards
        ...usageGuide.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < usageGuide.length - 1 ? 16 : 0),
            child: _UsageGuideCard(
              item: item,
              index: index + 1,
            ),
          );
        }),
        
        const SizedBox(height: 24),
        
        // Action button
        if (onUseInRoller != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUseInRoller,
              icon: const Icon(Icons.casino),
              label: const Text('Use This Palette in Roller'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class _UsageGuideCard extends StatelessWidget {
  final ColorUsageGuideItem item;
  final int index;

  const _UsageGuideCard({
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.hexToColor(item.hex);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Color swatch
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Color info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _RoleBadge(role: item.role),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.brandName} ${item.code}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.hex.toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Application instructions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity( 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.howToUse,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Finish recommendations
            Row(
              children: [
                _FinishChip(
                  label: item.finishRecommendation,
                  icon: _getFinishIcon(item.finishRecommendation),
                ),
                const SizedBox(width: 8),
                _FinishChip(
                  label: '${item.sheen} sheen',
                  icon: _getSheenIcon(item.sheen),
                ),
                const SizedBox(width: 8),
                _FinishChip(
                  label: item.surface,
                  icon: _getSurfaceIcon(item.surface),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getFinishIcon(String finish) {
    switch (finish.toLowerCase()) {
      case 'matte': return Icons.texture;
      case 'eggshell': return Icons.egg;
      case 'satin': return Icons.water_drop_outlined;
      case 'semi-gloss': return Icons.water_drop;
      case 'gloss': return Icons.lightbulb_outline;
      default: return Icons.brush;
    }
  }
  
  IconData _getSheenIcon(String sheen) {
    switch (sheen.toLowerCase()) {
      case 'low': return Icons.brightness_low;
      case 'medium': return Icons.brightness_medium;
      case 'high': return Icons.brightness_high;
      default: return Icons.brightness_auto;
    }
  }
  
  IconData _getSurfaceIcon(String surface) {
    switch (surface.toLowerCase()) {
      case 'wall': return Icons.crop_square;
      case 'trim': return Icons.border_outer;
      case 'ceiling': return Icons.horizontal_rule;
      case 'cabinet': return Icons.kitchen;
      case 'accent': return Icons.star_outline;
      default: return Icons.format_paint;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = _getRoleColor(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity( 0.3)),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'main wall': return Colors.blue;
      case 'accent wall': return Colors.orange;
      case 'trim': return Colors.green;
      case 'ceiling': return Colors.purple;
      case 'furniture': return Colors.brown;
      case 'accessories': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class _FinishChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FinishChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity( 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}