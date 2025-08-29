import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

class BrandFilterDialog extends StatefulWidget {
  final List<Brand> availableBrands;
  final Set<String> selectedBrandIds;
  final Function(Set<String>) onBrandsSelected;

  const BrandFilterDialog({
    super.key,
    required this.availableBrands,
    required this.selectedBrandIds,
    required this.onBrandsSelected,
  });

  @override
  State<BrandFilterDialog> createState() => _BrandFilterDialogState();
}

class _BrandFilterDialogState extends State<BrandFilterDialog> {
  late Set<String> _selectedBrands;

  @override
  void initState() {
    super.initState();
    _selectedBrands = Set.from(widget.selectedBrandIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Brand'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick actions
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedBrands = widget.availableBrands.map((b) => b.id).toSet();
                    });
                  },
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedBrands.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            
            // Brand list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableBrands.length,
                itemBuilder: (context, index) {
                  final brand = widget.availableBrands[index];
                  final isSelected = _selectedBrands.contains(brand.id);
                  
                  return CheckboxListTile(
                    title: Text(brand.name),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedBrands.add(brand.id);
                        } else {
                          _selectedBrands.remove(brand.id);
                        }
                      });
                    },
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onBrandsSelected(_selectedBrands);
            Navigator.of(context).pop();
          },
          child: Text(_selectedBrands.isEmpty ? 'Show All' : 'Apply (${_selectedBrands.length})'),
        ),
      ],
    );
  }
}

class BrandFilterPanel extends StatefulWidget {
  final List<Brand> availableBrands;
  final Set<String> selectedBrandIds;
  final Function(Set<String>) onBrandsSelected;
  final VoidCallback onDone;
  final bool showActions;

  const BrandFilterPanel({
    super.key,
    required this.availableBrands,
    required this.selectedBrandIds,
    required this.onBrandsSelected,
    required this.onDone,
    this.showActions = false,
  });

  @override
  State<BrandFilterPanel> createState() => _BrandFilterPanelState();
}

class _BrandFilterPanelState extends State<BrandFilterPanel> {
  late Set<String> _selectedBrands;

  @override
  void initState() {
    super.initState();
    _selectedBrands = Set.from(widget.selectedBrandIds);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Brands', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          
          // Quick actions
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedBrands = widget.availableBrands.map((b) => b.id).toSet();
                  });
                  widget.onBrandsSelected(_selectedBrands);
                },
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedBrands.clear();
                  });
                  widget.onBrandsSelected(_selectedBrands);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const Divider(),
          
          // Brand list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableBrands.length,
              itemBuilder: (context, index) {
                final brand = widget.availableBrands[index];
                final isSelected = _selectedBrands.contains(brand.id);
                
                return CheckboxListTile(
                  title: Text(brand.name),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedBrands.add(brand.id);
                      } else {
                        _selectedBrands.remove(brand.id);
                      }
                    });
                    widget.onBrandsSelected(_selectedBrands);
                  },
                  dense: true,
                );
              },
            ),
          ),
          
          if (widget.showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onDone,
                    child: Text(_selectedBrands.isEmpty ? 'Show All' : 'Apply (${_selectedBrands.length})'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onDone,
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}