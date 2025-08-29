import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/models/color_story.dart' as model;
import 'package:color_canvas/screens/color_story_detail_screen.dart';
import 'package:color_canvas/screens/color_story_wizard_screen.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/utils/gradient_hero_utils.dart';
import 'package:color_canvas/widgets/network_aware_image.dart';
import 'package:color_canvas/services/network_utils.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Performance optimization - debounce search
  Timer? _searchDebounce;
  final Duration _searchDelay = const Duration(milliseconds: 500);
  
  List<ColorStory> _stories = [];
  List<ColorStory> _filteredStories = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _hasError = false;
  String _errorMessage = '';
  final int _pageSize = 24;
  DocumentSnapshot? _lastDocument; // Cursor for pagination
  
  // Filter states
  final Set<String> _selectedThemes = <String>{};
  final Set<String> _selectedFamilies = <String>{};
  final Set<String> _selectedRooms = <String>{};
  String _searchQuery = '';
  String _sortBy = 'newest'; // v3: 'newest' or 'most_loved'
  
  // Filter options (loaded dynamically from Firestore)
  List<String> _themeOptions = [];
  List<String> _familyOptions = [];
  List<String> _roomOptions = [];
  
  // User palette state for FAB visibility
  bool _hasUserPalettes = false;
  
  // Spotlight stories state
  List<model.ColorStory> _spotlightStories = [];
  bool _isLoadingSpotlights = false;
  
  // Network preferences
  bool _wifiOnlyAssets = false;

  @override
  void initState() {
    super.initState();
    _loadTaxonomies();
    _loadSpotlightStories();
    _loadColorStories();
    _checkUserPalettes();
    _loadUserPreferences();
    _scrollController.addListener(_onScroll);
    
    // Track screen view
    AnalyticsService.instance.screenView('explore_color_stories');
  }

  Future<void> _loadTaxonomies() async {
    try {
      final taxonomies = await FirebaseService.getTaxonomyOptions();
      setState(() {
        _themeOptions = taxonomies['themes'] ?? [];
        _familyOptions = taxonomies['families'] ?? [];
        _roomOptions = taxonomies['rooms'] ?? [];
      });
    } catch (e) {
      // Use defaults on error
      setState(() {
        _themeOptions = ['coastal', 'modern-farmhouse', 'traditional', 'contemporary', 'rustic', 'minimalist'];
        _familyOptions = ['greens', 'blues', 'neutrals', 'warm-neutrals', 'cool-neutrals', 'whites', 'grays'];
        _roomOptions = ['kitchen', 'living', 'bedroom', 'bathroom', 'dining', 'exterior', 'office'];
      });
    }
  }
  
  Future<void> _loadSpotlightStories() async {
    setState(() => _isLoadingSpotlights = true);
    
    try {
      final spotlights = await FirebaseService.getSpotlightStories(limit: 12);
      setState(() => _spotlightStories = spotlights);
    } catch (e) {
      debugPrint('Error loading spotlight stories: $e');
      // Fail silently - spotlight rail will just not appear
    } finally {
      setState(() => _isLoadingSpotlights = false);
    }
  }
  
  Future<void> _loadUserPreferences() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseService.getUserDocument(user.uid);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            _wifiOnlyAssets = data['wifiOnlyAssets'] ?? false;
          });
        }
      } catch (e) {
        // Use defaults if loading fails
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreStories();
    }
  }

  Future<void> _loadColorStories() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Direct Firestore query with proper filtering
      final sortByMostLoved = _sortBy == 'most_loved';
      Query q = FirebaseFirestore.instance.collection('colorStories')
        .where('access', isEqualTo: 'public')
        .where('status', isEqualTo: 'complete')
        .orderBy(sortByMostLoved ? 'likeCount' : 'createdAt', descending: true);
      
      // Apply additional filters
      if (_selectedThemes.isNotEmpty) {
        q = q.where('themes', arrayContainsAny: _selectedThemes.toList());
      }
      if (_selectedFamilies.isNotEmpty) {
        q = q.where('families', arrayContainsAny: _selectedFamilies.toList());
      }
      if (_selectedRooms.isNotEmpty) {
        q = q.where('rooms', arrayContainsAny: _selectedRooms.toList());
      }
      
      q = q.limit(_pageSize);
      
      final snapshot = await q.get();
      final stories = snapshot.docs.map((doc) => 
        ColorStory.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
      
      setState(() {
        _stories = stories;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _applyTextFilter();
      });
    } catch (e) {
      debugPrint('Error loading color stories: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load color stories. Please check your connection.';
        // Fallback to sample data for development
        _stories = _getSampleStories();
        _applyTextFilter();
      });
      
      // Don't show global SnackBar - handle error locally in UI
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreStories() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Direct Firestore query with proper filtering and pagination
      final sortByMostLoved = _sortBy == 'most_loved';
      Query q = FirebaseFirestore.instance.collection('colorStories')
        .where('access', isEqualTo: 'public')
        .where('status', isEqualTo: 'complete')
        .orderBy(sortByMostLoved ? 'likeCount' : 'createdAt', descending: true);
      
      // Apply additional filters
      if (_selectedThemes.isNotEmpty) {
        q = q.where('themes', arrayContainsAny: _selectedThemes.toList());
      }
      if (_selectedFamilies.isNotEmpty) {
        q = q.where('families', arrayContainsAny: _selectedFamilies.toList());
      }
      if (_selectedRooms.isNotEmpty) {
        q = q.where('rooms', arrayContainsAny: _selectedRooms.toList());
      }
      
      q = q.startAfterDocument(_lastDocument!).limit(_pageSize);
      
      final snapshot = await q.get();
      final newStories = snapshot.docs.map((doc) => 
        ColorStory.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
      
      setState(() {
        _stories.addAll(newStories);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _applyTextFilter();
      });
    } catch (e) {
      debugPrint('Error loading more stories: $e');
      // Don't show global SnackBar for load more failures - handle silently
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyTextFilter() {
    if (_searchQuery.isEmpty) {
      _filteredStories = List.from(_stories);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredStories = _stories.where((story) {
        final titleMatch = story.title.toLowerCase().contains(query);
        final tagsMatch = story.tags.any((tag) => tag.toLowerCase().contains(query));
        return titleMatch || tagsMatch;
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous debounce timer
    _searchDebounce?.cancel();
    
    setState(() {
      _searchQuery = query;
      _applyTextFilter();
    });
    
    // Debounced analytics tracking to avoid too many events
    if (query.trim().isNotEmpty) {
      _searchDebounce = Timer(_searchDelay, () {
        final startTime = DateTime.now();
        _applyTextFilter();
        final searchDuration = DateTime.now().difference(startTime).inMilliseconds.toDouble();
        
        final activeFilters = <String>[
          ..._selectedThemes.map((t) => 'theme:$t'),
          ..._selectedFamilies.map((f) => 'family:$f'),
          ..._selectedRooms.map((r) => 'room:$r'),
        ];
        
        AnalyticsService.instance.trackExploreSearch(
          searchQuery: query.trim(),
          resultCount: _filteredStories.length,
          searchDurationMs: searchDuration,
          activeFilters: activeFilters.isNotEmpty ? activeFilters : null,
        );
      });
    }
  }

  void _onFilterChanged() {
    _hasMoreData = true;
    _lastDocument = null; // Reset cursor for new filter query
    _loadColorStories();
    
    // Track filter analytics
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
    );
  }

  void _toggleTheme(String theme) {
    final wasSelected = _selectedThemes.contains(theme);
    setState(() {
      if (wasSelected) {
        _selectedThemes.remove(theme);
      } else {
        _selectedThemes.add(theme);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'theme_removed' : 'theme_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  void _toggleFamily(String family) {
    final wasSelected = _selectedFamilies.contains(family);
    setState(() {
      if (wasSelected) {
        _selectedFamilies.remove(family);
      } else {
        _selectedFamilies.add(family);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'family_removed' : 'family_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  void _toggleRoom(String room) {
    final wasSelected = _selectedRooms.contains(room);
    setState(() {
      if (wasSelected) {
        _selectedRooms.remove(room);
      } else {
        _selectedRooms.add(room);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'room_removed' : 'room_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  List<ColorStory> _getSampleStories() {
    // Sample data for development/offline mode
    return [
      ColorStory(
        id: 'sample-1',
        userId: 'sample-user', // Sample data placeholder
        title: 'Coastal Serenity',
        slug: 'coastal-serenity',
        heroImageUrl: 'https://pixabay.com/get/g1d5c9aa83a66d093c7e4b4fc7b97b2b2a83ae7a311c8f2f0d621269c20bd3109f26e62dbe18eb3717b515c4738252cdef0a5fb70596b60152ed0ed0b61c5ddef_1280.jpg',
        themes: ['coastal', 'contemporary'],
        families: ['blues', 'neutrals'],
        rooms: ['living', 'bedroom'],
        tags: ['ocean', 'calming', 'fresh'],
        description: 'Inspired by ocean waves and sandy shores',
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        facets: ['theme:coastal', 'theme:contemporary', 'family:blues', 'family:neutrals', 'room:living', 'room:bedroom'],
        palette: [
          ColorStoryPalette(
            role: 'main',
            hex: '#4A90A4',
            name: 'Ocean Blue',
            brandName: 'Sherwin-Williams',
            code: 'SW 6501',
            psychology: 'Promotes tranquility and calm, evoking the serenity of ocean depths.',
            usageTips: 'Perfect for bedrooms and bathrooms where relaxation is key.',
          ),
          ColorStoryPalette(
            role: 'accent',
            hex: '#E8F4F8',
            name: 'Sea Foam',
            brandName: 'Benjamin Moore',
            code: 'OC-58',
            psychology: 'Light and airy, creates a sense of freshness and renewal.',
            usageTips: 'Ideal for trim work and ceiling accents to brighten spaces.',
          ),
          ColorStoryPalette(
            role: 'trim',
            hex: '#F5F5DC',
            name: 'Sandy Beige',
            brandName: 'Behr',
            code: 'N240-1',
            psychology: 'Warm and grounding, provides stability and comfort.',
            usageTips: 'Use as a neutral base to balance cooler tones.',
          ),
        ],
      ),
      ColorStory(
        id: 'sample-2',
        userId: 'sample-user', // Sample data placeholder
        title: 'Modern Farmhouse',
        slug: 'modern-farmhouse',
        heroImageUrl: 'https://pixabay.com/get/ga04013479135d1420a173525047d5aa53d70a7cef34a22c34c59d3edfee6daff2a8feee41d7e42aac0dd6462898e291ef492fa25b9984dd761c6f49b9cf20a68_1280.jpg',
        themes: ['modern-farmhouse', 'rustic'],
        families: ['warm-neutrals', 'whites'],
        rooms: ['kitchen', 'dining'],
        tags: ['cozy', 'natural', 'warm'],
        description: 'Warm and inviting farmhouse aesthetic',
        isFeatured: false,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        facets: ['theme:modern-farmhouse', 'theme:rustic', 'family:warm-neutrals', 'family:whites', 'room:kitchen', 'room:dining'],
        palette: [
          ColorStoryPalette(
            role: 'main',
            hex: '#F7F3E9',
            name: 'Creamy White',
            brandName: 'Benjamin Moore',
            code: 'OC-14',
            psychology: 'Warm and inviting, creates a cozy and welcoming atmosphere.',
            usageTips: 'Excellent for main walls in kitchens and dining areas.',
          ),
          ColorStoryPalette(
            role: 'accent',
            hex: '#8B7355',
            name: 'Weathered Wood',
            brandName: 'Sherwin-Williams',
            code: 'SW 2841',
            psychology: 'Natural and rustic, brings warmth and earthiness to spaces.',
            usageTips: 'Perfect for accent walls and built-in cabinetry.',
          ),
          ColorStoryPalette(
            role: 'trim',
            hex: '#2F2F2F',
            name: 'Charcoal',
            brandName: 'Behr',
            code: 'S350-7',
            psychology: 'Bold and sophisticated, adds depth and contrast.',
            usageTips: 'Use sparingly on trim and window frames for definition.',
          ),
        ],
      ),
    ];
  }

  void _navigateToStory(String storyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColorStoryDetailScreen(storyId: storyId),
      ),
    );
    
    // Track analytics
    AnalyticsService.instance.logEvent('spotlight_story_tapped', {
      'story_id': storyId,
      'source': 'spotlight_rail',
    });
  }
  
  void _showAllSpotlights() {
    // For now, just reload the main stories with a spotlight filter
    // In a real implementation, you would modify the query to filter by spotlight=true
    
    // Track analytics
    AnalyticsService.instance.logEvent('spotlight_see_all_tapped', {
      'spotlight_count': _spotlightStories.length,
    });
    
    // Show snackbar to indicate spotlight filter
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing ${_spotlightStories.length} spotlight stories'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View All',
          onPressed: () {
            // Reset to normal explore view
            _loadColorStories();
          },
        ),
      ),
    );
  }
  
  Future<void> _checkUserPalettes() async {
    try {
      final userId = FirebaseService.currentUser?.uid;
      if (userId != null) {
        final palettes = await FirebaseService.getUserPalettes(userId);
        setState(() {
          _hasUserPalettes = palettes.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently fail - just keep FAB showing StoryStudio as fallback
      debugPrint('Error checking user palettes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Stories'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ColorStoryWizardScreen(),
            ),
          );
          
          AnalyticsService.instance.logEvent('explore_new_story_fab', {
            'has_palettes': _hasUserPalettes,
            'destination': 'color_story_wizard',
          });
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.auto_awesome),
        tooltip: 'Create Color Story',
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  final startTime = DateTime.now();
                  _applyTextFilter();
                  final searchDuration = DateTime.now().difference(startTime).inMilliseconds.toDouble();
                  
                  AnalyticsService.instance.trackExploreSearch(
                    searchQuery: query.trim(),
                    resultCount: _filteredStories.length,
                    searchDurationMs: searchDuration,
                  );
                }
              },
              decoration: InputDecoration(
                hintText: 'Search stories or tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          
          // Spotlight Rail
          if (_spotlightStories.isNotEmpty) _buildSpotlightRail(),
          
          // v3: Sort Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 8, top: 8),
            child: Row(
              children: [
                Text(
                  'Sort by:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _sortBy,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'most_loved', child: Text('Most Loved')),
                  ],
                  onChanged: (value) {
                    if (value != null && value != _sortBy) {
                      setState(() {
                        _sortBy = value;
                      });
                      
                      // Track analytics
                      AnalyticsService.instance.trackExploreSortChanged(value: value);
                      
                      // Reload with new sort
                      _onFilterChanged();
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Filter Chips
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection('Style', _themeOptions, _selectedThemes, _toggleTheme),
                  const SizedBox(height: 8),
                  _buildFilterSection('Family', _familyOptions, _selectedFamilies, _toggleFamily),
                  const SizedBox(height: 8),
                  _buildFilterSection('Room', _roomOptions, _selectedRooms, _toggleRoom),
                ],
              ),
            ),
          ),
          
          const Divider(height: 1),
          
          // Results Grid
          Expanded(
            child: _buildResultsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, Set<String> selected, Function(String) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: options.map((option) => FilterChip(
            label: Text(
              option.replaceAll('-', ' '),
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected.contains(option),
            onSelected: (_) => onToggle(option),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSpotlightRail() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.stars,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Designer Spotlights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _showAllSpotlights,
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Horizontal scrolling cards
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _spotlightStories.length,
              itemBuilder: (context, index) {
                final story = _spotlightStories[index];
                return _buildSpotlightCard(story, index);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpotlightCard(model.ColorStory story, int index) {
    return Container(
      width: 200,
      margin: EdgeInsets.only(right: index < _spotlightStories.length - 1 ? 12 : 0),
      child: InkWell(
        onTap: () => _navigateToStory(story.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: story.heroImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: story.heroImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => _buildSpotlightGradientFallback(story),
                          errorWidget: (_, __, ___) => _buildSpotlightGradientFallback(story),
                        )
                      : _buildSpotlightGradientFallback(story),
                ),
              ),
              
              // Story info
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        story.narration.isNotEmpty 
                          ? story.narration.split(' ').take(4).join(' ')
                          : 'Beautiful Color Story',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Designer attribution and likes
                      Row(
                        children: [
                          // Designer attribution
                          Expanded(
                            child: Text(
                              'AI Generated',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Likes placeholder - would need to be fetched from firestore
                          if (story.access == 'public') ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.red.withOpacity(0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '0', // Placeholder - would need actual like count
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSpotlightGradientFallback(model.ColorStory story) {
    // Extract colors from usage guide for gradient
    String firstColor = '#6366F1';
    String secondColor = '#8B5CF6';
    
    if (story.usageGuide.isNotEmpty) {
      final validColors = story.usageGuide
          .where((item) => item.hex.isNotEmpty)
          .map((item) => item.hex)
          .toList();
      
      if (validColors.isNotEmpty) {
        firstColor = validColors.first;
        if (validColors.length > 1) {
          secondColor = validColors[1];
        }
      }
    }
    
    return GradientHeroUtils.buildGradientFallback(
      colorA: firstColor,
      colorB: secondColor,
      child: Center(
        child: Icon(
          Icons.palette,
          color: Colors.white.withOpacity(0.8),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    if (_isLoading && _filteredStories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading color stories...'),
          ],
        ),
      );
    }
    
    if (_hasError && _filteredStories.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredStories.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(context),
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredStories.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredStories.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        return ColorStoryCard(story: _filteredStories[index], wifiOnlyPref: _wifiOnlyAssets);
      },
    );
  }

  Widget _buildEmptyState() {
    // Generate dynamic suggestions based on current filter state
    final suggestion = _buildDynamicSuggestion();
    
    // Track empty state analytics
    AnalyticsService.instance.trackExploreEmptyStateShown(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      suggestedAction: suggestion['action'] ?? 'unknown',
    );
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              'No matches yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              suggestion['message'] ?? 'Try adjusting your filters or search terms',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            
            // Clear filters button (always shown when filters are active)
            if (_selectedThemes.isNotEmpty || _selectedFamilies.isNotEmpty || _selectedRooms.isNotEmpty || _searchQuery.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Track clear filters action
                    AnalyticsService.instance.trackColorStoriesEngagement(
                      action: 'clear_filters_from_empty_state',
                      additionalData: {
                        'had_themes': _selectedThemes.isNotEmpty,
                        'had_families': _selectedFamilies.isNotEmpty,
                        'had_rooms': _selectedRooms.isNotEmpty,
                        'had_search': _searchQuery.isNotEmpty,
                      },
                    );
                    
                    setState(() {
                      _selectedThemes.clear();
                      _selectedFamilies.clear();
                      _selectedRooms.clear();
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _onFilterChanged();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear filters'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Build dynamic suggestion message based on current filter state
  Map<String, String> _buildDynamicSuggestion() {
    final hasThemes = _selectedThemes.isNotEmpty;
    final hasFamilies = _selectedFamilies.isNotEmpty;
    final hasRooms = _selectedRooms.isNotEmpty;
    final hasSearch = _searchQuery.isNotEmpty;
    
    // If all three filter categories are selected, suggest removing the most restrictive one
    if (hasThemes && hasFamilies && hasRooms) {
      return {
        'message': 'This combination might be too specific. Try removing one of your filters to find more stories.',
        'action': 'remove_filter_combination',
      };
    }
    
    // If search query + multiple filters
    if (hasSearch && (hasThemes || hasFamilies || hasRooms)) {
      return {
        'message': 'Your search combined with filters might be too narrow. Try clearing your search or removing some filters.',
        'action': 'simplify_search_and_filters',
      };
    }
    
    // If only search query
    if (hasSearch && !hasThemes && !hasFamilies && !hasRooms) {
      return {
        'message': 'No stories match your search. Try different keywords or browse by style instead.',
        'action': 'modify_search_query',
      };
    }
    
    // If only rooms are selected (most restrictive)
    if (hasRooms && !hasThemes && !hasFamilies) {
      return {
        'message': 'Try adding a color family like "neutrals" or "blues" to find stories for this room.',
        'action': 'add_family_filter',
      };
    }
    
    // If themes + families but no rooms
    if (hasThemes && hasFamilies && !hasRooms) {
      return {
        'message': 'This style and color combination might be rare. Try expanding to more color families.',
        'action': 'expand_families',
      };
    }
    
    // If only themes selected
    if (hasThemes && !hasFamilies && !hasRooms) {
      return {
        'message': 'Try adding a color family like "neutrals" or "warm-neutrals" to discover stories in this style.',
        'action': 'add_family_to_theme',
      };
    }
    
    // If only families selected
    if (hasFamilies && !hasThemes && !hasRooms) {
      return {
        'message': 'Try adding a style like "modern-farmhouse" or "contemporary" to find stories with these colors.',
        'action': 'add_theme_to_family',
      };
    }
    
    // Default case (no filters)
    return {
      'message': 'No color stories available right now. Check your connection or try again later.',
      'action': 'connection_issue',
    };
  }
  
  // Error handling is now done inline in the UI instead of global SnackBars
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Unable to load color stories. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    });
                    _loadColorStories();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                      _stories = _getSampleStories();
                      _applyTextFilter();
                    });
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('View Samples'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  int _getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4; // Desktop
    if (width > 600) return 3;  // Tablet
    return 2;                   // Mobile
  }
}

class ColorStoryCard extends StatelessWidget {
  final ColorStory story;
  final bool wifiOnlyPref;

  const ColorStoryCard({super.key, required this.story, this.wifiOnlyPref = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Track story open analytics
          AnalyticsService.instance.trackColorStoryOpen(
            storyId: story.id,
            slug: story.slug,
            title: story.title,
            source: 'explore',
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ColorStoryDetailScreen(storyId: story.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image with Palette Preview
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (story.heroImageUrl != null || story.fallbackHero.isNotEmpty)
                    ClipRRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Always show gradient fallback first for instant render
                          if (story.fallbackHero.isNotEmpty)
                            GradientHeroUtils.buildGradientFallback(
                              colorA: _extractFirstColor(story),
                              colorB: _extractSecondColor(story),
                              child: Center(
                                child: Icon(
                                  Icons.palette,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 24,
                                ),
                              ),
                            ),
                          
                          // Network-aware hero image loading
                          if (story.heroImageUrl != null)
                            NetworkAwareImage(
                              imageUrl: story.heroImageUrl!,
                              wifiOnlyPref: wifiOnlyPref,
                              fit: BoxFit.cover,
                              isHeavyAsset: true,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    )
                  else
                    _buildPalettePreview(),
                  
                  // Featured badge and menu
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (story.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (story.isFeatured) const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 16,
                            ),
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'use_start',
                                child: const Text('Use as Starting Point'),
                              ),
                              PopupMenuItem(
                                value: 'view_details',
                                child: const Text('View Details'),
                              ),
                            ],
                            onSelected: (value) async {
                              switch (value) {
                                case 'use_start':
                                  await _handleUseAsStartingPoint(context, story);
                                  break;
                                case 'view_details':
                                  _navigateToStoryDetail(context, story);
                                  break;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // v3: Processing/queued spinner badge (top-left)
                  if (story.status == 'processing' || story.status == 'queued')
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: story.status == 'processing' 
                              ? Colors.blue.shade600 
                              : Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              story.status == 'processing' ? 'Processing' : 'Queued',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // v3: Like count badge (bottom-left)
                  if (story.likeCount > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              story.likeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: story.title,
                    ),
                    const SizedBox(height: 4),
                    if (story.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: story.tags.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )).toList(),
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

  String _extractFirstColor(ColorStory story) {
    if (story.usageGuide.isNotEmpty && story.usageGuide.first.hex.isNotEmpty) {
      return story.usageGuide.first.hex;
    }
    if (story.palette.isNotEmpty && story.palette.first.hex.isNotEmpty) {
      return story.palette.first.hex;
    }
    return '#6366F1'; // Default indigo
  }
  
  String _extractSecondColor(ColorStory story) {
    if (story.usageGuide.length > 1 && story.usageGuide[1].hex.isNotEmpty) {
      return story.usageGuide[1].hex;
    }
    if (story.palette.length > 1 && story.palette[1].hex.isNotEmpty) {
      return story.palette[1].hex;
    }
    if (story.usageGuide.isNotEmpty && story.usageGuide.first.hex.isNotEmpty) {
      return story.usageGuide.first.hex;
    }
    if (story.palette.isNotEmpty && story.palette.first.hex.isNotEmpty) {
      return story.palette.first.hex;
    }
    return '#8B5CF6'; // Default purple
  }

  Widget _buildPalettePreview() {
    if (story.palette.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.palette_outlined,
            size: 32,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Row(
      children: story.palette.take(5).map((color) {
        final colorValue = int.parse(color.hex.substring(1), radix: 16) + 0xFF000000;
        return Expanded(
          child: Container(
            color: Color(colorValue),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleUseAsStartingPoint(BuildContext context, ColorStory story) async {
    try {
      // First, we need to get the palette ID from the story
      // Since ColorStory might not directly expose paletteId, we'll create a new palette from the story's colors
      final user = FirebaseService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create a Color Story')),
        );
        return;
      }
      
      // Convert story palette colors to PaletteColor format
      final paletteColors = story.palette.asMap().entries.map((entry) {
        final color = entry.value;
        return PaletteColor(
          paintId: color.paintId?.isNotEmpty == true ? color.paintId! : 'imported_${color.hex}',
          locked: false,
          position: entry.key,
          brand: color.brandName?.isNotEmpty == true ? color.brandName! : 'Unknown',
          name: color.name?.isNotEmpty == true ? color.name! : 'Color ${entry.key + 1}',
          code: color.code?.isNotEmpty == true ? color.code! : color.hex,
          hex: color.hex,
        );
      }).toList();
      
      if (paletteColors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story has no colors to use')),
        );
        return;
      }
      
      // Create a new palette based on the story
      final seededPaletteId = await FirebaseService.createPalette(
        userId: user.uid,
        name: '${story.title} (Remix)',
        colors: paletteColors,
        tags: [...story.tags, 'remix'],
        notes: 'Based on: ${story.title}',
      );
      
      // Create project
      final project = await ProjectService.create(
        title: '${story.title} (Remix)',
        paletteId: seededPaletteId,
      );
      
      // Track start from explore
      AnalyticsService.instance.logStartFromExplore(story.id, project.id);
      
      // Navigate to Roller with success feedback
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen()));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started new Color Story from "${story.title}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Navigate back to dashboard to see the project
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating Color Story: $e')),
      );
    }
  }

  void _navigateToStoryDetail(BuildContext context, ColorStory story) {
    // Track story open analytics
    AnalyticsService.instance.trackColorStoryOpen(
      storyId: story.id,
      slug: story.slug,
      title: story.title,
      source: 'explore_menu',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColorStoryDetailScreen(storyId: story.id),
      ),
    );
  }
}