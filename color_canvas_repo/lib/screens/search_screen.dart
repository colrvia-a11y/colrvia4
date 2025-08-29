import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/screens/home_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final void Function(Paint)? onPaintSelected;
  
  const SearchScreen({super.key, this.initialQuery, this.onPaintSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Paint> _searchResults = [];
  List<Brand> _brands = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
    _loadBrands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    try {
      final brands = await FirebaseService.getAllBrands();
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading brands: $e')),
        );
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await FirebaseService.searchPaints(query.trim());
      
      // Filter by brand if selected
      final filteredResults = _selectedBrand != null
          ? results.where((paint) => paint.brandName == _selectedBrand).toList()
          : results;
      
      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _selectPaint(Paint paint) {
    if (widget.onPaintSelected != null) {
      widget.onPaintSelected!(paint);
      return;
    }
    
    // Find the HomeScreen in the widget tree and notify it of the paint selection
    HomeScreenPaintSelection? homeScreen;
    
    // Walk up the widget tree to find the HomeScreen state
    context.visitAncestorElements((element) {
      if (element.widget is HomeScreen) {
        final state = (element as StatefulElement).state;
        if (state is HomeScreenPaintSelection) {
          homeScreen = state as HomeScreenPaintSelection;
          return false; // Stop searching
        }
      }
      return true; // Continue searching
    });
    
    if (homeScreen != null) {
      homeScreen!.onPaintSelectedFromSearch(paint);
    } else {
      // Fallback: show snackbar if HomeScreen not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected ${paint.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Search Colors')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Colors'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, code, or color...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _performSearch,
                ),
                
                const SizedBox(height: 12),
                
                // Brand filter
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      FilterChip(
                        selected: _selectedBrand == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedBrand = null);
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          }
                        },
                        label: const Text('All Brands'),
                      ),
                      const SizedBox(width: 8),
                      ..._brands.map((brand) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: _selectedBrand == brand.name,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBrand = selected ? brand.name : null;
                            });
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                          label: Text(brand.name),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final paint = _searchResults[index];
        return PaintSearchCard(
          paint: paint,
          onTap: () => _selectPaint(paint),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for paint colors',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try searching by name, code, or brand',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or check the brand filter',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PaintSearchCard extends StatelessWidget {
  final Paint paint;
  final VoidCallback onTap;

  const PaintSearchCard({
    super.key,
    required this.paint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
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
              ),
              
              const SizedBox(width: 16),
              
              // Paint info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paint.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paint.brandName} • ${paint.code}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paint.hex.toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Select arrow
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}