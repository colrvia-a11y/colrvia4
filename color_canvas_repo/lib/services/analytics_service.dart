import 'dart:developer' as developer;
import '../models/project.dart';

/// A comprehensive analytics tracking service for Color Stories feature.
/// 
/// This service provides analytics tracking for Color Stories interactions.
/// It uses a mock implementation that logs events to the console since Firebase Analytics
/// is not currently installed in the project. When Firebase Analytics is added to the project,
/// replace the mock implementation with actual Firebase Analytics calls.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  bool _isEnabled = true;
  
  /// Enable or disable analytics tracking
  void setAnalyticsCollectionEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Track when a user opens/views a color story
  Future<void> trackColorStoryOpen({
    required String storyId,
    required String slug,
    String? title,
    List<String>? themes,
    List<String>? families,
    List<String>? rooms,
    bool? isFeatured,
    String? source, // e.g., 'explore', 'featured', 'search'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'slug': slug,
        if (title != null) 'story_title': title,
        if (themes != null && themes.isNotEmpty) 'themes': themes.join(','),
        if (families != null && families.isNotEmpty) 'families': families.join(','),
        if (rooms != null && rooms.isNotEmpty) 'rooms': rooms.join(','),
        if (isFeatured != null) 'is_featured': isFeatured,
        if (source != null) 'source': source,
      };

      await _logEvent('color_story_open', parameters);
    } catch (e) {
      developer.log('Analytics error in trackColorStoryOpen: $e', name: 'AnalyticsService');
    }
  }

  /// Track when a user clicks "Use This Palette" button
  Future<void> trackColorStoryUseClick({
    required String storyId,
    required String slug,
    String? title,
    int? paletteColorCount,
    List<String>? colorHexCodes,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'slug': slug,
        if (title != null) 'story_title': title,
        if (paletteColorCount != null) 'palette_color_count': paletteColorCount,
        if (colorHexCodes != null && colorHexCodes.isNotEmpty)
          'color_codes': colorHexCodes.join(','),
      };

      await _logEvent('color_story_use_click', parameters);
    } catch (e) {
      developer.log('Analytics error in trackColorStoryUseClick: $e', name: 'AnalyticsService');
    }
  }

  /// Track when a user clicks "Save to Library" button
  Future<void> trackColorStorySaveClick({
    required String storyId,
    required String slug,
    String? title,
    bool? isAlreadySaved,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'slug': slug,
        if (title != null) 'story_title': title,
        if (isAlreadySaved != null) 'is_already_saved': isAlreadySaved,
      };

      await _logEvent('color_story_save_click', parameters);
    } catch (e) {
      developer.log('Analytics error in trackColorStorySaveClick: $e', name: 'AnalyticsService');
    }
  }

  /// Track when a user clicks "Share" button
  Future<void> trackColorStoryShareClick({
    required String storyId,
    required String slug,
    String? title,
    String? shareMethod, // e.g., 'native_share', 'copy_link', 'social'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'slug': slug,
        if (title != null) 'story_title': title,
        if (shareMethod != null) 'share_method': shareMethod,
      };

      await _logEvent('color_story_share_click', parameters);
    } catch (e) {
      developer.log('Analytics error in trackColorStoryShareClick: $e', name: 'AnalyticsService');
    }
  }

  /// Track when user changes filters in the explore screen
  Future<void> trackExploreFilterChange({
    List<String>? selectedThemes,
    List<String>? selectedFamilies,
    List<String>? selectedRooms,
    bool? featuredOnly,
    String? changeType, // e.g., 'theme_added', 'family_removed', 'featured_toggled'
    int? totalResultCount,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        if (selectedThemes != null) 'selected_themes': selectedThemes.join(','),
        if (selectedFamilies != null) 'selected_families': selectedFamilies.join(','),
        if (selectedRooms != null) 'selected_rooms': selectedRooms.join(','),
        if (featuredOnly != null) 'featured_only': featuredOnly,
        if (changeType != null) 'change_type': changeType,
        if (totalResultCount != null) 'result_count': totalResultCount,
        'active_filter_count': _calculateActiveFilterCount(
          selectedThemes, selectedFamilies, selectedRooms, featuredOnly,
        ),
      };

      await _logEvent('explore_filter_change', parameters);
    } catch (e) {
      developer.log('Analytics error in trackExploreFilterChange: $e', name: 'AnalyticsService');
    }
  }

  /// Track when user performs a search in the explore screen
  Future<void> trackExploreSearch({
    required String searchQuery,
    int? resultCount,
    double? searchDurationMs,
    List<String>? activeFilters,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'search_query': searchQuery.toLowerCase().trim(),
        'query_length': searchQuery.trim().length,
        if (resultCount != null) 'result_count': resultCount,
        if (searchDurationMs != null) 'search_duration_ms': searchDurationMs.round(),
        if (activeFilters != null && activeFilters.isNotEmpty)
          'active_filters': activeFilters.join(','),
      };

      await _logEvent('explore_search', parameters);
    } catch (e) {
      developer.log('Analytics error in trackExploreSearch: $e', name: 'AnalyticsService');
    }
  }

  /// Track when explore empty state is shown
  Future<void> trackExploreEmptyStateShown({
    List<String>? selectedThemes,
    List<String>? selectedFamilies,
    List<String>? selectedRooms,
    String? searchQuery,
    String? suggestedAction,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        if (selectedThemes != null && selectedThemes.isNotEmpty) 
          'selected_themes': selectedThemes.join(','),
        if (selectedFamilies != null && selectedFamilies.isNotEmpty) 
          'selected_families': selectedFamilies.join(','),
        if (selectedRooms != null && selectedRooms.isNotEmpty) 
          'selected_rooms': selectedRooms.join(','),
        if (searchQuery != null && searchQuery.isNotEmpty) 
          'search_query': searchQuery.toLowerCase().trim(),
        if (suggestedAction != null) 'suggested_action': suggestedAction,
        'active_filter_count': _calculateActiveFilterCount(
          selectedThemes, selectedFamilies, selectedRooms, null,
        ),
        'has_search_query': searchQuery != null && searchQuery.trim().isNotEmpty,
      };

      await _logEvent('explore_empty_state_shown', parameters);
    } catch (e) {
      developer.log('Analytics error in trackExploreEmptyStateShown: $e', name: 'AnalyticsService');
    }
  }

  /// Track general user engagement with color stories feature
  Future<void> trackColorStoriesEngagement({
    required String action, // e.g., 'feature_accessed', 'story_favorited', 'palette_exported'
    String? storyId,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'action': action,
        if (storyId != null) 'story_id': storyId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (additionalData != null) {
        parameters.addAll(additionalData);
      }

      await _logEvent('color_stories_engagement', parameters);
    } catch (e) {
      developer.log('Analytics error in trackColorStoriesEngagement: $e', name: 'AnalyticsService');
    }
  }

  /// Track when harmony modes are sorted by LRV in the Roller
  Future<void> trackRollerHarmonySortedByLrv({
    required String modeName,
    required int paletteSize,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'harmony_mode': modeName,
        'palette_size': paletteSize,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('roller_harmony_sorted_by_lrv', parameters);
    } catch (e) {
      developer.log('Analytics error in trackRollerHarmonySortedByLrv: $e', name: 'AnalyticsService');
    }
  }

  /// Track user properties for segmentation
  Future<void> setUserProperty(String name, String? value) async {
    if (!_isEnabled) return;

    try {
      // Mock implementation - log the user property
      developer.log('Setting user property: $name = $value', name: 'AnalyticsService');
      
      // TODO: When Firebase Analytics is added, replace with:
      // await FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
    } catch (e) {
      developer.log('Analytics error in setUserProperty: $e', name: 'AnalyticsService');
    }
  }

  /// Set the current screen name for analytics
  Future<void> setCurrentScreen({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isEnabled) return;

    try {
      developer.log('Screen view: $screenName${screenClass != null ? ' ($screenClass)' : ''}', 
                   name: 'AnalyticsService');
      
      // TODO: When Firebase Analytics is added, replace with:
      // await FirebaseAnalytics.instance.logScreenView(
      //   screenName: screenName,
      //   screenClass: screenClass,
      // );
    } catch (e) {
      developer.log('Analytics error in setCurrentScreen: $e', name: 'AnalyticsService');
    }
  }

  /// Track Color Story generation start
  Future<void> trackStoryGenerateStart({
    required String paletteId,
    required String styleTag,
    required String roomType,
    List<String>? vibeWords,
    List<String>? brandHints,
    String? guidanceLevel,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'palette_id': paletteId,
        'style_tag': styleTag,
        'room_type': roomType,
        if (vibeWords != null && vibeWords.isNotEmpty) 'vibe_words': vibeWords.join(','),
        if (brandHints != null && brandHints.isNotEmpty) 'brand_hints': brandHints.join(','),
        if (guidanceLevel != null) 'guidance_level': guidanceLevel,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_generate_start', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryGenerateStart: $e', name: 'AnalyticsService');
    }
  }

  /// Track Color Story generation completion
  Future<void> trackStoryGenerateComplete({
    required String storyId,
    required String paletteId,
    required Duration generationTime,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'palette_id': paletteId,
        'generation_time_seconds': generationTime.inSeconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_generate_complete', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryGenerateComplete: $e', name: 'AnalyticsService');
    }
  }

  /// Track Color Story generation error
  Future<void> trackStoryGenerateError({
    required String errorMessage,
    String? paletteId,
    String? storyId,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'error_message': errorMessage,
        if (paletteId != null) 'palette_id': paletteId,
        if (storyId != null) 'story_id': storyId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_generate_error', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryGenerateError: $e', name: 'AnalyticsService');
    }
  }

  /// Track story audio play
  Future<void> trackStoryPlay({
    required String storyId,
    String? audioType, // 'ambient' | 'tts'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        if (audioType != null) 'audio_type': audioType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_play', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryPlay: $e', name: 'AnalyticsService');
    }
  }

  /// Track story like
  Future<void> trackStoryLike({
    required String storyId,
    required bool liked, // true = liked, false = unliked
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'liked': liked,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_like', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryLike: $e', name: 'AnalyticsService');
    }
  }

  /// Track apply story to visualizer
  Future<void> trackStoryApplyVisualizer({
    required String storyId,
    required String roomType,
    int? colorCount,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'room_type': roomType,
        if (colorCount != null) 'color_count': colorCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_apply_visualizer', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryApplyVisualizer: $e', name: 'AnalyticsService');
    }
  }

  /// Track story remix (regenerate with different parameters)
  Future<void> trackStoryRemix({
    required String storyId,
    required String remixType, // 'image' | 'audio' | 'narration'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        'remix_type': remixType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('story_remix', parameters);
    } catch (e) {
      developer.log('Analytics error in trackStoryRemix: $e', name: 'AnalyticsService');
    }
  }

  /// Track wizard screen open
  Future<void> trackWizardOpen({
    String? source, // 'explore_fab' | 'save_panel' | 'palette_detail' | etc
    String? preselectedPaletteId,
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        if (source != null) 'source': source,
        if (preselectedPaletteId != null) 'preselected_palette_id': preselectedPaletteId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('wizard_open', parameters);
    } catch (e) {
      developer.log('Analytics error in trackWizardOpen: $e', name: 'AnalyticsService');
    }
  }

  /// Track color story reveal screen open
  Future<void> trackRevealOpen({
    required String storyId,
    String? source, // 'wizard' | 'explore' | 'library' | etc
    String? status, // 'complete' | 'processing' | 'error'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'story_id': storyId,
        if (source != null) 'source': source,
        if (status != null) 'status': status,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('reveal_open', parameters);
    } catch (e) {
      developer.log('Analytics error in trackRevealOpen: $e', name: 'AnalyticsService');
    }
  }

  /// Track Explore screen sort changes
  Future<void> trackExploreSortChanged({
    required String value, // 'newest' | 'most_loved'
  }) async {
    if (!_isEnabled) return;

    try {
      final Map<String, dynamic> parameters = {
        'value': value,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _logEvent('explore_sort_changed', parameters);
    } catch (e) {
      developer.log('Analytics error in trackExploreSortChanged: $e', name: 'AnalyticsService');
    }
  }

  /// Public method to log custom events with parameters
  Future<void> logEvent(String eventName, [Map<String, dynamic>? parameters]) async {
    await _logEvent(eventName, parameters ?? {});
  }

  /// Internal method to log events - currently uses mock implementation
  Future<void> _logEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      // Mock implementation - log to console with structured format
      final parametersStr = parameters.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      
      developer.log(
        'EVENT: $eventName | $parametersStr',
        name: 'AnalyticsService',
      );

      // TODO: When Firebase Analytics is added, replace with:
      // await FirebaseAnalytics.instance.logEvent(
      //   name: eventName,
      //   parameters: parameters,
      // );
      
    } catch (e) {
      developer.log('Failed to log analytics event $eventName: $e', name: 'AnalyticsService');
      // Don't rethrow - analytics failures should not crash the app
    }
  }

  /// Helper method to calculate the number of active filters
  int _calculateActiveFilterCount(
    List<String>? themes,
    List<String>? families, 
    List<String>? rooms,
    bool? featuredOnly,
  ) {
    int count = 0;
    if (themes != null && themes.isNotEmpty) count++;
    if (families != null && families.isNotEmpty) count++;
    if (rooms != null && rooms.isNotEmpty) count++;
    if (featuredOnly == true) count++;
    return count;
  }

  /// Get analytics instance for direct access if needed
  /// Returns null in mock implementation
  dynamic get analyticsInstance {
    // TODO: When Firebase Analytics is added, return:
    // return FirebaseAnalytics.instance;
    return null;
  }

  // Funnel Analytics Methods
  
  /// Track when dashboard is opened
  Future<void> logDashboardOpened() async {
    await _logEvent('dashboard_opened', {});
  }

  /// Track when a project is created
  Future<void> logProjectCreated(String projectId) async {
    await _logEvent('project_created', {
      'project_id': projectId,
    });
  }

  /// Track when a project changes funnel stage
  Future<void> logProjectStageChanged(String projectId, FunnelStage stage) async {
    await _logEvent('project_stage_changed', {
      'project_id': projectId,
      'stage': funnelStageToString(stage),
    });
  }

  /// Track when user starts from explore story
  Future<void> logStartFromExplore(String sourceStoryId, String projectId) async {
    await _logEvent('start_from_explore', {
      'source_story_id': sourceStoryId,
      'project_id': projectId,
    });
  }

  /// Track when roller saves to project
  Future<void> logRollerSaveToProject(String projectId, String paletteId) async {
    await _logEvent('roller_save_to_project', {
      'project_id': projectId,
      'palette_id': paletteId,
    });
  }

  /// Track when story is generated
  Future<void> logStoryGenerated(String projectId, String colorStoryId) async {
    await _logEvent('story_generated', {
      'project_id': projectId,
      'color_story_id': colorStoryId,
    });
  }

  /// Track when visualizer is opened from story
  Future<void> logVisualizerOpenedFromStory(String projectId) async {
    await _logEvent('visualizer_opened_from_story', {
      'project_id': projectId,
    });
  }

  /// Track when export/share happens
  Future<void> logExportShared(String projectId) async {
    await _logEvent('export_shared', {
      'project_id': projectId,
    });
  }
}

// Extension methods for easy access
extension AnalyticsServiceExtension on AnalyticsService {
  /// Quick method to track screen views
  Future<void> screenView(String screenName) async {
    await setCurrentScreen(screenName: screenName);
  }

  /// Quick method to track button clicks
  Future<void> buttonClick(String buttonName, {Map<String, dynamic>? data}) async {
    await trackColorStoriesEngagement(
      action: 'button_click',
      additionalData: {'button_name': buttonName, ...?data},
    );
  }
}