import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/utils/slug_utils.dart';

class SamplePaints {
  static List<Map<String, dynamic>>? _cachedPaintData;

  /// Load paint data from JSON assets files
  static Future<List<Map<String, dynamic>>> _loadPaintData() async {
    if (_cachedPaintData != null) {
      return _cachedPaintData!;
    }

    try {
      // Load all three brand JSON files
      final sherwinData = await rootBundle.loadString('assets/documents/paints_sherwin-williams_mapped.json');
      final benjaminData = await rootBundle.loadString('assets/documents/paints_benjamin_moore_mapped.json');
      final behrData = await rootBundle.loadString('assets/documents/behr.json');

      // Parse JSON data
      final List<dynamic> sherwinPaints = json.decode(sherwinData);
      final List<dynamic> benjaminPaints = json.decode(benjaminData);
      final List<dynamic> behrPaints = json.decode(behrData);

      // Convert to List<Map<String, dynamic>>
      final List<Map<String, dynamic>> allPaints = [
        ...sherwinPaints.cast<Map<String, dynamic>>(),
        ...benjaminPaints.cast<Map<String, dynamic>>(),
        ...behrPaints.cast<Map<String, dynamic>>(),
      ];

      _cachedPaintData = allPaints;
      return allPaints;
    } catch (e) {
      print('Error loading paint data: $e');
      // Return fallback sample data if files can\'t be loaded
      return _getFallbackPaintData();
    }
  }

  /// Fallback sample paint data in case JSON files can't be loaded
  static List<Map<String, dynamic>> _getFallbackPaintData() {
    return [
      // Sherwin-Williams samples
      {
        'brandName': 'Sherwin-Williams',
        'name': 'Alabaster',
        'code': 'SW 7008',
        'hex': '#F2F0E8',
      },
      {
        'brandName': 'Sherwin-Williams',
        'name': 'Agreeable Gray',
        'code': 'SW 7029',
        'hex': '#D0CDB7',
      },
      {
        'brandName': 'Sherwin-Williams',
        'name': 'Naval',
        'code': 'SW 6244',
        'hex': '#1F2937',
      },
      // Benjamin Moore samples
      {
        'brandName': 'Benjamin Moore',
        'name': 'White Dove',
        'code': 'OC-17',
        'hex': '#F9F7F4',
      },
      {
        'brandName': 'Benjamin Moore',
        'name': 'Revere Pewter',
        'code': 'HC-172',
        'hex': '#D1C7B8',
      },
      {
        'brandName': 'Benjamin Moore',
        'name': 'Hale Navy',
        'code': 'HC-154',
        'hex': '#2F4F4F',
      },
      // Behr samples
      {
        'brandName': 'Behr',
        'name': 'Ultra Pure White',
        'code': 'PR-W15',
        'hex': '#FFFFFF',
      },
      {
        'brandName': 'Behr',
        'name': 'Perfect Taupe',
        'code': 'N350-2',
        'hex': '#C5B49A',
      },
      {
        'brandName': 'Behr',
        'name': 'Atmospheric',
        'code': 'PPU25-14',
        'hex': '#C7D1D0',
      },
    ];
  }

  /// Load and return all paint data from JSON files
  static Future<List<Paint>> getSamplePaints() async {
    final paintData = await _loadPaintData();

    return paintData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      
      // Process color values
      final hex = data['hex'] as String;
      final rgb = ColorUtils.hexToRgb(hex);
      final lab = ColorUtils.rgbToLab(rgb[0], rgb[1], rgb[2]);
      
      return Paint(
        id: 'paint_$index',
        brandId: SlugUtils.brandKey(data['brandName']),
        brandName: data['brandName'],
        name: data['name'],
        code: data['code'],
        hex: hex,
        rgb: rgb,
        lab: lab,
        lch: ColorUtils.labToLch(lab),
        collection: null,
        finish: 'Eggshell',
        metadata: {
          'isSample': true,
        },
      );
    }).toList();
  }

  /// Get paint data by brand name
  static Future<List<Paint>> getPaintsByBrand(String brandName) async {
    final allPaints = await getSamplePaints();
    return allPaints.where((paint) => paint.brandName == brandName).toList();
  }

  /// Search paints by name or code
  static Future<List<Paint>> searchPaints(String query) async {
    final allPaints = await getSamplePaints();
    final lowercaseQuery = query.toLowerCase();
    
    return allPaints.where((paint) {
      return paint.name.toLowerCase().contains(lowercaseQuery) ||
             paint.code.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  static List<Brand> getSampleBrands() {
    return [
      Brand(
        id: SlugUtils.brandKey('Sherwin-Williams'),
        name: 'Sherwin-Williams',
        slug: SlugUtils.brandSlug('Sherwin-Williams'),
        website: 'https://www.sherwin-williams.com',
      ),
      Brand(
        id: SlugUtils.brandKey('Benjamin Moore'),
        name: 'Benjamin Moore',
        slug: SlugUtils.brandSlug('Benjamin Moore'),
        website: 'https://www.benjaminmoore.com',
      ),
      Brand(
        id: SlugUtils.brandKey('Behr'),
        name: 'Behr',
        slug: SlugUtils.brandSlug('Behr'),
        website: 'https://www.behr.com',
      ),
    ];
  }
}