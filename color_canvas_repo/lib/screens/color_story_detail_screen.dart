import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../models/color_story.dart';
import '../models/project.dart';
import '../services/firebase_service.dart';
import '../services/project_service.dart';
import '../services/ai_service.dart';
import '../services/auth_guard.dart';
import '../services/network_utils.dart';
import '../services/ambient_audio_controller.dart';
import '../services/accessibility_service.dart';
import '../services/analytics_service.dart';
import '../widgets/usage_guide_card.dart';
import '../widgets/motion_aware_parallax.dart';
import '../widgets/contrast_coaching_widgets.dart';
import '../widgets/story_generation_progress.dart';
import '../widgets/gradient_fallback_hero.dart';
import '../utils/gradient_hero_utils.dart';
import '../screens/visualizer_screen.dart';
import '../screens/color_story_wizard_screen.dart';

class ColorStoryDetailScreen extends StatefulWidget {
  final String storyId;
  const ColorStoryDetailScreen({super.key, required this.storyId});
  @override State<ColorStoryDetailScreen> createState() => _ColorStoryDetailScreenState();
}

class _ColorStoryDetailScreenState extends State<ColorStoryDetailScreen> {
  final _player = AudioPlayer();
  bool _colorBlindOn = false;
  bool _loadingAudio = false;
  bool _isLiked = false;
  bool _isLikeLoading = false;
  bool _showTranscript = false;
  bool _wifiOnlyAssets = false;
  bool _processingTimedOut = false;
  
  // Ambient audio
  final _ambientController = AmbientLoopController();
  String _ambientAudioMode = 'off'; // 'off', 'soft', 'softer'
  bool _ambientAutoplayHintShown = false;
  
  // Motion sensitivity
  bool _reduceMotion = false;
  
  // Story ownership and visibility
  bool _isOwner = false;
  
  // Variations state
  final List<ColorStory> _variants = [];
  final Map<String, bool> _variantLoading = {};
  final Map<String, String?> _variantErrors = {};
  
  // Variation presets
  final List<Map<String, String>> _variationPresets = [
    {'id': 'cozier', 'label': 'Cozier', 'emphasis': 'cozier'},
    {'id': 'airier', 'label': 'Airier', 'emphasis': 'airier'},
    {'id': 'bold_trim', 'label': 'Bold Trim', 'emphasis': 'bold_trim'},
    {'id': 'light_ceiling', 'label': 'Light Ceiling', 'emphasis': 'light_ceiling'},
  ];

  @override void initState() {
    super.initState();
    _checkLikeStatus();
    _loadUserPreferences();
    
    // Check for processing timeout after 2 minutes
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted) {
        setState(() {
          _processingTimedOut = true;
        });
      }
    });
  }

  Future<void> _loadUserPreferences() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseService.getUserDocument(user.uid);
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          
          // Check OS-level reduce motion setting
          final osReduceMotion = await AccessibilityService.instance.isReduceMotionEnabled();
          final userReduceMotion = data['reduceMotion'] ?? false;
          
          setState(() {
            _wifiOnlyAssets = data['wifiOnlyAssets'] ?? false;
            _ambientAudioMode = data['ambientAudioMode'] ?? 'off';
            _reduceMotion = osReduceMotion || userReduceMotion;
          });
          
          // Start ambient audio if enabled
          _updateAmbientAudio();
        }
      } catch (e) {
        // Use defaults if loading fails
      }
    }
  }

  @override void dispose() { 
    _player.dispose(); 
    _ambientController.dispose();
    super.dispose(); 
  }
  
  Future<void> _checkLikeStatus() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      try {
        final liked = await FirebaseService.isColorStoryLiked(widget.storyId, user.uid);
        setState(() => _isLiked = liked);
      } catch (e) {
        // Fail silently
      }
    }
  }

  Future<void> _maybeLoadAudio(String url) async {
    if (url.isEmpty) return;
    
    // Check network policy before loading audio
    final shouldLoad = await NetworkGuard.shouldLoadHeavyAsset(
      wifiOnlyPref: _wifiOnlyAssets,
      assetKey: url,
    );
    
    if (!shouldLoad) {
      // Don't auto-load on cellular - audio will be handled by NetworkAwareAudio widget
      return;
    }
    
    setState(() => _loadingAudio = true);
    try {
      await _player.setUrl(url);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAudio = false);
      }
    }
  }

  /// Create a story variation using AI
  Future<String> _createVariant(String storyId, String emphasis) async {
    try {
      final newId = await AiService.generateVariant(storyId, emphasis: emphasis);
      return newId;
    } catch (e) {
      debugPrint('Error creating variant: $e');
      rethrow;
    }
  }
  
  /// Generate and load a story variant
  Future<void> _generateVariant(String presetId, String emphasis) async {
    setState(() {
      _variantLoading[presetId] = true;
      _variantErrors[presetId] = null;
    });
    
    try {
      // Generate variant
      final newStoryId = await _createVariant(widget.storyId, emphasis);
      
      // Fetch the new story
      final newStory = await FirebaseService.getColorStory(newStoryId);
      
      if (newStory != null) {
        setState(() {
          _variants.add(newStory);
          _variantLoading[presetId] = false;
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated ${_getPresetLabel(presetId)} variation!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to load generated story');
      }
    } catch (e) {
      setState(() {
        _variantLoading[presetId] = false;
        _variantErrors[presetId] = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating variation: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _generateVariant(presetId, emphasis),
            ),
          ),
        );
      }
    }
  }
  
  String _getPresetLabel(String presetId) {
    final preset = _variationPresets.firstWhere(
      (p) => p['id'] == presetId,
      orElse: () => {'label': 'Unknown'},
    );
    return preset['label'] ?? 'Unknown';
  }
  
  /// Apply color story to visualizer with role→surface mapping
  Future<void> _applyStoryToVisualizer(ColorStory story) async {
    // Build role→hex mapping from usage guide
    final Map<String, String> roleColors = {};
    for (final item in story.usageGuide) {
      if (item.hex.isNotEmpty) {
        roleColors[item.role.toLowerCase()] = item.hex;
      }
    }
    
    // Map roles to visualizer surfaces
    final assignments = <String, String>{};
    assignments['walls'] = roleColors['main'] ?? roleColors['primary'] ?? '#F8F8FF';
    assignments['trim'] = roleColors['trim'] ?? roleColors['door'] ?? '#FFFFFF';
    assignments['ceiling'] = roleColors['ceiling'] ?? '#FFFFFF';
    assignments['backWall'] = roleColors['accent'] ?? roleColors['feature'] ?? assignments['walls'] ?? '#F8F8FF';
    assignments['door'] = roleColors['trim'] ?? roleColors['door'] ?? '#FFFFFF';
    assignments['floor'] = roleColors['floor'] ?? '#F5F5DC';
    
    // Build assignment summary for toast
    final List<String> assignmentSummary = [];
    final roleMapping = {
      'main': 'Walls',
      'primary': 'Walls', 
      'trim': 'Trim',
      'ceiling': 'Ceiling',
      'accent': 'Back wall',
      'feature': 'Back wall',
      'door': 'Door',
      'floor': 'Floor'
    };
    
    for (final entry in roleColors.entries) {
      final surfaceName = roleMapping[entry.key];
      if (surfaceName != null) {
        assignmentSummary.add('${entry.key.toUpperCase()}→$surfaceName');
      }
    }
    
    // Navigate to visualizer with URL-safe parameters
    final encodedAssignments = Uri.encodeComponent(jsonEncode(assignments));
    
    // Update project funnel stage and get projectId first
    String? projectId;
    try {
      final projects = await ProjectService.myProjectsStream(limit: 10).first;
      final matchingProject = projects.where((p) => p.colorStoryId == story.id).firstOrNull;
      
      if (matchingProject != null) {
        projectId = matchingProject.id;
        await ProjectService.setFunnelStage(matchingProject.id, FunnelStage.visualize);
        // Track visualizer opening
        AnalyticsService.instance.logVisualizerOpenedFromStory(matchingProject.id);
      }
    } catch (e) {
      debugPrint('Failed to update project funnel stage: $e');
    }

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizerScreen(
          projectId: projectId,
          storyId: story.id,
          assignmentsParam: encodedAssignments,
          initialGuide: story.usageGuide,
        ),
        settings: RouteSettings(
          name: '/visualizer',
          arguments: {
            'storyId': story.id,
            'assignments': encodedAssignments,
            'source': 'story',
          },
        ),
      ),
    );
    
    // Show feedback toast
    if (mounted && assignmentSummary.isNotEmpty) {
      String toastMessage;
      if (assignmentSummary.length <= 3) {
        toastMessage = 'Assigned: ${assignmentSummary.join(', ')}';
      } else {
        toastMessage = 'Assigned: ${assignmentSummary.take(2).join(', ')}, +${assignmentSummary.length - 2} more';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(toastMessage),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Applied colors to visualizer'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _applyContrastSwap(String fromRole, String toRole) async {
    try {
      final user = FirebaseService.currentUser;
      if (user == null) return;

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text('Applying contrast improvement ($fromRole → $toRole)...'),
            ],
          ),
        ),
      );

      // Update the story in Firebase
      await FirebaseService.swapColorStoryRoles(widget.storyId, fromRole, toRole);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Contrast improvement applied successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Failed to apply contrast improvement'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _handleLike() async {
    final user = FirebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like stories')),
      );
      return;
    }
    
    setState(() => _isLikeLoading = true);
    
    try {
      await FirebaseService.toggleColorStoryLike(widget.storyId, user.uid);
      setState(() => _isLiked = !_isLiked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')),
        );
      }
    } finally {
      setState(() => _isLikeLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🐛 ColorStoryDetailScreen: Building with storyId = ${widget.storyId}');
    
    return StreamBuilder<ColorStory>(
      stream: FirebaseService.storyStream(widget.storyId),
      builder: (context, snap) {
        debugPrint('🐛 ColorStoryDetailScreen: StreamBuilder state = ${snap.connectionState}');
        
        if (snap.hasError) {
          debugPrint('🐛 ColorStoryDetailScreen: Stream error = ${snap.error}');
          return Scaffold(
            appBar: AppBar(title: const Text('Color Story')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error loading story', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(snap.error.toString(), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final story = snap.data;
        debugPrint('🐛 ColorStoryDetailScreen: Story data exists = ${story != null}');
        if (story != null) {
          debugPrint('🐛 ColorStoryDetailScreen: Story status = ${story.status}');
          debugPrint('🐛 ColorStoryDetailScreen: Story progress = ${story.progress}');
          debugPrint('🐛 ColorStoryDetailScreen: Story narration length = ${story.narration.length}');
          debugPrint('🐛 ColorStoryDetailScreen: Story heroImageUrl = ${story.heroImageUrl}');
          
          // Check ownership
          final currentUser = FirebaseService.currentUser;
          final isOwner = currentUser?.uid == story.ownerId;
          if (isOwner != _isOwner) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _isOwner = isOwner);
              }
            });
          }
        }
        
        if (story == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Color Story')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading your color story...', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Color Story'),
                if (_isOwner && story.access != 'private') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: story.access == 'public' 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      story.access == 'public' ? 'Public' : 'Unlisted',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: story.access == 'public'
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: _colorBlindOn ? 'Disable color-blind sim' : 'Enable color-blind sim',
                icon: Icon(_colorBlindOn ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(()=>_colorBlindOn = !_colorBlindOn),
              ),
              IconButton(
                tooltip: _isLiked ? 'Unlike story' : 'Like story',
                icon: _isLikeLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : null),
                onPressed: _isLikeLoading ? null : _handleLike,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value.startsWith('ambient_')) {
                    final mode = value.replaceAll('ambient_', '');
                    _updateAmbientAudioMode(mode);
                  } else if (value == 'wifi_toggle') {
                    _toggleWifiOnlyAssets();
                  } else if (value == 'motion_toggle') {
                    _toggleReduceMotion();
                  } else if (value.startsWith('access_')) {
                    final accessLevel = value.replaceAll('access_', '');
                    _updateStoryAccess(story, accessLevel);
                  } else if (value == 'share') {
                    _shareStory(story);
                  }
                },
                itemBuilder: (context) => [
                  // Share option (always visible for public/unlisted stories)
                  if (story.access != 'private')
                    PopupMenuItem<String>(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Share Story'),
                        ],
                      ),
                    ),
                  
                  // Visibility controls (only for owners)
                  if (_isOwner) ...[                    
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Visibility', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    PopupMenuItem<String>(
                      value: 'access_private',
                      child: Row(
                        children: [
                          Icon(
                            story.access == 'private' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Private'),
                                Text(
                                  'Only you can view',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'access_unlisted',
                      child: Row(
                        children: [
                          Icon(
                            story.access == 'unlisted' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Unlisted'),
                                Text(
                                  'Shareable with link',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'access_public',
                      child: Row(
                        children: [
                          Icon(
                            story.access == 'public' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Public'),
                                Text(
                                  'Visible in Explore',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  // Ambient audio submenu
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('Ambient Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  PopupMenuItem<String>(
                    value: 'ambient_off',
                    child: Row(
                      children: [
                        Icon(
                          _ambientAudioMode == 'off' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Off'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'ambient_soft',
                    child: Row(
                      children: [
                        Icon(
                          _ambientAudioMode == 'soft' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Soft'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'ambient_softer',
                    child: Row(
                      children: [
                        Icon(
                          _ambientAudioMode == 'softer' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Softer'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'wifi_toggle',
                    child: Row(
                      children: [
                        Icon(
                          _wifiOnlyAssets ? Icons.wifi : Icons.signal_cellular_4_bar,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_wifiOnlyAssets ? 'Wi-Fi only' : 'Allow cellular'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'motion_toggle',
                    child: Row(
                      children: [
                        Icon(
                          _reduceMotion ? Icons.motion_photos_off : Icons.motion_photos_on,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_reduceMotion ? 'Enable motion' : 'Reduce motion'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: story.status != 'complete' ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(value: story.progress > 0 && story.progress < 1 ? story.progress : null),
            ) : null,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Step-by-step progress indicator when generating
                if (story.status != 'complete')
                  StoryGenerationProgress(
                    story: story,
                    onRetryCompleted: () {
                      // The StreamBuilder will automatically update when Firestore data changes
                      // No additional action needed here
                    },
                  ),

                // Hero image with gradient fallback and parallax
                MotionAwareParallax(
                  reduceMotion: _reduceMotion,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GradientFallbackHero(
                      heroImageUrl: story.heroImageUrl.isNotEmpty ? story.heroImageUrl : null,
                      fallbackSvgDataUri: story.fallbackHero,
                      height: 280,
                      borderRadius: BorderRadius.circular(20),
                      wifiOnlyPref: _wifiOnlyAssets,
                    ),
                  ),
                ),

                // Narration section - show if story text exists OR if processing timed out
                if (story.narration.isNotEmpty || (_processingTimedOut && story.storyText.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_stories,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Color Story',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (story.room.isNotEmpty || story.style.isNotEmpty)
                                    Text(
                                      '${story.room.isNotEmpty ? story.room : ''} ${story.style.isNotEmpty ? '• ${story.style}' : ''}',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Audio controls
                        if (story.audioUrl.isNotEmpty)
                          FutureBuilder<bool>(
                            future: NetworkUtils.isWifi(),
                            builder: (c, wifiSnap) {
                              final isWifi = wifiSnap.data ?? false;
                              if (_wifiOnlyAssets && !isWifi) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: OutlinedButton.icon(
                                    onPressed: () async { 
                                      await _maybeLoadAudio(story.audioUrl); 
                                      await _player.play(); 
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text('Load Audio (Cellular)'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: FilledButton.icon(
                                  onPressed: _loadingAudio ? null : () async {
                                    if (_player.playing) { 
                                      await _player.pause(); 
                                    } else {
                                      if (_player.duration == null) await _maybeLoadAudio(story.audioUrl);
                                      await _player.play();
                                    }
                                    setState((){});
                                  },
                                  icon: _loadingAudio 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                                  label: Text(_loadingAudio ? 'Loading...' : (_player.playing ? 'Pause Audio' : 'Play Audio')),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        // Story text (use narration if available, otherwise raw story text)
                        Text(
                          story.narration.isNotEmpty ? story.narration : story.storyText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            fontSize: 17,
                          ),
                        ),
                        
                        // Show transcript toggle
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => setState(() => _showTranscript = !_showTranscript),
                          icon: Icon(_showTranscript ? Icons.visibility_off : Icons.subtitles),
                          label: Text(_showTranscript ? 'Hide Full Text' : 'Show Full Text'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Usage guide section
                if (story.usageGuide.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.palette,
                                color: Theme.of(context).colorScheme.secondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Paint Application Guide',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...story.usageGuide.map((u) {
                          final m = {
                            'role': u.role, 'hex': u.hex, 'name': u.name, 'brandName': u.brandName, 'code': u.code,
                            'surface': u.surface, 'finishRecommendation': u.finishRecommendation,
                            'sheen': u.sheen, 'howToUse': u.howToUse
                          };
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: UsageGuideCard(item: m),
                          );
                        }),
                      ],
                    ),
                  ),

                // Contrast Coaching section
                if (story.status == 'complete' && story.usageGuide.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                    ),
                    child: ContrastCoachingSection(
                      story: story,
                      onApplySwap: _applyContrastSwap,
                    ),
                  ),

                // Roll Variations section
                if (story.status == 'complete')
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.casino,
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Roll Variations',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Preset buttons
                        Row(
                          children: _variationPresets.map((preset) {
                            final presetId = preset['id']!;
                            final label = preset['label']!;
                            final emphasis = preset['emphasis']!;
                            final isLoading = _variantLoading[presetId] ?? false;
                            final hasError = _variantErrors[presetId] != null;
                            
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: preset == _variationPresets.last ? 0 : 8,
                                ),
                                child: Column(
                                  children: [
                                    OutlinedButton(
                                      onPressed: isLoading ? null : () => _generateVariant(presetId, emphasis),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(
                                          color: hasError 
                                            ? Colors.red 
                                            : Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                      child: isLoading 
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: hasError ? Colors.red : null,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                    ),
                                    if (hasError)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Icon(
                                          Icons.error_outline,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        
                        // Variants carousel
                        if (_variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _variants.length,
                              itemBuilder: (context, index) {
                                final variant = _variants[index];
                                return _buildVariantCard(variant, index);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Action buttons
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    children: [
                      // Primary action
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _applyStoryToVisualizer(story),
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Apply to Visualizer'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Secondary actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openRemixWizard(story),
                              icon: const Icon(Icons.tune),
                              label: const Text('Remix'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (story.access != 'private') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareStory(story),
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildVariantCard(ColorStory variant, int index) {
    return Container(
      width: 100,
      margin: EdgeInsets.only(right: index < _variants.length - 1 ? 12 : 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ColorStoryDetailScreen(storyId: variant.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: variant.heroImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: variant.heroImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildGradientFallback(variant),
                      errorWidget: (_, __, ___) => _buildGradientFallback(variant),
                    )
                  : _buildGradientFallback(variant),
              ),
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              _getVariantLabel(variant),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGradientFallback(ColorStory variant) {
    // Extract colors from usage guide for gradient
    String firstColor = '#6366F1';
    String secondColor = '#8B5CF6';
    
    if (variant.usageGuide.isNotEmpty) {
      final validColors = variant.usageGuide
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
          size: 24,
        ),
      ),
    );
  }
  
  String _getVariantLabel(ColorStory variant) {
    // Try to determine which preset this variant came from based on story content
    // For now, use a simple index-based approach
    final variantIndex = _variants.indexOf(variant);
    if (variantIndex >= 0 && variantIndex < _variationPresets.length) {
      return _variationPresets[variantIndex]['label'] ?? 'Variation ${variantIndex + 1}';
    }
    return 'Variation ${variantIndex + 1}';
  }
  
  /// Toggle Wi-Fi only assets preference
  Future<void> _toggleWifiOnlyAssets() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    try {
      final newValue = !_wifiOnlyAssets;
      await FirebaseService.updateUserColorStoryPreferences(
        uid: user.uid,
        autoPlayStoryAudio: false, // Keep existing values
        reduceMotion: false,
        wifiOnlyAssets: newValue,
        defaultStoryVisibility: 'private',
      );
      
      setState(() => _wifiOnlyAssets = newValue);
      
      // Update ambient audio based on new Wi-Fi preference
      await _updateAmbientAudio();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Media streaming limited to Wi-Fi' : 'Media streaming allowed on cellular'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating preference: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Update ambient audio based on current preferences and network status
  Future<void> _updateAmbientAudio() async {
    if (_ambientAudioMode == 'off') {
      await _ambientController.stop();
      return;
    }
    
    // Check network status if Wi-Fi only is enabled
    if (_wifiOnlyAssets) {
      final isWifi = await NetworkUtils.isWifi();
      if (!isWifi) {
        await _ambientController.stop();
        return;
      }
    }
    
    // Determine gain level
    double gain;
    switch (_ambientAudioMode) {
      case 'soft':
        gain = 0.4;
        break;
      case 'softer':
        gain = 0.2;
        break;
      default:
        return;
    }
    
    // Use a default ambient loop URL - in production this would come from the story
    const ambientUrl = 'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav';
    await _ambientController.start(ambientUrl, gain);
    
    // Show hint if autoplay was blocked
    if (_ambientController.isAutoplayBlocked && !_ambientAutoplayHintShown) {
      _showAutoplayHint();
    }
  }
  
  /// Show hint when autoplay is blocked
  void _showAutoplayHint() {
    if (mounted) {
      setState(() => _ambientAutoplayHintShown = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap play to enable ambient audio'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Play',
            onPressed: () => _ambientController.manualPlay(),
          ),
        ),
      );
    }
  }
  
  /// Update ambient audio preference
  Future<void> _updateAmbientAudioMode(String mode) async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseService.updateAmbientAudioPreference(
        uid: user.uid,
        ambientAudioMode: mode,
      );
      
      setState(() => _ambientAudioMode = mode);
      await _updateAmbientAudio();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ambient audio set to ${mode.replaceFirst(mode[0], mode[0].toUpperCase())}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating audio preference: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Open remix wizard with original story inputs
  Future<void> _openRemixWizard(ColorStory story) async {
    try {
      // Ensure user is signed in before creating project
      await AuthGuard.ensureSignedIn(context);
      
      // Create a new project for the remix
      final project = await ProjectService.create(
        title: story.room.isNotEmpty && story.style.isNotEmpty 
          ? '${story.room} ${story.style} Story (Remix)'
          : 'Color Story (Remix)',
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ColorStoryWizardScreen(
              projectId: project.id,
              remixStoryId: story.id,
            ),
          ),
        );
        
        AnalyticsService.instance.logStartFromExplore(story.id, project.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to remix color stories')),
        );
      }
    }
  }
  
  /// Update story visibility/access level
  Future<void> _updateStoryAccess(ColorStory story, String newAccess) async {
    try {
      await FirebaseService.updateColorStoryAccess(
        storyId: story.id,
        access: newAccess,
      );
      
      if (mounted) {
        String statusText;
        switch (newAccess) {
          case 'private':
            statusText = 'Story is now private';
            break;
          case 'unlisted':
            statusText = 'Story is now unlisted (shareable with link)';
            break;
          case 'public':
            statusText = 'Story is now public';
            break;
          default:
            statusText = 'Visibility updated';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusText),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Track visibility change
        AnalyticsService.instance.logEvent('story_visibility_changed', {
          'story_id': story.id,
          'old_access': story.access,
          'new_access': newAccess,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating visibility: \$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Share the color story
  Future<void> _shareStory(ColorStory story) async {
    try {
      // Generate share title from palette name or first two colors
      String shareTitle;
      if (story.usageGuide.isNotEmpty) {
        // Use first main and accent color names
        final mainColors = story.usageGuide.where((item) => item.role.toLowerCase().contains('main'));
        final accentColors = story.usageGuide.where((item) => item.role.toLowerCase().contains('accent'));
        final mainColor = mainColors.isNotEmpty ? mainColors.first.name : null;
        final accentColor = accentColors.isNotEmpty ? accentColors.first.name : null;
        
        if (mainColor != null && accentColor != null) {
          shareTitle = 'Color Story: \$mainColor & \$accentColor';
        } else {
          final colors = story.usageGuide.take(2).map((item) => item.name).join(' & ');
          shareTitle = 'Color Story: \$colors';
        }
      } else {
        shareTitle = 'Color Story: Beautiful Color Palette';
      }
      
      // Create excerpt from narration (first 140 chars)
      String excerpt = '';
      if (story.narration.isNotEmpty) {
        excerpt = story.narration.length > 140 
          ? '\${story.narration.substring(0, 137)}...' 
          : story.narration;
      } else if (story.storyText.isNotEmpty) {
        excerpt = story.storyText.length > 140
          ? '\${story.storyText.substring(0, 137)}...'
          : story.storyText;
      } else {
        excerpt = 'Discover this beautiful color palette and story.';
      }
      
      // Create share text with room and style context
      String contextInfo = '';
      if (story.room.isNotEmpty && story.style.isNotEmpty) {
        contextInfo = '\n\n\${story.style.toUpperCase()} \${story.room.toUpperCase()}';
      }
      
      final shareText = '\$shareTitle\$contextInfo\n\n\$excerpt\n\n🎨 View this color story: https://colorcanvas.app/story/\${story.id}';
      
      // Share the story
      await Share.share(
        shareText,
        subject: shareTitle,
      );
      
      // Update project funnel stage to share
      try {
        final projects = await ProjectService.myProjectsStream(limit: 10).first;
        final matchingProject = projects.where((p) => p.colorStoryId == story.id).firstOrNull;
        
        if (matchingProject != null) {
          await ProjectService.setFunnelStage(matchingProject.id, FunnelStage.share);
          // Track export/share with project ID
          AnalyticsService.instance.logExportShared(matchingProject.id);
        }
      } catch (e) {
        debugPrint('Failed to update project funnel stage for share: $e');
      }
      
      // Track story share
      AnalyticsService.instance.logEvent('story_shared', {
        'story_id': story.id,
        'access_level': story.access,
        'has_hero_image': story.heroImageUrl.isNotEmpty,
        'share_source': 'detail_screen',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing story: \$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Toggle reduce motion preference
  Future<void> _toggleReduceMotion() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    try {
      // Get current user preferences to preserve other values
      final doc = await FirebaseService.getUserDocument(user.uid);
      final data = doc.exists ? (doc.data() as Map<String, dynamic>? ?? {}) : <String, dynamic>{};
      
      final newValue = !_reduceMotion;
      await FirebaseService.updateUserColorStoryPreferences(
        uid: user.uid,
        autoPlayStoryAudio: data['autoPlayStoryAudio'] ?? false,
        reduceMotion: newValue,
        wifiOnlyAssets: data['wifiOnlyAssets'] ?? false,
        defaultStoryVisibility: data['defaultStoryVisibility'] ?? 'private',
        ambientAudioMode: data['ambientAudioMode'] ?? 'off',
      );
      
      // Check OS-level reduce motion setting and combine with user preference
      final osReduceMotion = await AccessibilityService.instance.isReduceMotionEnabled();
      setState(() => _reduceMotion = osReduceMotion || newValue);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Motion effects disabled' : 'Motion effects enabled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating motion preference: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}