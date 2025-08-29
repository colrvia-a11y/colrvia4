import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/utils/color_utils.dart';

class RefineSheet extends StatelessWidget {
  final Paint paint;
  final List<Paint> availablePaints;
  final Function(Paint) onPaintSelected;

  const RefineSheet({
    super.key,
    required this.paint,
    required this.availablePaints,
    required this.onPaintSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current paint display
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity( 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      paint.brandName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    paint.code,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    paint.name,
                    style: TextStyle(
                      color: textColor.withOpacity( 0.8),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Undertone tags
          _buildUndertoneTags(),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Text(
            'Refine Options',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          
          _buildActionButton(
            context,
            'Nudge Lighter',
            Icons.brightness_high,
            () => _nudgeLighter(context),
          ),
          
          _buildActionButton(
            context,
            'Nudge Darker',
            Icons.brightness_low,
            () => _nudgeDarker(context),
          ),
          
          _buildActionButton(
            context,
            'Swap Brand',
            Icons.swap_horiz,
            () => _swapBrand(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUndertoneTags() {
    final tags = ColorUtils.undertoneTags(paint.lab);
    if (tags.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Undertones',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: tags.map((tag) => Chip(
            label: Text(
              tag,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.grey[200],
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  void _nudgeLighter(BuildContext context) {
    final lighter = PaletteGenerator.nudgeLighter(paint, availablePaints);
    if (lighter != null) {
      onPaintSelected(lighter);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lighter paint found in this brand')),
      );
    }
  }

  void _nudgeDarker(BuildContext context) {
    final darker = PaletteGenerator.nudgeDarker(paint, availablePaints);
    if (darker != null) {
      onPaintSelected(darker);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No darker paint found in this brand')),
      );
    }
  }

  void _swapBrand(BuildContext context) {
    final swapped = PaletteGenerator.swapBrand(paint, availablePaints);
    if (swapped != null) {
      onPaintSelected(swapped);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No similar paint found in other brands')),
      );
    }
  }
}