import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/color_story.dart';
import '../services/firebase_service.dart';
import '../services/project_service.dart';
import '../services/analytics_service.dart';

class VisualizerScreen extends StatefulWidget {
  final String? projectId;
  final String? storyId;
  final String? assignmentsParam; // URL-safe JSON string
  final Map<String, String>? initialAssignments;
  final List<ColorUsageItem>? initialGuide;
  
  const VisualizerScreen({
    super.key, 
    this.projectId,
    this.storyId,
    this.assignmentsParam,
    this.initialAssignments, 
    this.initialGuide,
  });
  
  @override State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> {
  late Map<String, String> assignments;
  String currentLighting = 'Daylight';
  final List<String> lightingOptions = ['Daylight', 'Warm LED', 'Evening'];
  String _source = '';
  ColorStory? _loadedStory;
  bool _isLoading = false;
  List<String> _missingRoles = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAssignments();
    
    // Track visualizer screen view
    AnalyticsService.instance.screenView('visualizer');
    
    // Track funnel analytics if opened with projectId
    if (widget.projectId != null) {
      AnalyticsService.instance.logVisualizerOpenedFromStory(widget.projectId!);
    }
  }
  
  Future<void> _initializeAssignments() async {
    setState(() => _isLoading = true);
    
    try {
      // Parse assignments from URL parameter if provided
      if (widget.assignmentsParam != null && widget.assignmentsParam!.isNotEmpty) {
        try {
          final decoded = jsonDecode(Uri.decodeComponent(widget.assignmentsParam!)) as Map<String, dynamic>;
          assignments = decoded.cast<String, String>();
          _source = 'story:${widget.storyId ?? 'unknown'}';
        } catch (e) {
          debugPrint('Error parsing assignments parameter: $e');
          assignments = {...?widget.initialAssignments};
        }
      } else {
        assignments = {...?widget.initialAssignments};
      }
      
      // Load story data if storyId provided but no direct assignments
      if (widget.storyId != null && assignments.isEmpty) {
        try {
          _loadedStory = await FirebaseService.getColorStory(widget.storyId!);
          if (_loadedStory != null) {
            _deriveAssignmentsFromStory(_loadedStory!);
            _source = 'story:${widget.storyId!}';
          }
        } catch (e) {
          debugPrint('Error loading story: $e');
        }
      }
      
      // Apply usage guide if available
      _applyUsageGuideToScene();
      
      // Set default assignments if still empty
      if (assignments.isEmpty) {
        assignments = {
          'walls': '#F8F8FF',
          'trim': '#FFFFFF', 
          'ceiling': '#FFFFFF',
          'backWall': '#F8F8FF',
          'door': '#FFFFFF',
          'floor': '#F5F5DC',
        };
      }
      
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _deriveAssignmentsFromStory(ColorStory story) {
    final Map<String, String> roleColors = {};
    final List<String> missingRoles = [];
    
    for (final item in story.usageGuide) {
      if (item.hex.isNotEmpty) {
        roleColors[item.role.toLowerCase()] = item.hex;
      }
    }
    
    // Map roles to surfaces with fallbacks
    final Map<String, List<String>> surfaceMappings = {
      'walls': ['main', 'primary', 'wall'],
      'trim': ['trim', 'door', 'window'],
      'ceiling': ['ceiling'],
      'backWall': ['accent', 'feature', 'feature_wall'],
      'door': ['door', 'trim'],
      'floor': ['floor'],
    };
    
    assignments = {};
    
    for (final entry in surfaceMappings.entries) {
      final surface = entry.key;
      final possibleRoles = entry.value;
      
      String? assignedColor;
      for (final role in possibleRoles) {
        if (roleColors.containsKey(role)) {
          assignedColor = roleColors[role];
          break;
        }
      }
      
      if (assignedColor != null) {
        assignments[surface] = assignedColor;
      } else {
        // Use defaults and track missing
        final defaults = {
          'walls': '#F8F8FF',
          'trim': '#FFFFFF',
          'ceiling': '#FFFFFF', 
          'backWall': '#F8F8FF',
          'door': '#FFFFFF',
          'floor': '#F5F5DC',
        };
        assignments[surface] = defaults[surface]!;
        missingRoles.addAll(possibleRoles.where((r) => !roleColors.containsKey(r)));
      }
    }
    
    _missingRoles = missingRoles.toSet().toList(); // Remove duplicates
  }

  void _applyUsageGuideToScene() {
    if (widget.initialGuide != null) {
      for (final item in widget.initialGuide!) {
        final surface = _mapRoleToSurface(item.role);
        if (surface != null && item.hex.isNotEmpty) {
          assignments[surface] = item.hex;
        }
      }
    }
  }

  String? _mapRoleToSurface(String role) {
    final lowerRole = role.toLowerCase();
    if (lowerRole.contains('wall') || lowerRole.contains('accent')) return 'walls';
    if (lowerRole.contains('trim') || lowerRole.contains('door') || lowerRole.contains('window')) return 'trim';
    if (lowerRole.contains('ceiling')) return 'ceiling';
    if (lowerRole.contains('floor')) return 'floor';
    return null;
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  Color _adjustForLighting(Color color) {
    switch (currentLighting) {
      case 'Warm LED':
        return Color.fromARGB(
          color.alpha,
          (color.red * 1.1).clamp(0, 255).round(),
          (color.green * 0.95).clamp(0, 255).round(),
          (color.blue * 0.8).clamp(0, 255).round(),
        );
      case 'Evening':
        return Color.fromARGB(
          color.alpha,
          (color.red * 0.8).clamp(0, 255).round(),
          (color.green * 0.7).clamp(0, 255).round(),
          (color.blue * 0.6).clamp(0, 255).round(),
        );
      default: // Daylight
        return color;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D Room Visualizer')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading visualizer...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Room Visualizer'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.lightbulb_outline),
            onSelected: (value) => setState(() => currentLighting = value),
            itemBuilder: (context) => lightingOptions.map((option) => 
              PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(
                      option == currentLighting ? Icons.check : Icons.lightbulb_outline,
                      color: option == currentLighting ? Colors.blue : null,
                    ),
                    const SizedBox(width: 8),
                    Text(option),
                  ],
                ),
              ),
            ).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Source and lighting info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber[600]),
                    const SizedBox(width: 8),
                    Text('Lighting: $currentLighting', style: Theme.of(context).textTheme.titleSmall),
                    if (_source.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.palette, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'From Story',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                // Show warning for missing roles
                if (_missingRoles.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Some roles not set—using defaults (${_missingRoles.take(3).join(', ')}${_missingRoles.length > 3 ? '...' : ''})',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _build3DRoom(),
          ),
          _buildColorPalette(),
        ],
      ),
    );
  }

  Widget _build3DRoom() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity( 0.1), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          size: Size.infinite,
          painter: Room3DPainter(assignments, currentLighting, _adjustForLighting, _hexToColor),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    if (widget.initialGuide == null || widget.initialGuide!.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Applied Colors', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: widget.initialGuide!.map((item) => _ColorChip(
              color: _adjustForLighting(_hexToColor(item.hex)),
              label: '${item.role}\n${item.name}',
              brandName: item.brandName,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;
  final String brandName;
  
  const _ColorChip({required this.color, required this.label, required this.brandName});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.split('\n')[0], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
              Text(label.split('\n')[1], style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              Text(brandName, style: TextStyle(fontSize: 8, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}

class Room3DPainter extends CustomPainter {
  final Map<String, String> assignments;
  final String lighting;
  final Color Function(Color) adjustForLighting;
  final Color Function(String) hexToColor;
  
  Room3DPainter(this.assignments, this.lighting, this.adjustForLighting, this.hexToColor);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black.withOpacity( 0.2)
      ..strokeWidth = 1;
    
    // Room dimensions (isometric view)
    final double roomWidth = size.width * 0.6;
    final double roomHeight = size.height * 0.7;
    final double depth = roomWidth * 0.4;
    
    final double centerX = size.width * 0.5;
    final double centerY = size.height * 0.6;
    
    // Calculate room corners (isometric projection)
    final frontLeft = Offset(centerX - roomWidth * 0.5, centerY + roomHeight * 0.3);
    final frontRight = Offset(centerX + roomWidth * 0.5, centerY + roomHeight * 0.3);
    final backLeft = Offset(frontLeft.dx - depth * 0.5, frontLeft.dy - depth * 0.3);
    final backRight = Offset(frontRight.dx - depth * 0.5, frontRight.dy - depth * 0.3);
    
    final frontLeftTop = Offset(frontLeft.dx, frontLeft.dy - roomHeight);
    final frontRightTop = Offset(frontRight.dx, frontRight.dy - roomHeight);
    final backLeftTop = Offset(backLeft.dx, backLeft.dy - roomHeight);
    final backRightTop = Offset(backRight.dx, backRight.dy - roomHeight);
    
    // Draw floor
    final floorColor = adjustForLighting(hexToColor(assignments['floor'] ?? '#F5F5DC'));
    paint.color = floorColor;
    final floorPath = Path()
      ..moveTo(frontLeft.dx, frontLeft.dy)
      ..lineTo(frontRight.dx, frontRight.dy)
      ..lineTo(backRight.dx, backRight.dy)
      ..lineTo(backLeft.dx, backLeft.dy)
      ..close();
    canvas.drawPath(floorPath, paint);
    canvas.drawPath(floorPath, strokePaint);
    
    // Draw left wall
    final wallColor = adjustForLighting(hexToColor(assignments['walls'] ?? '#F8F8FF'));
    paint.color = wallColor.withOpacity( 0.9);
    final leftWallPath = Path()
      ..moveTo(frontLeft.dx, frontLeft.dy)
      ..lineTo(backLeft.dx, backLeft.dy)
      ..lineTo(backLeftTop.dx, backLeftTop.dy)
      ..lineTo(frontLeftTop.dx, frontLeftTop.dy)
      ..close();
    canvas.drawPath(leftWallPath, paint);
    canvas.drawPath(leftWallPath, strokePaint);
    
    // Draw right wall (slightly darker for depth)
    paint.color = wallColor.withOpacity( 0.8);
    final rightWallPath = Path()
      ..moveTo(frontRight.dx, frontRight.dy)
      ..lineTo(frontRightTop.dx, frontRightTop.dy)
      ..lineTo(backRightTop.dx, backRightTop.dy)
      ..lineTo(backRight.dx, backRight.dy)
      ..close();
    canvas.drawPath(rightWallPath, paint);
    canvas.drawPath(rightWallPath, strokePaint);
    
    // Draw ceiling
    final ceilingColor = adjustForLighting(hexToColor(assignments['ceiling'] ?? '#FFFFFF'));
    paint.color = ceilingColor.withOpacity( 0.7);
    final ceilingPath = Path()
      ..moveTo(frontLeftTop.dx, frontLeftTop.dy)
      ..lineTo(frontRightTop.dx, frontRightTop.dy)
      ..lineTo(backRightTop.dx, backRightTop.dy)
      ..lineTo(backLeftTop.dx, backLeftTop.dy)
      ..close();
    canvas.drawPath(ceilingPath, paint);
    canvas.drawPath(ceilingPath, strokePaint);
    
    // Draw trim/baseboards
    final trimColor = adjustForLighting(hexToColor(assignments['trim'] ?? '#FFFFFF'));
    paint.color = trimColor;
    paint.strokeWidth = 3;
    paint.style = PaintingStyle.stroke;
    
    // Baseboard on left wall
    canvas.drawLine(frontLeft, backLeft, paint);
    // Baseboard on right wall  
    canvas.drawLine(frontRight, backRight, paint);
    // Baseboard on front
    canvas.drawLine(frontLeft, frontRight, paint);
    
    // Add some furniture for context
    _drawFurniture(canvas, size, centerX, centerY, roomWidth, roomHeight, depth);
  }
  
  void _drawFurniture(Canvas canvas, Size size, double centerX, double centerY, 
                     double roomWidth, double roomHeight, double depth) {
    final paint = Paint();
    
    // Simple sofa
    paint.color = Colors.grey[700]!;
    final sofaRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX - roomWidth * 0.2, centerY + roomHeight * 0.1),
        width: roomWidth * 0.3,
        height: 20,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(sofaRect, paint);
    
    // Coffee table
    paint.color = Colors.brown[300]!;
    final tableRect = Rect.fromCenter(
      center: Offset(centerX, centerY + roomHeight * 0.2),
      width: roomWidth * 0.15,
      height: 12,
    );
    canvas.drawRect(tableRect, paint);
  }
  
  @override
  bool shouldRepaint(Room3DPainter oldDelegate) {
    return oldDelegate.assignments != assignments || 
           oldDelegate.lighting != lighting;
  }
}