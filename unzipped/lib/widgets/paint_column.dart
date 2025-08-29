import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/widgets/paint_action_sheet.dart';
import 'package:color_canvas/utils/color_utils.dart';

class PaintStripe extends StatefulWidget {
  final Paint? paint;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onRefine;
  const PaintStripe({
    super.key,
    this.paint,
    required this.isLocked,
    required this.onTap,
    this.onLongPress,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onRefine,
  });

  @override
  State<PaintStripe> createState() => _PaintStripeState();
}

class _PaintStripeState extends State<PaintStripe> {
  double _dragStartX = 0;
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final color = widget.paint != null ? ColorUtils.getPaintColor(widget.paint!.hex) : Colors.grey;

    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.paint != null
          ? () => _showActionSheet(context)
          : widget.onLongPress,
      onHorizontalDragStart: (details) {
        _dragStartX = details.localPosition.dx;
        _dragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDistance = details.localPosition.dx - _dragStartX;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        const minDistance = 24.0;
        const minVelocity = 300.0;

        // Right swipe: positive distance and velocity
        if (_dragDistance > minDistance &&
            velocity > minVelocity &&
            widget.onSwipeRight != null) {
          widget.onSwipeRight!();
        }
        // Left swipe: negative distance and velocity
        else if (_dragDistance < -minDistance &&
            velocity < -minVelocity &&
            widget.onSwipeLeft != null) {
          widget.onSwipeLeft!();
        }

        // Reset drag state
        _dragStartX = 0;
        _dragDistance = 0;
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: Colors.white.withOpacity( 0.3),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Lock indicator
            if (widget.isLocked)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity( 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // Paint information
            if (widget.paint != null)
              Positioned(
                left: widget.isLocked ? 60 : 16,
                top: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand information (roles removed)
                    Text(
                      widget.paint!.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Paint name
                    Text(
                      widget.paint!.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            else
              // Empty state
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tap to roll',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    if (widget.paint == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaintActionSheet(
        paint: widget.paint!,
        onRefine: widget.onRefine,
      ),
    );
  }

}

class AnimatedPaintStripe extends StatefulWidget {
  final Paint? paint;
  final Paint? previousPaint;
  final bool isLocked;
  final bool isRolling;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onRefine;
  const AnimatedPaintStripe({
    super.key,
    this.paint,
    this.previousPaint,
    required this.isLocked,
    required this.isRolling,
    required this.onTap,
    this.onLongPress,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onRefine,
  });

  @override
  State<AnimatedPaintStripe> createState() => _AnimatedPaintStripeState();
}

class _AnimatedPaintStripeState extends State<AnimatedPaintStripe>
    with TickerProviderStateMixin {
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  double _dragDx = 0.0;

  @override
  void initState() {
    super.initState();

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _updateColorAnimation();

    // Start animation at end state for initial load
    _colorController.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedPaintStripe oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.paint?.hex != widget.paint?.hex) {
      _updateColorAnimation();
      _animateColorChange();
    }
  }

  void _updateColorAnimation() {
    final previousColor = widget.previousPaint != null
        ? widget.previousPaint != null ? ColorUtils.getPaintColor(widget.previousPaint!.hex) : Colors.grey
        : widget.paint != null ? ColorUtils.getPaintColor(widget.paint!.hex) : Colors.grey; // Start with current color if no previous
    final currentColor = widget.paint != null ? ColorUtils.getPaintColor(widget.paint!.hex) : Colors.grey;

    _colorAnimation = ColorTween(
      begin: previousColor,
      end: currentColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOutCubic,
    ));
  }

  void _animateColorChange() {
    _colorController.reset();
    _colorController.forward();
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorController,
      builder: (context, child) {
        final color = _colorAnimation.value ?? (widget.paint != null ? ColorUtils.getPaintColor(widget.paint!.hex) : Colors.grey);
        final brightness = ThemeData.estimateBrightnessForColor(color);
        final textColor =
            brightness == Brightness.dark ? Colors.white : Colors.black;

        return GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.paint != null
              ? () => _showActionSheet(context)
              : widget.onLongPress,
          onHorizontalDragStart: (_) => _dragDx = 0.0,
          onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
          onHorizontalDragEnd: (details) {
            final v = details.velocity.pixelsPerSecond.dx;
            if ((_dragDx > 24) || (v > 500)) {
              if (widget.onSwipeRight != null) widget.onSwipeRight!();
            } else if ((_dragDx < -24) || (v < -500)) {
              if (widget.onSwipeLeft != null) widget.onSwipeLeft!();
            }
            _dragDx = 0.0;
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: Colors.white.withOpacity( 0.3),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // Lock indicator
                if (widget.isLocked)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity( 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                // Paint information
                if (widget.paint != null)
                  Positioned(
                    left: widget.isLocked ? 60 : 16,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Brand information (roles removed)
                        Text(
                          widget.paint!.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Paint name
                        Text(
                          widget.paint!.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  )
                else
                  // Empty state
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tap to roll',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
        );
      },
    );
  }

  void _showActionSheet(BuildContext context) {
    if (widget.paint == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaintActionSheet(
        paint: widget.paint!,
        onRefine: widget.onRefine,
      ),
    );
  }

}