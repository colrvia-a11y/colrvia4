// This file provides examples of how to integrate the AnalyticsService
// into the existing Color Stories screens. Copy these patterns into the actual screens.

import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

/// Example integration for Color Story Detail Screen
class ColorStoryDetailScreenAnalyticsExample {
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Call this in initState() to track when a color story is opened
  Future<void> trackStoryOpen(ColorStory colorStory, {String? source}) async {
    await _analytics.trackColorStoryOpen(
      storyId: colorStory.id,
      slug: colorStory.slug,
      title: colorStory.title,
      themes: colorStory.themes,
      families: colorStory.families,
      rooms: colorStory.rooms,
      isFeatured: colorStory.isFeatured,
      source: source, // e.g., 'explore', 'featured', 'direct_link'
    );
  }

  /// Call this when user clicks "Use This Palette"
  Future<void> trackUseClick(ColorStory colorStory) async {
    final colorHexCodes = colorStory.palette.map((color) => color.hex).toList();
    
    await _analytics.trackColorStoryUseClick(
      storyId: colorStory.id,
      slug: colorStory.slug,
      title: colorStory.title,
      paletteColorCount: colorStory.palette.length,
      colorHexCodes: colorHexCodes,
    );
  }

  /// Call this when user clicks "Save to Library"
  Future<void> trackSaveClick(ColorStory colorStory, {bool? isAlreadySaved}) async {
    await _analytics.trackColorStorySaveClick(
      storyId: colorStory.id,
      slug: colorStory.slug,
      title: colorStory.title,
      isAlreadySaved: isAlreadySaved,
    );
  }

  /// Call this when user clicks "Share"
  Future<void> trackShareClick(ColorStory colorStory, {String? method}) async {
    await _analytics.trackColorStoryShareClick(
      storyId: colorStory.id,
      slug: colorStory.slug,
      title: colorStory.title,
      shareMethod: method, // e.g., 'native_share', 'copy_link'
    );
  }

  /// Call this when screen appears to set current screen
  Future<void> setScreenView() async {
    await _analytics.setCurrentScreen(
      screenName: 'color_story_detail',
      screenClass: 'ColorStoryDetailScreen',
    );
  }
}

/// Example integration for Explore Screen
class ExploreScreenAnalyticsExample {
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Call this when filters change
  Future<void> trackFilterChange({
    required List<String> selectedThemes,
    required List<String> selectedFamilies,
    required List<String> selectedRooms,
    required bool featuredOnly,
    required String changeType, // e.g., 'theme_added', 'family_removed'
    int? resultCount,
  }) async {
    await _analytics.trackExploreFilterChange(
      selectedThemes: selectedThemes,
      selectedFamilies: selectedFamilies,
      selectedRooms: selectedRooms,
      featuredOnly: featuredOnly,
      changeType: changeType,
      totalResultCount: resultCount,
    );
  }

  /// Call this when user performs a search
  Future<void> trackSearch({
    required String query,
    int? resultCount,
    List<String>? activeFilters,
  }) async {
    await _analytics.trackExploreSearch(
      searchQuery: query,
      resultCount: resultCount,
      activeFilters: activeFilters,
    );
  }

  /// Call this when screen appears
  Future<void> setScreenView() async {
    await _analytics.setCurrentScreen(
      screenName: 'explore',
      screenClass: 'ExploreScreen',
    );
  }
}

/// Example of tracking user properties for segmentation
class UserAnalyticsExample {
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Call this when user signs in or user data changes
  Future<void> setUserProperties({
    String? userType, // e.g., 'free', 'premium', 'admin'
    int? paletteCount,
    bool? isAdmin,
  }) async {
    if (userType != null) {
      await _analytics.setUserProperty('user_type', userType);
    }
    if (paletteCount != null) {
      await _analytics.setUserProperty('palette_count', paletteCount.toString());
    }
    if (isAdmin != null) {
      await _analytics.setUserProperty('is_admin', isAdmin.toString());
    }
  }
}

/// Example of integration patterns for method calls
class IntegrationPatterns {
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Pattern 1: Track button clicks with try-catch
  Future<void> handleUseThisPalette(ColorStory story) async {
    try {
      // Your existing business logic
      // Navigator.popUntil(context, (route) => route.isFirst);
      
      // Add analytics tracking
      await _analytics.trackColorStoryUseClick(
        storyId: story.id,
        slug: story.slug,
        title: story.title,
        paletteColorCount: story.palette.length,
      );
    } catch (e) {
      // Handle errors, analytics failures should not break functionality
      print('Error in handleUseThisPalette: $e');
    }
  }

  /// Pattern 2: Fire-and-forget analytics (don't await)
  void handleShareClick(ColorStory story) {
    // Your existing business logic
    // showShareDialog(story);
    
    // Fire-and-forget analytics (runs in background)
    _analytics.trackColorStoryShareClick(
      storyId: story.id,
      slug: story.slug,
      title: story.title,
      shareMethod: 'native_share',
    );
  }

  /// Pattern 3: Track with additional context
  Future<void> handleFilterChange(List<String> themes, String addedTheme) async {
    // Your existing filter logic
    // setState(() { _selectedThemes.add(addedTheme); });
    
    // Track with context about what changed
    await _analytics.trackExploreFilterChange(
      selectedThemes: themes,
      selectedFamilies: [],
      selectedRooms: [],
      featuredOnly: false,
      changeType: 'theme_added',
      totalResultCount: null, // Will be set after results load
    );
  }
}