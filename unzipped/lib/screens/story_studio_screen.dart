import 'package:flutter/material.dart' hide Paint;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/utils/slug_utils.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/data/sample_paints.dart';
import 'package:color_canvas/utils/color_utils.dart';

class StoryStudioScreen extends StatefulWidget {
  const StoryStudioScreen({super.key});

  @override
  State<StoryStudioScreen> createState() => _StoryStudioScreenState();
}

class _StoryStudioScreenState extends State<StoryStudioScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Form data
  String _title = '';
  String _slug = '';
  String _description = '';
  Set<String> _selectedThemes = {};
  Set<String> _selectedFamilies = {};
  Set<String> _selectedRooms = {};
  List<String> _tags = [];
  File? _heroImage;
  String _heroImageUrl = '';
  
  // Palette data
  List<PaletteEntry> _selectedColors = [];
  List<Paint> _availablePaints = [];
  List<Paint> _filteredPaints = [];
  String _paintSearchQuery = '';
  String? _selectedBrand;
  
  // UI state
  int _currentStep = 0;
  bool _isAutoSlug = true;
  bool _isLoading = false;
  bool _isFeatured = false;
  bool _isPublished = false;
  String? _publishedStoryId;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _paintSearchController = TextEditingController();

  // Controlled lists (loaded dynamically from Firestore)
  List<String> _availableThemes = [];
  List<String> _availableFamilies = [];
  List<String> _availableRooms = [];
  bool _taxonomiesLoading = true;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    _paintSearchController.addListener(_onPaintSearchChanged);
    _loadTaxonomies();
    _loadPaintData();
  }

  Future<void> _loadTaxonomies() async {
    try {
      final taxonomies = await FirebaseService.getTaxonomyOptions();
      setState(() {
        _availableThemes = taxonomies['themes'] ?? [];
        _availableFamilies = taxonomies['families'] ?? [];
        _availableRooms = taxonomies['rooms'] ?? [];
        _taxonomiesLoading = false;
      });
    } catch (e) {
      // Use defaults on error
      setState(() {
        _availableThemes = ['Modern', 'Traditional', 'Contemporary', 'Minimalist', 'Rustic', 'Coastal'];
        _availableFamilies = ['Neutrals', 'Warm Neutrals', 'Cool Neutrals', 'Greens', 'Blues', 'Earth Tones'];
        _availableRooms = ['Living Room', 'Bedroom', 'Kitchen', 'Bathroom', 'Dining Room', 'Home Office'];
        _taxonomiesLoading = false;
      });
    }
  }

  void _onTitleChanged() {
    if (_isAutoSlug && _titleController.text != _title) {
      setState(() {
        _title = _titleController.text;
        _slug = SlugUtils.brandSlug(_title);
        _slugController.text = _slug;
      });
    }
  }

  void _onSlugChanged(String value) {
    setState(() {
      _slug = value;
      _isAutoSlug = false;
    });
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0: // Foundation
        return _title.trim().length >= 3 &&
               _slug.trim().isNotEmpty &&
               _description.trim().length >= 20 &&
               _selectedThemes.isNotEmpty &&
               _selectedFamilies.isNotEmpty &&
               _selectedRooms.isNotEmpty;
      case 1: // Palette
        return _selectedColors.length >= 2 && _hasMainAndTrim();
      case 2: // Preview
        return _canPublish();
      default:
        return false;
    }
  }
  
  bool _canPublish() {
    // At least 3 colors chosen, roles assigned, main + trim present
    if (_selectedColors.length < 3) return false;
    if (!_hasMainAndTrim()) return false;
    
    // Text contrast validation
    for (final entry in _selectedColors) {
      if (!_hasReadableContrast(entry.paint)) {
        return false;
      }
    }
    
    // Title and description required
    if (_title.trim().isEmpty || _description.trim().isEmpty) return false;
    
    return true;
  }
  
  bool _hasReadableContrast(Paint paint) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final luminance = color.computeLuminance();
    // Simple contrast check - ensure color isn't too close to middle gray
    return luminance < 0.3 || luminance > 0.7;
  }

  void _nextStep() {
    if (!_canContinue()) return;
    
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _heroImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }
  
  Future<void> _loadPaintData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _availablePaints = await SamplePaints.getSamplePaints();
      _filteredPaints = List.from(_availablePaints);
    } catch (e) {
      print('Error loading paint data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _onPaintSearchChanged() {
    _filterPaints();
  }
  
  void _filterPaints() {
    final query = _paintSearchController.text.toLowerCase();
    setState(() {
      _filteredPaints = _availablePaints.where((paint) {
        final matchesSearch = query.isEmpty ||
            paint.name.toLowerCase().contains(query) ||
            paint.code.toLowerCase().contains(query) ||
            paint.brandName.toLowerCase().contains(query);
        final matchesBrand = _selectedBrand == null ||
            paint.brandName == _selectedBrand;
        return matchesSearch && matchesBrand;
      }).toList();
    });
  }
  
  void _addColor(Paint paint) {
    if (_selectedColors.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 6 colors allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Check for duplicates
    if (_selectedColors.any((entry) => entry.paint.id == paint.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Color already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _selectedColors.add(PaletteEntry(
        paint: paint,
        role: _selectedColors.isEmpty ? 'MAIN' : 'ACCENT',
        psychology: '',
        usageTips: '',
      ));
    });
  }
  
  void _removeColor(int index) {
    setState(() {
      _selectedColors.removeAt(index);
    });
  }
  
  void _reorderColors(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _selectedColors.removeAt(oldIndex);
      _selectedColors.insert(newIndex, item);
    });
  }
  
  void _updateColorRole(int index, String role) {
    setState(() {
      _selectedColors[index] = _selectedColors[index].copyWith(role: role);
    });
  }
  
  void _updateColorPsychology(int index, String psychology) {
    setState(() {
      _selectedColors[index] = _selectedColors[index].copyWith(psychology: psychology);
    });
  }
  
  void _updateColorUsageTips(int index, String usageTips) {
    setState(() {
      _selectedColors[index] = _selectedColors[index].copyWith(usageTips: usageTips);
    });
  }
  
  bool _hasMainAndTrim() {
    final roles = _selectedColors.map((e) => e.role).toSet();
    return roles.contains('MAIN') && roles.contains('TRIM');
  }
  
  int _getAccentCount() {
    return _selectedColors.where((e) => e.role == 'ACCENT').length;
  }
  
  bool _hasNearIdenticalColors() {
    for (int i = 0; i < _selectedColors.length; i++) {
      for (int j = i + 1; j < _selectedColors.length; j++) {
        final paint1 = _selectedColors[i].paint;
        final paint2 = _selectedColors[j].paint;
        final deltaE = ColorUtils.deltaE2000(paint1.lab, paint2.lab);
        if (deltaE < 5.0) { // Very similar colors
          return true;
        }
      }
    }
    return false;
  }
  
  void _suggestAccents() {
    final mainColor = _selectedColors.firstWhere(
      (entry) => entry.role == 'MAIN',
      orElse: () => _selectedColors.first,
    );
    
    // Generate harmonious colors using color theory
    final suggestions = _generateHarmoniousColors(mainColor.paint);
    
    if (suggestions.isNotEmpty) {
      _showAccentSuggestions(suggestions);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No accent suggestions available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  List<Paint> _generateHarmoniousColors(Paint mainPaint) {
    final lch = ColorUtils.labToLch(mainPaint.lab);
    final List<Paint> suggestions = [];
    
    // Generate complementary and triadic colors
    final targetHues = [
      (lch[2] + 60) % 360,  // Analogous
      (lch[2] - 60) % 360,  // Analogous
      (lch[2] + 180) % 360, // Complementary
      (lch[2] + 120) % 360, // Triadic
      (lch[2] - 120) % 360, // Triadic
    ];
    
    for (final targetHue in targetHues) {
      // Find paints with similar hue but different lightness/chroma
      final candidates = _availablePaints.where((paint) {
        final paintLch = ColorUtils.labToLch(paint.lab);
        final hueDiff = (paintLch[2] - targetHue).abs();
        final adjustedDiff = math.min(hueDiff, 360 - hueDiff);
        return adjustedDiff < 30 && !_selectedColors.any((e) => e.paint.id == paint.id);
      }).toList();
      
      if (candidates.isNotEmpty) {
        // Sort by lightness difference from main color
        candidates.sort((a, b) {
          final aLightnessDiff = (a.lab[0] - mainPaint.lab[0]).abs();
          final bLightnessDiff = (b.lab[0] - mainPaint.lab[0]).abs();
          return bLightnessDiff.compareTo(aLightnessDiff);
        });
        
        suggestions.addAll(candidates.take(2));
      }
    }
    
    return suggestions.take(4).toList();
  }
  
  void _showAccentSuggestions(List<Paint> suggestions) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested Accents',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on color harmony with your main color',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final paint = suggestions[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _addColor(paint);
                      },
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ColorUtils.getPaintColor(paint.hex),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    paint.name,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    paint.code,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _proceedToColorSelection() {
    // This method is no longer needed since we have the multi-step wizard
    // The navigation is handled by _nextStep()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Color Story'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          // Admin-only maintenance button
          FutureBuilder<bool>(
            future: FirebaseService.isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.admin_panel_settings),
                  onSelected: (value) {
                    if (value == 'backfill_facets') {
                      _showBackfillDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'backfill_facets',
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 20),
                          SizedBox(width: 8),
                          Text('Backfill Facets'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 3,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of 3',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      ['Foundation', 'Palette', 'Preview'][_currentStep],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildFoundationStep(),
                _buildPaletteStep(),
                _buildPreviewStep(),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canContinue() ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _currentStep == 2 ? 'Continue' : 'Continue',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundationStep() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foundation',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up the basic information for your Color Story.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Story Title *',
                hintText: 'e.g. Coastal Retreat',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Slug
            TextFormField(
              controller: _slugController,
              decoration: InputDecoration(
                labelText: 'URL Slug *',
                hintText: 'coastal-retreat',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isAutoSlug ? Icons.link : Icons.edit,
                    color: _isAutoSlug ? Colors.green : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isAutoSlug = !_isAutoSlug;
                      if (_isAutoSlug) {
                        _slug = SlugUtils.brandSlug(_title);
                        _slugController.text = _slug;
                      }
                    });
                  },
                ),
              ),
              onChanged: _onSlugChanged,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Slug is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Text(
              _isAutoSlug ? 'Auto-generated from title' : 'Manual override',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isAutoSlug ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe the mood and inspiration behind this color story...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _description = value;
                });
              },
              validator: (value) {
                if (value == null || value.trim().length < 20) {
                  return 'Description must be at least 20 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Themes
            _buildMultiSelectSection(
              'Design Themes *',
              'Choose 1-3 design styles that best describe this story',
              _availableThemes,
              _selectedThemes,
              maxSelections: 3,
            ),
            const SizedBox(height: 24),
            
            // Color Families
            _buildMultiSelectSection(
              'Color Families *',
              'Select 1-3 color families featured in this story',
              _availableFamilies,
              _selectedFamilies,
              maxSelections: 3,
            ),
            const SizedBox(height: 24),
            
            // Rooms
            _buildMultiSelectSection(
              'Room Types *',
              'Choose up to 5 rooms where this palette works well',
              _availableRooms,
              _selectedRooms,
              maxSelections: 5,
            ),
            const SizedBox(height: 24),
            
            // Tags
            _buildTagsSection(),
            const SizedBox(height: 24),
            
            // Hero Image
            _buildHeroImageSection(),
            
            const SizedBox(height: 80), // Space for navigation buttons
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectSection(
    String title,
    String description,
    List<String> options,
    Set<String> selected,
    {int maxSelections = 3}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // Show loading or options
        if (_taxonomiesLoading) ...[
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading options...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ] else if (options.isEmpty) ...[
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            child: Text(
              'No options available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              final canSelect = selected.length < maxSelections || isSelected;
              
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: canSelect ? (bool isSelectedNow) {
                  setState(() {
                    if (isSelectedNow) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  });
                } : null,
                backgroundColor: canSelect ? null : Colors.grey[100],
                disabledColor: Colors.grey[100],
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
        ],
        
        if (selected.isNotEmpty && !_taxonomiesLoading) ...[
          const SizedBox(height: 8),
          Text(
            '${selected.length}/$maxSelections selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected.isEmpty ? Colors.red : Colors.green,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add mood, season, or style keywords (optional)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  hintText: 'Add a tag...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHeroImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hero Image',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload a beautiful hero image for your story (optional)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: _heroImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _heroImage!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add hero image',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
          ),
        ),
        if (_heroImage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                'Image selected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _heroImage = null;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaletteStep() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Palette Builder',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select 3-6 colors and assign roles for your Color Story',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Row(
            children: [
              // Paint Picker Panel
              Expanded(
                flex: 2,
                child: _buildPaintPickerPanel(),
              ),
              
              // Selected Colors Panel
              Expanded(
                flex: 3,
                child: _buildSelectedColorsPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaintPickerPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Search and filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _paintSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Search colors...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Brand filter
                DropdownButtonFormField<String?>(
                  value: _selectedBrand,
                  decoration: const InputDecoration(
                    labelText: 'Brand Filter',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Brands'),
                    ),
                    ...SamplePaints.getSampleBrands().map((brand) =>
                      DropdownMenuItem(
                        value: brand.name,
                        child: Text(brand.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBrand = value;
                    });
                    _filterPaints();
                  },
                ),
              ],
            ),
          ),
          
          // Paint grid
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _filteredPaints.length,
                  itemBuilder: (context, index) {
                    final paint = _filteredPaints[index];
                    final isSelected = _selectedColors.any((e) => e.paint.id == paint.id);
                    
                    return GestureDetector(
                      onTap: isSelected ? null : () => _addColor(paint),
                      child: Card(
                        elevation: isSelected ? 0 : 2,
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ColorUtils.getPaintColor(paint.hex),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          paint.name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          paint.code,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          paint.brandName,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity( 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectedColorsPanel() {
    return Column(
      children: [
        // Header with add button and smart assists
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected Colors (${_selectedColors.length}/6)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectedColors.length < 6 ? () {
                      // Focus search field
                      FocusScope.of(context).requestFocus(FocusNode());
                    } : null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Color'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Smart assists
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectedColors.isNotEmpty ? _suggestAccents : null,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Suggest Accents'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Warning badges
        if (_selectedColors.isNotEmpty) ..._buildWarningBadges(),
        
        // Selected colors list
        Expanded(
          child: _selectedColors.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No colors selected',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search and tap colors from the left panel to add them',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedColors.length,
                onReorder: _reorderColors,
                itemBuilder: (context, index) {
                  final entry = _selectedColors[index];
                  return _buildColorEntryCard(entry, index);
                },
              ),
        ),
      ],
    );
  }
  
  List<Widget> _buildWarningBadges() {
    final warnings = <Widget>[];
    
    if (!_hasMainAndTrim()) {
      warnings.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Requires at least MAIN and TRIM colors',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_getAccentCount() > 3) {
      warnings.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border.all(color: Colors.orange[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Warning: More than 3 accent colors',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_hasNearIdenticalColors()) {
      warnings.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border.all(color: Colors.orange[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Warning: Some colors are very similar',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return warnings;
  }
  
  Widget _buildColorEntryCard(PaletteEntry entry, int index) {
    return Card(
      key: ValueKey(entry.paint.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color info row
            Row(
              children: [
                // Color swatch
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: ColorUtils.getPaintColor(entry.paint.hex),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Paint details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.paint.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.paint.brandName} • ${entry.paint.code}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Role dropdown
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    value: entry.role,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MAIN', child: Text('MAIN')),
                      DropdownMenuItem(value: 'TRIM', child: Text('TRIM')),
                      DropdownMenuItem(value: 'ACCENT', child: Text('ACCENT')),
                      DropdownMenuItem(value: 'BACKGROUND', child: Text('BACKGROUND')),
                    ],
                    onChanged: (value) {
                      if (value != null) _updateColorRole(index, value);
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Remove button
                IconButton(
                  onPressed: () => _removeColor(index),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Psychology field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Psychology',
                hintText: 'e.g., Calming, energizing, sophisticated...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => _updateColorPsychology(index, value),
              maxLength: 50,
            ),
            
            const SizedBox(height: 8),
            
            // Usage tips field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Usage Tips',
                hintText: 'How to use: Perfect for accent walls, trim work...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => _updateColorUsageTips(index, value),
              maxLength: 100,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep() {
    if (_isPublished) {
      return _buildPostPublishView();
    }
    
    return Column(
      children: [
        // Header with validation status
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview & Publish',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Final checks before publishing your Color Story',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Featured toggle
                  Column(
                    children: [
                      Switch(
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                      ),
                      Text(
                        'Featured',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Validation checks
              ..._buildValidationChecks(),
            ],
          ),
        ),
        
        // Preview content - exact replica of Color Story detail view
        Expanded(
          child: _buildStoryPreview(),
        ),
        
        // Publish controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity( 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _canPublish() && !_isLoading ? _publishStory : null,
                icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
                label: Text(_isLoading ? 'Publishing...' : 'Publish Color Story'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _saveAsDraft,
                icon: const Icon(Icons.drafts),
                label: const Text('Save as Draft'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  List<Widget> _buildValidationChecks() {
    final checks = <Widget>[];
    
    // Color count check
    final colorCountCheck = _selectedColors.length >= 3;
    checks.add(_buildCheckItem(
      'At least 3 colors chosen',
      colorCountCheck,
      '${_selectedColors.length}/3 colors selected',
    ));
    
    // Roles check
    final rolesCheck = _hasMainAndTrim();
    checks.add(_buildCheckItem(
      'Main and trim roles assigned',
      rolesCheck,
      rolesCheck ? 'All required roles set' : 'Missing main or trim role',
    ));
    
    // Text contrast check
    bool allContrastsGood = true;
    for (final entry in _selectedColors) {
      if (!_hasReadableContrast(entry.paint)) {
        allContrastsGood = false;
        break;
      }
    }
    checks.add(_buildCheckItem(
      'Text contrast readable on all swatches',
      allContrastsGood,
      allContrastsGood ? 'All colors have good contrast' : 'Some colors may be hard to read',
    ));
    
    // Hero image check
    final heroCheck = _heroImage != null;
    checks.add(_buildCheckItem(
      'Hero image set',
      heroCheck,
      heroCheck ? 'Hero image uploaded' : 'No hero image (optional)',
      isWarning: !heroCheck,
    ));
    
    return checks;
  }
  
  Widget _buildCheckItem(String title, bool isValid, String subtitle, {bool isWarning = false}) {
    final color = isValid ? Colors.green : (isWarning ? Colors.orange : Colors.red);
    final icon = isValid ? Icons.check_circle : (isWarning ? Icons.warning : Icons.error);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.1),
        border: Border.all(color: color.withOpacity( 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withOpacity( 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPreview() {
    final backgroundColor = const Color(0xFFF8F9FA);
    final textColor = Colors.black87;
    
    return Container(
      color: backgroundColor,
      child: CustomScrollView(
        slivers: [
          // Hero Header (like Color Story Detail)
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: false,
            automaticallyImplyLeading: false,
            backgroundColor: backgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _title.isEmpty ? 'Untitled Story' : _title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.white.withOpacity( 0.8),
                    ),
                  ],
                ),
              ),
              background: _heroImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        _heroImage!,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity( 0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    decoration: _selectedColors.isNotEmpty
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ColorUtils.getPaintColor(_selectedColors.first.paint.hex),
                              ColorUtils.getPaintColor(_selectedColors.last.paint.hex),
                            ],
                          ),
                        )
                      : BoxDecoration(
                          color: Colors.grey[300],
                        ),
                  ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildListDelegate([
              // Description
              if (_description.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      height: 1.6,
                      fontSize: 16,
                    ),
                  ),
                ),
              
              // Color Reveal Cards (like in Color Story Detail)
              ..._selectedColors.map((entry) => _buildPreviewColorCard(entry, textColor)).toList(),
              
              // CTA Section Preview
              Container(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    
                    // Use This Color Story Button (preview only)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.palette),
                        label: const Text('Use This Color Story'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor.withOpacity( 0.5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Secondary Actions (preview only)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.bookmark_outline),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: textColor.withOpacity( 0.5),
                              side: BorderSide(color: textColor.withOpacity( 0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: textColor.withOpacity( 0.5),
                              side: BorderSide(color: textColor.withOpacity( 0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewColorCard(PaletteEntry entry, Color textColor) {
    final swatchColor = ColorUtils.getPaintColor(entry.paint.hex);
    final cardTextColor = _getCardTextColor(swatchColor);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity( 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color Swatch Block
            Container(
              height: 120,
              color: swatchColor,
              child: Stack(
                children: [
                  // Gradient overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          cardTextColor == Colors.white 
                              ? Colors.black.withOpacity( 0.3)
                              : Colors.white.withOpacity( 0.3),
                        ],
                      ),
                    ),
                  ),
                  
                  // Color Info Overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.role.toUpperCase(),
                          style: TextStyle(
                            color: cardTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.paint.name,
                          style: TextStyle(
                            color: cardTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${entry.paint.brandName} • ${entry.paint.code}',
                          style: TextStyle(
                            color: cardTextColor.withOpacity( 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Section
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Psychology Snippet
                  if (entry.psychology.isNotEmpty) ...[
                    Text(
                      entry.psychology,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Usage Tips
                  if (entry.usageTips.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: 'How to use: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          TextSpan(text: entry.usageTips),
                        ],
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
  
  Color _getCardTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
  
  Widget _buildPostPublishView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green[600],
          ),
          const SizedBox(height: 24),
          Text(
            'Color Story Published!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '"${_title}" has been successfully published and is now available in the Explore section.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
          
          // Action buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _viewInExplore,
                icon: const Icon(Icons.explore),
                label: const Text('View in Explore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _createAnother,
                icon: const Icon(Icons.add),
                label: const Text('Create Another Story'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveAsDraft() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Convert palette entries to ColorStoryPalette objects
      final palette = _selectedColors.map((entry) => ColorStoryPalette(
        role: entry.role,
        hex: entry.paint.hex,
        paintId: entry.paint.id,
        brandName: entry.paint.brandName,
        name: entry.paint.name,
        code: entry.paint.code,
        psychology: entry.psychology,
        usageTips: entry.usageTips,
      )).toList();
      
      // Upload hero image if present
      String? heroImageUrl;
      if (_heroImage != null) {
        // For now, we'll use a placeholder URL
        // In a real implementation, you'd upload to Firebase Storage
        heroImageUrl = 'https://via.placeholder.com/800x400';
      }
      
      // Build facets for efficient querying
      final facets = ColorStory.buildFacets(
        themes: _selectedThemes.toList(),
        families: _selectedFamilies.toList(),
        rooms: _selectedRooms.toList(),
      );
      
      // Create the ColorStory object
      final userId = FirebaseService.currentUser?.uid ?? '';
      final colorStory = ColorStory(
        id: '', // Will be set by Firestore
        userId: userId,
        title: _title,
        slug: _slug,
        heroImageUrl: heroImageUrl ?? '',
        themes: _selectedThemes.toList(),
        families: _selectedFamilies.toList(),
        rooms: _selectedRooms.toList(),
        tags: _tags,
        description: _description,
        palette: palette,
        isFeatured: _isFeatured,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        facets: facets,
      );
      
      // Save to Firestore (this will save as draft with timestamps)
      await FirebaseService.createColorStory(colorStory);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Color Story saved as draft'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildStep3PreviewAndPublish() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publish Story',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Color Story is ready to be published!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Story Ready',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSummaryRow('Title', _title.isEmpty ? 'Untitled' : _title),
                  _buildSummaryRow('Slug', _slug.isEmpty ? 'untitled' : _slug),
                  _buildSummaryRow('Themes', _selectedThemes.join(', ')),
                  _buildSummaryRow('Families', _selectedFamilies.join(', ')),
                  _buildSummaryRow('Rooms', _selectedRooms.join(', ')),
                  _buildSummaryRow('Colors', '${_selectedColors.length} selected'),
                  if (_heroImage != null)
                    _buildSummaryRow('Hero Image', 'Uploaded'),
                  if (_tags.isNotEmpty)
                    _buildSummaryRow('Tags', _tags.join(', ')),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishStory,
                icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
                label: Text(_isLoading ? 'Publishing...' : 'Publish Color Story'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () {
                  // Save as draft functionality could go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Draft saving coming soon!'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: const Icon(Icons.drafts),
                label: const Text('Save as Draft'),
              ),
            ],
          ),
          
          const SizedBox(height: 80), // Space for navigation buttons
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey[500] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  
  Future<void> _publishStory() async {
    if (!_canPublish()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all validations before publishing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Convert palette entries to ColorStoryPalette objects
      final palette = _selectedColors.map((entry) => ColorStoryPalette(
        role: entry.role,
        hex: entry.paint.hex,
        paintId: entry.paint.id,
        brandName: entry.paint.brandName,
        name: entry.paint.name,
        code: entry.paint.code,
        psychology: entry.psychology,
        usageTips: entry.usageTips,
      )).toList();
      
      // Upload hero image if present
      String? heroImageUrl;
      if (_heroImage != null) {
        // For now, we'll use a placeholder URL
        // In a real implementation, you'd upload to Firebase Storage
        heroImageUrl = 'https://via.placeholder.com/800x400';
      }
      
      // Build facets for efficient querying
      final facets = ColorStory.buildFacets(
        themes: _selectedThemes.toList(),
        families: _selectedFamilies.toList(),
        rooms: _selectedRooms.toList(),
      );
      
      // Create the ColorStory object
      final userId = FirebaseService.currentUser?.uid ?? '';
      final colorStory = ColorStory(
        id: '', // Will be set by Firestore
        userId: userId,
        title: _title,
        slug: _slug,
        heroImageUrl: heroImageUrl ?? '',
        themes: _selectedThemes.toList(),
        families: _selectedFamilies.toList(),
        rooms: _selectedRooms.toList(),
        tags: _tags,
        description: _description,
        palette: palette,
        isFeatured: _isFeatured,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        facets: facets,
      );
      
      // Save to Firestore
      final storyId = await FirebaseService.createColorStory(colorStory);
      _publishedStoryId = storyId;
      
      // Show success and switch to post-publish view
      if (mounted) {
        setState(() {
          _isPublished = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _viewInExplore() {
    // Navigate to explore screen
    Navigator.of(context).popUntil((route) => route.isFirst);
    // TODO: Navigate to specific story in explore
  }
  
  void _createAnother() {
    // Reset all form data and go back to step 0
    setState(() {
      _currentStep = 0;
      _title = '';
      _slug = '';
      _description = '';
      _selectedThemes.clear();
      _selectedFamilies.clear();
      _selectedRooms.clear();
      _tags.clear();
      _heroImage = null;
      _heroImageUrl = '';
      _selectedColors.clear();
      _isAutoSlug = true;
      _isFeatured = false;
      _isPublished = false;
      _publishedStoryId = null;
      
      _titleController.clear();
      _slugController.clear();
      _descriptionController.clear();
      _tagController.clear();
      _paintSearchController.clear();
    });
    
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showBackfillDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backfill Facets'),
        content: const Text(
          'This will update all existing Color Stories to include the new facets field for improved filtering. This is a one-time maintenance operation.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _runBackfillFacets();
            },
            child: const Text('Backfill'),
          ),
        ],
      ),
    );
  }

  Future<void> _runBackfillFacets() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Backfilling facets...')),
          ],
        ),
      ),
    );

    try {
      final result = await FirebaseService.backfillColorStoryFacets();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show results dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              result['success'] ? 'Backfill Complete' : 'Backfill Failed',
              style: TextStyle(
                color: result['success'] ? Colors.green : Colors.red,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result['success']) ...[
                  Text('✅ Processed: ${result['processedCount']} stories'),
                  Text('✅ Updated: ${result['updatedCount']} stories'),
                  if (result['errorCount'] > 0)
                    Text('⚠️ Errors: ${result['errorCount']} stories'),
                ] else ...[
                  Text('❌ Error: ${result['error']}'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backfill failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _paintSearchController.dispose();
    super.dispose();
  }
}

// Helper class for palette entries
class PaletteEntry {
  final Paint paint;
  final String role;
  final String psychology;
  final String usageTips;
  
  PaletteEntry({
    required this.paint,
    required this.role,
    required this.psychology,
    required this.usageTips,
  });
  
  PaletteEntry copyWith({
    Paint? paint,
    String? role,
    String? psychology,
    String? usageTips,
  }) {
    return PaletteEntry(
      paint: paint ?? this.paint,
      role: role ?? this.role,
      psychology: psychology ?? this.psychology,
      usageTips: usageTips ?? this.usageTips,
    );
  }
}