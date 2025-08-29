import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/models/project.dart';
import 'package:color_canvas/screens/palette_detail_screen.dart';
import 'package:color_canvas/screens/login_screen.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/screens/explore_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/screens/color_story_detail_screen.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/main.dart' show isFirebaseInitialized;

class LibraryScreen extends StatefulWidget {
  final bool showSavedTitle;
  
  const LibraryScreen({super.key, this.showSavedTitle = false});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<UserPalette> _palettes = [];
  List<Paint> _savedColors = [];
  List<ProjectDoc> _colorStories = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Palettes', 'Stories'
  bool _hasPermissionError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Check Firebase initialization first
    if (!isFirebaseInitialized) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firebase not configured. Items may not sync across devices.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    final user = FirebaseService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Debug: Check Firebase status and auth state
      final firebaseStatus = await FirebaseService.getFirebaseStatus();
      print('Firebase Status in library: $firebaseStatus');
      print('User ID: ${user.uid}, Email: ${user.email}');
      
      // Try to load data with individual error handling
      List<UserPalette> palettes = [];
      List<Paint> savedColors = [];
      List<ProjectDoc> colorStories = [];
      
      try {
        palettes = await FirebaseService.getUserPalettes(user.uid);
        print('Successfully loaded ${palettes.length} palettes');
      } catch (paletteError) {
        print('Error loading palettes: $paletteError');
        if (paletteError.toString().contains('permission-denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. Please check your account permissions.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      
      try {
        savedColors = await FirebaseService.getUserFavoriteColors(user.uid);
        print('Successfully loaded ${savedColors.length} favorite colors');
      } catch (colorsError) {
        print('Error loading favorite colors: $colorsError');
        if (colorsError.toString().contains('permission-denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied for saved colors. Please try signing out and back in.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      
      try {
        // Load color stories (projects with colorStoryId)
        final allProjects = await ProjectService.myProjectsStream(limit: 50).first;
        colorStories = allProjects.where((p) => p.colorStoryId != null).toList();
        print('Successfully loaded ${colorStories.length} color stories');
      } catch (storiesError) {
        print('Error loading color stories: $storiesError');
      }
      
      setState(() {
        _palettes = palettes;
        _savedColors = savedColors;
        _colorStories = colorStories;
        _isLoading = false;
        _hasPermissionError = palettes.isEmpty && savedColors.isEmpty && colorStories.isEmpty;
      });
      
    } catch (e) {
      print('General error loading library data: $e');
      setState(() => _isLoading = false);
      
      if (e.toString().contains('permission-denied')) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading data: ${e.toString().split(':').first}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget get _currentView {
    switch (_selectedFilter) {
      case 'Palettes':
        return _buildPalettesView();
      case 'Stories':
        return _buildStoriesView();
      default: // 'All'
        return _buildAllView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.showSavedTitle ? 'Saved' : 'My Library')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please sign in to view your palettes'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showSavedTitle ? 'Saved' : 'My Library'),
        actions: [
          if (_hasPermissionError)
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Some data may not be available due to permission issues. Try signing out and back in.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
              tooltip: 'Permission Issues',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Palettes'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Stories'),
                    ],
                  ),
                ),
                // Content
                Expanded(child: _currentView),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = label),
      label: Text(label),
      backgroundColor: isSelected ? null : Colors.grey[100],
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildAllView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_colorStories.isNotEmpty) ...[
            _buildSectionHeader('Color Stories', _colorStories.length),
            _buildStoriesList(),
            const SizedBox(height: 16),
          ],
          if (_palettes.isNotEmpty) ...[
            _buildSectionHeader('Palettes', _palettes.length),
            _buildPalettesGrid(),
            const SizedBox(height: 16),
          ],
          if (_savedColors.isNotEmpty) ...[
            _buildSectionHeader('Saved Colors', _savedColors.length),
            _buildColorsGrid(),
          ],
          if (_colorStories.isEmpty && _palettes.isEmpty && _savedColors.isEmpty)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildPalettesView() {
    if (_palettes.isEmpty) {
      return _buildEmptyPalettes();
    }
    return _buildPalettesGrid();
  }

  Widget _buildStoriesView() {
    if (_colorStories.isEmpty) {
      return _buildEmptyStories();
    }
    return _buildStoriesList();
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStoriesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _colorStories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final story = _colorStories[index];
        return _buildStoryCard(story);
      },
    );
  }

  Widget _buildStoryCard(ProjectDoc story) {
    final statusMap = {
      FunnelStage.build: {'label': 'Building', 'color': Colors.orange},
      FunnelStage.story: {'label': 'Story Ready', 'color': Colors.blue},
      FunnelStage.visualize: {'label': 'Visualized', 'color': Colors.green},
      FunnelStage.share: {'label': 'Shared', 'color': Colors.purple},
    };
    
    final status = statusMap[story.funnelStage] ?? statusMap[FunnelStage.build]!;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      title: Text(
        story.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (status['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (status['color'] as Color).withOpacity(0.3)),
            ),
            child: Text(
              status['label'] as String,
              style: TextStyle(
                color: status['color'] as Color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (story.vibeWords.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              story.vibeWords.join(', '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (story.colorStoryId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ColorStoryDetailScreen(storyId: story.colorStoryId!),
            ),
          );
        }
      },
    );
  }

  Widget _buildEmptyStories() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Color Stories yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create palettes and turn them into stories to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPalettes() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No palettes yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Save color combinations from the Roller to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPalettesGrid() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _palettes.length,
        itemBuilder: (context, index) {
          final palette = _palettes[index];
          return EnhancedPaletteCard(
            palette: palette,
            onTap: () => _openPaletteDetail(palette),
            onDelete: () => _deletePalette(palette),
            onEdit: () => _editPaletteTags(palette),
            onOpenInRoller: () => _openPaletteInRoller(palette),
          );
        },
      ),
    );
  }

  Widget _buildColorsGrid() {
    final user = FirebaseService.currentUser;
    if (user == null) {
      // Guest state: prompt sign-in
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Sign in to save colors'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen())
              ).then((_) => _loadData()),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }
    
    // Use the static data for now instead of streaming to avoid permission issues
    return _savedColors.isEmpty
        ? _buildEmptyColorsState()
        : RefreshIndicator(
            onRefresh: _loadData,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _savedColors.length,
              itemBuilder: (context, index) {
                final paint = _savedColors[index];
                return SavedColorCard(
                  paint: paint,
                  onTap: () => _showColorDetails(paint),
                  onRemove: () => _removeSavedColor(paint),
                );
              },
            ),
          );
  }

  Widget _buildEmptyColorsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.color_lens_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No saved colors yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the heart icon on any paint to save it here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _editPaletteTags(UserPalette palette) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => EditTagsDialog(
        initialTags: palette.tags,
        availableTags: _getAllTags(),
      ),
    );
    
    if (result != null) {
      try {
        final updatedPalette = palette.copyWith(
          tags: result,
          updatedAt: DateTime.now(),
        );
        await FirebaseService.updatePalette(updatedPalette);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating tags: $e')),
          );
        }
      }
    }
  }

  List<String> _getAllTags() {
    final allTags = <String>{};
    for (final palette in _palettes) {
      allTags.addAll(palette.tags);
    }
    return allTags.toList()..sort();
  }

  void _showColorDetails(Paint paint) {
    showDialog(
      context: context,
      builder: (context) => ColorDetailDialog(paint: paint),
    );
  }

  Future<void> _removeSavedColor(Paint paint) async {
    try {
      await FirebaseService.removeFavoritePaint(paint.id);
      // Stream will automatically update the UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Color removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing color: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    final user = FirebaseService.currentUser;
    
    if (user == null) {
      // User not signed in
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to save palettes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create an account to save your favorite color palettes and access them from any device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ).then((_) => _loadData());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // User signed in but no palettes
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.palette_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No saved palettes yet'
                : 'No palettes with tag "$_selectedFilter"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create palettes in the Roller tab',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _openPaletteDetail(UserPalette palette) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteDetailScreen(palette: palette),
      ),
    ).then((_) => _loadData()); // Refresh on return
  }

  void _openPaletteInRoller(UserPalette palette) {
    final sorted = [...palette.colors]..sort((a, b) => a.position.compareTo(b.position));
    final ids = sorted.map((c) => c.paintId).toList();
    
    // Navigate back to home screen and switch to roller tab
    // Find the HomeScreen in the navigation stack
    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/' || route.isFirst;
    });
    
    // Send data to the home screen to switch to roller with initial colors
    // Since we can't easily pass data back, we'll use a different approach
    // Navigate to a new route that handles the roller with initial colors
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _RollerWithInitialColorsWrapper(initialPaintIds: ids),
      ),
    );
  }

  Future<void> _deletePalette(UserPalette palette) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Palette'),
        content: Text('Are you sure you want to delete "${palette.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Cache the palette for undo functionality
        final cachedPalette = palette;
        
        await FirebaseService.deletePalette(palette.id);
        _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Palette deleted'),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  try {
                    // Re-create the palette with empty ID to generate new one
                    final newPalette = cachedPalette.copyWith(
                      id: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await FirebaseService.createPalette(
                      userId: newPalette.userId,
                      name: newPalette.name,
                      colors: newPalette.colors,
                      tags: newPalette.tags,
                      notes: newPalette.notes,
                    );
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Palette restored'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error restoring palette: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting palette: $e')),
          );
        }
      }
    }
  }
  
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Access Denied'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account doesn\'t have permission to access saved palettes and colors.',
            ),
            SizedBox(height: 12),
            Text(
              'This might be because:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('• You need to verify your email address'),
            Text('• Your account is still being set up'),
            Text('• There\'s a temporary server issue'),
            SizedBox(height: 12),
            Text(
              'Try signing out and signing back in, or contact support if the issue persists.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to settings screen where user can sign out
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text('Go to Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class EnhancedPaletteCard extends StatelessWidget {
  final UserPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onOpenInRoller;

  const EnhancedPaletteCard({
    super.key,
    required this.palette,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onOpenInRoller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Large color preview (top half)
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Row(
                  children: palette.colors.map((paletteColor) {
                    final color = ColorUtils.hexToColor(paletteColor.hex);
                    
                    return Expanded(
                      child: Container(
                        height: double.infinity,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Content section (bottom half) - Made more flexible
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title and menu
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            palette.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          onSelected: (value) {
                            switch (value) {
                              case 'roller':
                                onOpenInRoller();
                                break;
                              case 'edit':
                                onEdit();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'roller',
                              child: Row(
                                children: [
                                  Icon(Icons.casino, size: 16),
                                  SizedBox(width: 8),
                                  Text('Open in Roller'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Tags'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Metadata
                    Text(
                      '${palette.colors.length} colors • ${_formatDate(palette.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    if (palette.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: palette.tags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity( 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // No longer needed - using stored color info directly

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }
}

class SavedColorCard extends StatelessWidget {
  final Paint paint;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SavedColorCard({
    super.key,
    required this.paint,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final isLight = color.computeLuminance() > 0.5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color swatch
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity( 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Paint info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      paint.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paint.brandName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          paint.code,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTagsDialog extends StatefulWidget {
  final List<String> initialTags;
  final List<String> availableTags;

  const EditTagsDialog({
    super.key,
    required this.initialTags,
    required this.availableTags,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _selectedTags;
  final _customTagController = TextEditingController();
  
  // Common tag suggestions
  final List<String> _commonTags = [
    'living room', 'bedroom', 'kitchen', 'bathroom', 
    'office', 'neutral', 'warm', 'cool', 'bold', 
    'modern', 'traditional', 'cozy', 'bright', 'dark'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _customTagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedTags = {..._commonTags, ...widget.availableTags}
        .where((tag) => !_selectedTags.contains(tag))
        .toList()..sort();

    return AlertDialog(
      title: const Text('Edit Tags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected tags
            if (_selectedTags.isNotEmpty) ...[
              const Text('Selected Tags:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selectedTags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _toggleTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 16),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Add custom tag
            const Text('Add Custom Tag:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tag name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addCustomTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Suggested tags
            const Text('Suggested Tags:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: suggestedTags.map((tag) => FilterChip(
                label: Text(tag),
                onSelected: (_) => _toggleTag(tag),
              )).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedTags),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ColorDetailDialog extends StatelessWidget {
  final Paint paint;

  const ColorDetailDialog({
    super.key,
    required this.paint,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large color swatch
          Container(
            height: 200,
            width: double.infinity,
            color: color,
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paint.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                _buildDetailRow('Brand', paint.brandName),
                _buildDetailRow('Code', paint.code),
                _buildDetailRow('Hex', paint.hex),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper to handle opening roller with initial colors while preserving bottom navigation
class _RollerWithInitialColorsWrapper extends StatefulWidget {
  final List<String> initialPaintIds;

  const _RollerWithInitialColorsWrapper({
    required this.initialPaintIds,
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
  final List<String> initialPaintIds;

  const _HomeScreenWithRollerInitialColors({
    required this.initialPaintIds,
  });

  @override
  State<_HomeScreenWithRollerInitialColors> createState() => _HomeScreenWithRollerInitialColorsState();
}

class _HomeScreenWithRollerInitialColorsState extends State<_HomeScreenWithRollerInitialColors> {
  int _currentIndex = 0; // Start with roller tab
  late final GlobalKey<RollerScreenStatePublic> _rollerKey = GlobalKey<RollerScreenStatePublic>();
  
  late final List<Widget> _screens = [
    RollerScreen(key: _rollerKey, initialPaintIds: widget.initialPaintIds),
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
        const SnackBar(
          content: Text('Opened palette in Roller!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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