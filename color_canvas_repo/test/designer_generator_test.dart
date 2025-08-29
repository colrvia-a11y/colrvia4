// This file has been updated to remove role-based functionality.
// Designer mode now uses simple size-based palette generation (1-9 colors).
// See designer_size_test.dart for comprehensive size-based Designer testing.

import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

void main() {
  group('Basic Designer Generator Tests', () {
    test('paintIdentity creates unique keys for deduplication', () {
      final paint1 = Paint(
        id: 'id1',
        brandId: 'brand_a',
        name: 'White',
        brandName: 'Brand A',
        code: 'W100',
        hex: '#FFFFFF',
        rgb: [255, 255, 255],
        lab: [95.0, 0.0, 0.0],
        lch: [95.0, 0.0, 0.0],
        collection: 'Premium',
      );
      
      final paint2 = Paint(
        id: 'id2', // Different document ID
        brandId: 'brand_a',
        name: 'White',
        brandName: 'Brand A',
        code: 'W100',
        hex: '#FFFFFF',
        rgb: [255, 255, 255],
        lab: [95.0, 0.0, 0.0],
        lch: [95.0, 0.0, 0.0],
        collection: 'Premium',
      );
      
      // Should have same identity despite different document IDs
      final identity1 = paintIdentity(paint1);
      final identity2 = paintIdentity(paint2);
      expect(identity1, equals(identity2));
      expect(identity1, equals('brand_a|premium|w100'));
    });
    
    test('Designer mode generates requested palette size', () {
      final testPaints = [
        Paint(
          id: 'light',
          brandId: 'test',
          name: 'Light',
          brandName: 'Test Brand',
          code: 'L90',
          hex: '#F0F0F0',
          rgb: [240, 240, 240],
          lab: [90.0, 0.0, 0.0],
          lch: [90.0, 0.0, 0.0],
        ),
        Paint(
          id: 'medium',
          brandId: 'test',
          name: 'Medium',
          brandName: 'Test Brand',
          code: 'M50',
          hex: '#808080',
          rgb: [128, 128, 128],
          lab: [50.0, 0.0, 0.0],
          lch: [50.0, 0.0, 0.0],
        ),
        Paint(
          id: 'dark',
          brandId: 'test',
          name: 'Dark',
          brandName: 'Test Brand',
          code: 'D20',
          hex: '#333333',
          rgb: [51, 51, 51],
          lab: [20.0, 0.0, 0.0],
          lch: [20.0, 0.0, 0.0],
        ),
      ];
      
      for (int size = 1; size <= 3; size++) {
        final result = PaletteGenerator.rollPalette(
          availablePaints: testPaints,
          anchors: List.filled(size, null),
          mode: HarmonyMode.designer,
        );
        
        expect(result.length, equals(size));
      }
    });
  });
}