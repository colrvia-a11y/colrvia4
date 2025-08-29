import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/screens/explore_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/screens/library_screen.dart';
import 'package:color_canvas/screens/color_story_wizard_screen.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/widgets/paint_action_sheet.dart';

class PaletteDetailScreen extends StatefulWidget {
  final UserPalette palette;

  const PaletteDetailScreen({super.key, required this.palette});

  @override
  State<PaletteDetailScreen> createState() => _PaletteDetailScreenState();
}

class _PaletteDetailScreenState extends State<PaletteDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.palette.name);
    _notesController = TextEditingController(text: widget.palette.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }


  Future<void> _updatePalette() async {
    try {
      final updatedPalette = UserPalette(
        id: widget.palette.id,
        userId: widget.palette.userId,
        name: _nameController.text.trim(),
        colors: widget.palette.colors,
        tags: widget.palette.tags,
        notes: _notesController.text.trim(),
        createdAt: widget.palette.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await FirebaseService.updatePalette(updatedPalette);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Palette updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating palette: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    final text = widget.palette.colors.map((color) => '${color.name} (${color.code}) - ${color.hex}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Palette copied to clipboard')),
    );
  }

  Future<void> _exportCSV() async {
    final csv = 'Brand,Code,Name,Hex\n${widget.palette.colors.map((color) => '${color.brand ?? 'Unknown'},${color.code},"${color.name}",${color.hex}').join('\n')}';
    
    await Share.share(csv, subject: '${widget.palette.name} - Paint Colors');
  }

  Future<void> _shareLink() async {
    final hexCodes = widget.palette.colors.map((color) => color.hex.substring(1)).join('-');
    final shareUrl = 'https://colorcanvas.app/palette/${widget.palette.id}?colors=$hexCodes';
    final shareText = '${widget.palette.name}\n\n${widget.palette.colors.map((color) => '${color.name} (${color.code})').join('\n')}\n\nView this palette: $shareUrl';
    
    await Share.share(shareText, subject: '${widget.palette.name} - Color Palette');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palette Details'),
        actions: [
          PopupMenuButton(
            onSelected: (value) async {
              switch (value) {
                case 'copy':
                  _copyToClipboard();
                  break;
                case 'csv':
                  _exportCSV();
                  break;
                case 'share':
                  _shareLink();
                  break;
                case 'roller':
                  final ids = widget.palette.colors.map((c) => c.paintId).toList();
                  if (!mounted) return;
                  _openInRoller(ids);
                  break;
                case 'delete':
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Palette'),
                      content: Text('Are you sure you want to delete "${widget.palette.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true) {
                    try {
                      await FirebaseService.deletePalette(widget.palette.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Palette deleted'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting palette: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 16),
                    SizedBox(width: 8),
                    Text('Copy to clipboard'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 16),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 16),
                    SizedBox(width: 8),
                    Text('Share link'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'roller',
                child: Row(
                  children: [Icon(Icons.casino, size: 16), SizedBox(width: 8), Text('Open in Roller')],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final ids = widget.palette.colors.map((c) => c.paintId).toList();
          _openInRoller(ids);
        },
        icon: const Icon(Icons.casino),
        label: const Text('Open in Roller'),
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color preview
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: widget.palette.colors.map((paletteColor) {
                        final color = ColorUtils.hexToColor(paletteColor.hex);
                        final index = widget.palette.colors.indexOf(paletteColor);
                        
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: index == 0
                                  ? const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    )
                                  : index == widget.palette.colors.length - 1
                                      ? const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        )
                                      : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Create Color Story button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ColorStoryWizardScreen(
                              paletteId: widget.palette.id,
                            ),
                          ),
                        );
                        
                        // Track analytics
                        AnalyticsService.instance.logEvent('palette_detail_create_story', {
                          'palette_id': widget.palette.id,
                          'color_count': widget.palette.colors.length,
                        });
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Create Color Story'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Name field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Palette Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _updatePalette(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes field
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (_) => _updatePalette(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Paint details
                  Text(
                    'Colors',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  ...(widget.palette.colors.map((paletteColor) => 
                    PaintDetailCard.fromPaletteColor(
                      paletteColor, 
                      onOpenInRoller: (paint) {
                        _openInRollerSingleColor([paint]);
                      }
                    )).toList()),
                  
                  const SizedBox(height: 24),
                  
                  // Metadata
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Palette Info',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Created', _formatDate(widget.palette.createdAt)),
                          _buildInfoRow('Updated', _formatDate(widget.palette.updatedAt)),
                          _buildInfoRow('Colors', '${widget.palette.colors.length}'),
                          if (widget.palette.tags.isNotEmpty)
                            _buildInfoRow('Tags', widget.palette.tags.join(', ')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Navigate to roller with palette colors while preserving bottom navigation
  void _openInRoller(List<String> paintIds) {
    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/' || route.isFirst;
    });
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _RollerWithInitialColorsWrapper(initialPaintIds: paintIds),
      ),
    );
  }

  /// Navigate to roller with single paint while preserving bottom navigation
  void _openInRollerSingleColor(List<Paint> paints) {
    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/' || route.isFirst;
    });
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _RollerWithInitialColorsWrapper(initialPaints: paints),
      ),
    );
  }
}

class PaintDetailCard extends StatelessWidget {
  final Paint? paint;
  final PaletteColor? paletteColor;
  final Function(Paint)? onOpenInRoller;

  const PaintDetailCard({super.key, required this.paint, this.onOpenInRoller}) : paletteColor = null;
  
  const PaintDetailCard.fromPaletteColor(this.paletteColor, {super.key, this.onOpenInRoller}) : paint = null;

  @override
  Widget build(BuildContext context) {
    // Get data from either Paint or PaletteColor
    final String name = paint?.name ?? paletteColor?.name ?? 'Unknown';
    final String brandName = paint?.brandName ?? paletteColor?.brand ?? 'Unknown';
    final String code = paint?.code ?? paletteColor?.code ?? '';
    final String hex = paint?.hex ?? paletteColor?.hex ?? '#000000';
    
    final color = paint != null 
        ? ColorUtils.getPaintColor(paint!.hex) 
        : ColorUtils.hexToColor(hex);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          // Get the Paint object
          final paintId = paint?.id ?? paletteColor?.paintId;
          if (paintId == null) return;

          final p = paint ?? await FirebaseService.getPaintById(paintId);
          if (p == null) return;

          if (!context.mounted) return;
          showModalBottomSheet(
            context: context,
            builder: (ctx) => PaintActionSheet(
              paint: p,
              primaryActionLabel: 'Open in Roller',  // NEW
              onRefine: onOpenInRoller != null ? () {
                Navigator.of(ctx).pop(); // Close the modal first
                onOpenInRoller!(p);
              } : null,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Color swatch
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Text(
                    hex.substring(1, 4).toUpperCase(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Paint info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$brandName • $code',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hex.toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Copy icon
              const Icon(Icons.copy, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper to handle opening roller with initial colors while preserving bottom navigation
class _RollerWithInitialColorsWrapper extends StatefulWidget {
  final List<String>? initialPaintIds;
  final List<Paint>? initialPaints;

  const _RollerWithInitialColorsWrapper({
    this.initialPaintIds,
    this.initialPaints,
  });

  @override
  State<_RollerWithInitialColorsWrapper> createState() => _RollerWithInitialColorsWrapperState();
}

class _RollerWithInitialColorsWrapperState extends State<_RollerWithInitialColorsWrapper> {
  @override
  void initState() {
    super.initState();
    // Navigate to home screen immediately after this widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _HomeScreenWithRollerInitialColors(
            initialPaintIds: widget.initialPaintIds,
            initialPaints: widget.initialPaints,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Modified HomeScreen that starts with roller tab and initial colors
class _HomeScreenWithRollerInitialColors extends StatefulWidget {
  final List<String>? initialPaintIds;
  final List<Paint>? initialPaints;

  const _HomeScreenWithRollerInitialColors({
    this.initialPaintIds,
    this.initialPaints,
  });

  @override
  State<_HomeScreenWithRollerInitialColors> createState() => _HomeScreenWithRollerInitialColorsState();
}

class _HomeScreenWithRollerInitialColorsState extends State<_HomeScreenWithRollerInitialColors> {
  int _currentIndex = 0; // Start with roller tab
  late final GlobalKey<RollerScreenStatePublic> _rollerKey = GlobalKey<RollerScreenStatePublic>();
  
  late final List<Widget> _screens = [
    RollerScreen(
      key: _rollerKey, 
      initialPaintIds: widget.initialPaintIds,
      initialPaints: widget.initialPaints,
    ),
    const LibraryScreen(),
    const SearchScreen(),
    const ExploreScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Show success message after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.initialPaints != null 
            ? 'Opened color in Roller!'
            : 'Opened palette in Roller!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity( 0.6),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.palette),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}