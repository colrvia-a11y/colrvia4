import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/utils/palette_generator.dart';

class FeaturesScreen extends StatefulWidget {
  final RollerScreenStatePublic rollerState;
  final List<Paint> currentPalette;
  final List<Brand> availableBrands;
  final Set<String> selectedBrandIds;
  final HarmonyMode currentMode;
  final bool diversifyBrands;
  final int paletteSize;
  final Function(Set<String>) onBrandsChanged;
  final Function(HarmonyMode) onHarmonyModeChanged;
  final Function(bool) onDiversifyBrandsChanged;
  final Function(int) onPaletteSizeChanged;
  final VoidCallback onSavePalette;

  const FeaturesScreen({
    super.key,
    required this.rollerState,
    required this.currentPalette,
    required this.availableBrands,
    required this.selectedBrandIds,
    required this.currentMode,
    required this.diversifyBrands,
    required this.paletteSize,
    required this.onBrandsChanged,
    required this.onHarmonyModeChanged,
    required this.onDiversifyBrandsChanged,
    required this.onPaletteSizeChanged,
    required this.onSavePalette,
  });

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<String> _featureTabs = ['Sort', 'Style', 'Adjust', 'Save'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _featureTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Features',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _featureTabs.map((feature) => Tab(text: feature)).toList(),
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withOpacity( 0.6),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSortTab(),
          _buildStyleTab(),
          _buildAdjustTab(),
          _buildSaveTab(),
        ],
      ),
    );
  }

  Widget _buildSortTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Brand Selection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which paint brands to include in your palette generation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity( 0.7),
                ),
          ),
          const SizedBox(height: 32),
          
          // Current Selection Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity( 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity( 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.selectedBrandIds.length} of ${widget.availableBrands.length} brands selected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Provide immediate feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected all ${widget.availableBrands.length} brands'),
                        duration: const Duration(milliseconds: 1500),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    widget.onBrandsChanged(
                      widget.availableBrands.map((b) => b.id).toSet(),
                    );
                  },
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('Select All'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: widget.selectedBrandIds.length == widget.availableBrands.length
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity( 0.3)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Provide immediate feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Cleared all brand selections'),
                        duration: const Duration(milliseconds: 1500),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    widget.onBrandsChanged(<String>{});
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: widget.selectedBrandIds.isEmpty
                        ? Theme.of(context).colorScheme.errorContainer.withOpacity( 0.3)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity( 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withOpacity( 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Select Brands',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: widget.availableBrands.length,
                    itemBuilder: (context, index) {
                      final brand = widget.availableBrands[index];
                      final isSelected =
                          widget.selectedBrandIds.contains(brand.id);
                      return CheckboxListTile(
                        title: Text(
                          brand.name,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          // Provide immediate feedback for individual selections
                          if (value == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${brand.name}'),
                                duration: const Duration(milliseconds: 1000),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed ${brand.name}'),
                                duration: const Duration(milliseconds: 1000),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                          
                          final newSelectedBrands = Set<String>.from(
                            widget.selectedBrandIds,
                          );
                          if (value == true) {
                            newSelectedBrands.add(brand.id);
                          } else {
                            newSelectedBrands.remove(brand.id);
                          }
                          widget.onBrandsChanged(newSelectedBrands);
                        },
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: isSelected
                            ? Theme.of(
                                context,
                              )
                                .colorScheme
                                .primaryContainer
                                .withOpacity( 0.3)
                            : Colors.transparent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStyleTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harmony Mode',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how colors in your palette relate to each other',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity( 0.7),
                ),
          ),
          const SizedBox(height: 32),

          // Current Harmony Mode
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity( 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity( 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Mode',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity( 0.6),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getHarmonyModeDisplayName(widget.currentMode),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getHarmonyModeDescription(widget.currentMode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity( 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Harmony Mode Options
          ...HarmonyMode.values.map((mode) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HarmonyModeOption(
                  mode: mode,
                  isSelected: mode == widget.currentMode,
                  onSelected: () => widget.onHarmonyModeChanged(mode),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAdjustTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Palette Size',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the number of colors in your palette (1-5 colors)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity( 0.7),
                ),
          ),
          const SizedBox(height: 32),

          // Current Size Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity( 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withOpacity( 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.paletteSize} Colors',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current palette size',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity( 0.6),
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Size Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.paletteSize > 1
                      ? () =>
                          widget.onPaletteSizeChanged(widget.paletteSize - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove Color'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.paletteSize < 5
                      ? () =>
                          widget.onPaletteSizeChanged(widget.paletteSize + 1)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Color'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Size Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity( 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (index) {
                    final isActive = index < widget.paletteSize;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                        height: 40,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (index < widget.currentPalette.length
                                  ? Color(int.parse(
                                          widget.currentPalette[index].hex
                                              .substring(1),
                                          radix: 16) +
                                      0xFF000000)
                                  : Theme.of(context).colorScheme.primary)
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity( 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? null
                              : Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity( 0.3),
                                  style: BorderStyle.solid,
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save Palette',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your current palette to your library for future use',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity( 0.7),
                ),
          ),
          const SizedBox(height: 32),

          // Current Palette Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity( 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withOpacity( 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Palette',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                if (widget.currentPalette.isNotEmpty) ...[
                  Row(
                    children: widget.currentPalette
                        .map((paint) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(paint.hex.substring(1),
                                          radix: 16) +
                                      0xFF000000),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.currentPalette.length} colors • ${_getHarmonyModeDisplayName(widget.currentMode)} harmony',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity( 0.6),
                        ),
                  ),
                ] else ...[
                  Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity( 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No palette generated yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity( 0.5),
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.currentPalette.isNotEmpty
                  ? widget.onSavePalette
                  : null,
              icon: const Icon(Icons.save),
              label: const Text('Save to Library'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (widget.currentPalette.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Generate a palette first to save it',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity( 0.5),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getHarmonyModeDisplayName(HarmonyMode mode) {
    switch (mode) {
      case HarmonyMode.neutral:
        return 'Neutral';
      case HarmonyMode.analogous:
        return 'Analogous';
      case HarmonyMode.complementary:
        return 'Complementary';
      case HarmonyMode.triad:
        return 'Triad';
      case HarmonyMode.designer:
        return 'Designer';
    }
  }

  String _getHarmonyModeDescription(HarmonyMode mode) {
    switch (mode) {
      case HarmonyMode.neutral:
        return 'Calm, balanced colors that work well together';
      case HarmonyMode.analogous:
        return 'Colors that are next to each other on the color wheel';
      case HarmonyMode.complementary:
        return 'Opposite colors that create vibrant contrast';
      case HarmonyMode.triad:
        return 'Three colors equally spaced on the color wheel';
      case HarmonyMode.designer:
        return 'Professional curated color combinations';
    }
  }
}

class _HarmonyModeOption extends StatelessWidget {
  final HarmonyMode mode;
  final bool isSelected;
  final VoidCallback onSelected;

  const _HarmonyModeOption({
    required this.mode,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity( 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity( 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity( 0.5),
                        width: 2,
                      ),
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayName(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDescription(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity( 0.7)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity( 0.6),
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

  String _getDisplayName() {
    switch (mode) {
      case HarmonyMode.neutral:
        return 'Neutral';
      case HarmonyMode.analogous:
        return 'Analogous';
      case HarmonyMode.complementary:
        return 'Complementary';
      case HarmonyMode.triad:
        return 'Triad';
      case HarmonyMode.designer:
        return 'Designer';
    }
  }

  String _getDescription() {
    switch (mode) {
      case HarmonyMode.neutral:
        return 'Calm, balanced colors that work well together';
      case HarmonyMode.analogous:
        return 'Colors that are next to each other on the color wheel';
      case HarmonyMode.complementary:
        return 'Opposite colors that create vibrant contrast';
      case HarmonyMode.triad:
        return 'Three colors equally spaced on the color wheel';
      case HarmonyMode.designer:
        return 'Professional curated color combinations';
    }
  }
}
