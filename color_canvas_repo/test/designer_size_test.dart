import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

// Helper class for creating test data
class TestPaintFactory {
  static List<Paint> sampleSet() {
    return [
      // Light colors (90-100 LRV range)
      Paint(
        id: 'test_light_1',
        brandId: 'test_brand_1',
        name: 'Pure White',
        brandName: 'Test Brand',
        code: 'TW100',
        hex: '#FFFFFF',
        rgb: [255, 255, 255],
        lab: [95.0, 0.0, 0.0], // Very light, neutral
        lch: [95.0, 0.0, 0.0],
      ),
      Paint(
        id: 'test_light_2',
        brandId: 'test_brand_2',
        name: 'Cream White',
        brandName: 'Test Brand 2',
        code: 'TW92',
        hex: '#FEFDF8',
        rgb: [254, 253, 248],
        lab: [92.0, 2.0, 5.0], // Very light, slightly warm
        lch: [92.0, 5.4, 68.2],
      ),
      
      // Medium-light colors (70-85 LRV range)
      Paint(
        id: 'test_med_light_1',
        brandId: 'test_brand_1',
        name: 'Light Gray',
        brandName: 'Test Brand',
        code: 'LG85',
        hex: '#E8E8E6',
        rgb: [232, 232, 230],
        lab: [85.0, 1.0, 2.0], // Light gray
        lch: [85.0, 2.2, 63.4],
      ),
      Paint(
        id: 'test_med_light_2',
        brandId: 'test_brand_2',
        name: 'Soft Beige',
        brandName: 'Test Brand 2',
        code: 'SB82',
        hex: '#E6DDD1',
        rgb: [230, 221, 209],
        lab: [82.0, 3.0, 8.0], // Light warm
        lch: [82.0, 8.5, 69.4],
      ),
      
      // Main/medium colors (50-65 LRV range)
      Paint(
        id: 'test_main_1',
        brandId: 'test_brand_1',
        name: 'Medium Gray',
        brandName: 'Test Brand',
        code: 'MG60',
        hex: '#999996',
        rgb: [153, 153, 150],
        lab: [60.0, 2.0, 3.0], // Medium neutral
        lch: [60.0, 3.6, 56.3],
      ),
      Paint(
        id: 'test_main_2',
        brandId: 'test_brand_2',
        name: 'Warm Beige',
        brandName: 'Test Brand 2',
        code: 'WB55',
        hex: '#8A7F6C',
        rgb: [138, 127, 108],
        lab: [55.0, 5.0, 12.0], // Medium warm
        lch: [55.0, 13.0, 67.4],
      ),
      
      // Medium-dark colors (30-45 LRV range)
      Paint(
        id: 'test_med_dark_1',
        brandId: 'test_brand_1',
        name: 'Charcoal',
        brandName: 'Test Brand',
        code: 'CG40',
        hex: '#5A5856',
        rgb: [90, 88, 86],
        lab: [40.0, 2.0, 3.0], // Dark neutral
        lch: [40.0, 3.6, 56.3],
      ),
      Paint(
        id: 'test_med_dark_2',
        brandId: 'test_brand_2',
        name: 'Dark Brown',
        brandName: 'Test Brand 2',
        code: 'DB35',
        hex: '#4A3F32',
        rgb: [74, 63, 50],
        lab: [35.0, 5.0, 12.0], // Dark warm
        lch: [35.0, 13.0, 67.4],
      ),
      
      // Dark/accent colors (10-25 LRV range)
      Paint(
        id: 'test_dark_1',
        brandId: 'test_brand_1',
        name: 'Navy Blue',
        brandName: 'Test Brand',
        code: 'NB20',
        hex: '#2B3A4A',
        rgb: [43, 58, 74],
        lab: [20.0, 5.0, -15.0], // Dark cool blue
        lch: [20.0, 15.8, 288.4],
      ),
      Paint(
        id: 'test_dark_2',
        brandId: 'test_brand_2',
        name: 'Forest Green',
        brandName: 'Test Brand 2',
        code: 'FG15',
        hex: '#1E2F1E',
        rgb: [30, 47, 30],
        lab: [15.0, -8.0, 10.0], // Dark green
        lch: [15.0, 12.8, 128.7],
      ),
    ];
  }
}

void main() {
  group('Designer Size-Based Generation Tests', () {
    late List<Paint> dataset;

    setUp(() {
      dataset = TestPaintFactory.sampleSet();
    });

    test('Designer supports sizes 1-9 with uniqueness', () {
      for (int size = 1; size <= 9; size++) {
        final res = PaletteGenerator.rollPalette(
          availablePaints: dataset,
          anchors: List.filled(size, null),
          mode: HarmonyMode.designer,
        );
        
        expect(res.length, size, reason: 'Size $size should return exactly $size paints');
        
        // Check uniqueness by paint identity
        final ids = res.map((p) => '${p.brandId}|${p.collection ?? ''}|${(p.code.isNotEmpty ? p.code : p.name).toLowerCase()}').toSet();
        expect(ids.length, size, reason: 'Size $size should have $size unique paint identities');
      }
    });

    test('Designer palettes have reasonable LRV spacing', () {
      for (int size = 2; size <= 9; size++) {
        final res = PaletteGenerator.rollPalette(
          availablePaints: dataset,
          anchors: List.filled(size, null),
          mode: HarmonyMode.designer,
        );
        
        // Check that adjacent paints have reasonable LRV differences (≥ 3 on average)
        double totalSpacing = 0.0;
        int spacingCount = 0;
        
        for (int i = 1; i < res.length; i++) {
          final diff = (res[i-1].computedLrv - res[i].computedLrv).abs();
          totalSpacing += diff;
          spacingCount++;
        }
        
        if (spacingCount > 0) {
          final avgSpacing = totalSpacing / spacingCount;
          expect(avgSpacing, greaterThanOrEqualTo(3.0), 
            reason: 'Size $size palette should have average LRV spacing ≥ 3, got $avgSpacing');
        }
      }
    });

    test('Designer palette has reasonable hue diversity for larger sizes', () {
      for (int size = 5; size <= 9; size++) {
        final res = PaletteGenerator.rollPalette(
          availablePaints: dataset,
          anchors: List.filled(size, null),
          mode: HarmonyMode.designer,
        );
        
        // Calculate hue span (excluding potential accent colors at the end)
        final baseColors = res.take(size > 2 ? size - 2 : size).toList();
        if (baseColors.length >= 2) {
          double minH = 360.0, maxH = 0.0;
          for (final p in baseColors) {
            final h = p.lch[2];
            if (h < minH) minH = h;
            if (h > maxH) maxH = h;
          }
          final span = (maxH - minH).abs();
          
          // Expect some hue diversity for larger palettes (not all analogous)
          if (size >= 5) {
            expect(span, greaterThan(15.0), 
              reason: 'Size $size palette should have hue span > 15°, got $span');
          }
        }
      }
    });

    test('Designer mode preserves locked anchors', () {
      final lockedPaint = dataset.first;
      final anchors = [lockedPaint, null, null, null, null];
      
      final res = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: anchors,
        mode: HarmonyMode.designer,
      );
      
      expect(res.length, 5);
      expect(res[0].id, lockedPaint.id, reason: 'First position should preserve locked paint');
    });

    test('Single color Designer palette works', () {
      final res = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: [null],
        mode: HarmonyMode.designer,
      );
      
      expect(res.length, 1);
      expect(res.first.computedLrv, inInclusiveRange(30.0, 80.0), 
        reason: 'Single color should be in reasonable LRV range');
    });

    test('Designer mode does not crash with empty dataset', () {
      final res = PaletteGenerator.rollPalette(
        availablePaints: [],
        anchors: [null, null, null],
        mode: HarmonyMode.designer,
      );
      
      expect(res.length, 0, reason: 'Empty dataset should return empty result');
    });
  });
}