import 'package:flutter_test/flutter_test.dart';
import 'package:color_canvas/utils/palette_generator.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

// Helper class for creating test data
class TestPaintFactory {
  static List<Paint> sampleSet() {
    return [
      Paint(
        id: 'test_light_1',
        brandId: 'test_brand_1',
        name: 'Pure White',
        brandName: 'Test Brand',
        code: 'TW100',
        hex: '#FFFFFF',
        rgb: [255, 255, 255],
        lab: [95.0, 0.0, 0.0], 
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
        lab: [92.0, 2.0, 5.0],
        lch: [92.0, 5.4, 68.2],
      ),
      Paint(
        id: 'test_med_light_1',
        brandId: 'test_brand_1',
        name: 'Light Gray',
        brandName: 'Test Brand',
        code: 'LG85',
        hex: '#E8E8E6',
        rgb: [232, 232, 230],
        lab: [85.0, 1.0, 2.0],
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
        lab: [82.0, 3.0, 8.0],
        lch: [82.0, 8.5, 69.4],
      ),
      Paint(
        id: 'test_main_1',
        brandId: 'test_brand_1',
        name: 'Medium Gray',
        brandName: 'Test Brand',
        code: 'MG60',
        hex: '#999996',
        rgb: [153, 153, 150],
        lab: [60.0, 2.0, 3.0],
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
        lab: [55.0, 5.0, 12.0],
        lch: [55.0, 13.0, 67.4],
      ),
      Paint(
        id: 'test_med_dark_1',
        brandId: 'test_brand_1',
        name: 'Charcoal',
        brandName: 'Test Brand',
        code: 'CG40',
        hex: '#5A5856',
        rgb: [90, 88, 86],
        lab: [40.0, 2.0, 3.0],
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
        lab: [35.0, 8.0, 15.0],
        lch: [35.0, 17.0, 61.9],
      ),
      Paint(
        id: 'test_dark_1',
        brandId: 'test_brand_1',
        name: 'Dark Charcoal',
        brandName: 'Test Brand',
        code: 'DC20',
        hex: '#2C2A28',
        rgb: [44, 42, 40],
        lab: [20.0, 1.0, 2.0],
        lch: [20.0, 2.2, 63.4],
      ),
      Paint(
        id: 'test_dark_2',
        brandId: 'test_brand_2',
        name: 'Deep Brown',
        brandName: 'Test Brand 2',
        code: 'DB15',
        hex: '#1F1B16',
        rgb: [31, 27, 22],
        lab: [15.0, 5.0, 8.0],
        lch: [15.0, 9.4, 57.9],
      ),
    ];
  }
}

void main() {
  group('Designer Lock Persistence Tests', () {
    late List<Paint> dataset;

    setUp(() {
      dataset = TestPaintFactory.sampleSet();
    });

    test('Designer: locked swatches persist across generated pages', () {
      const size = 7;
      
      // Start with an initial palette
      final first = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: List<Paint?>.filled(size, null),
        mode: HarmonyMode.designer,
      );
      
      expect(first.length, equals(size));
      
      // Lock 1st and 5th positions
      final locked = List<bool>.generate(size, (i) => i == 0 || i == 4);
      final anchors = List<Paint?>.generate(size, (i) => locked[i] ? first[i] : null);

      // Generate another page with locks
      final next = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: anchors,
        mode: HarmonyMode.designer,
      );

      expect(next.length, equals(size));
      
      // Assert locked positions unchanged by identity
      expect(paintIdentity(next[0]), equals(paintIdentity(first[0])));
      expect(paintIdentity(next[4]), equals(paintIdentity(first[4])));
      
      // Verify unlocked positions can be different
      // (Note: they might be the same by chance, but we test that locks work)
      expect(next[0].id, equals(first[0].id)); // Locked should be identical
      expect(next[4].id, equals(first[4].id)); // Locked should be identical
    });

    test('Designer: single lock at middle position works', () {
      const size = 5;
      
      // Generate initial palette
      final first = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: List<Paint?>.filled(size, null),
        mode: HarmonyMode.designer,
      );
      
      // Lock only position 2 (middle)
      final anchors = List<Paint?>.generate(size, (i) => i == 2 ? first[i] : null);
      
      // Generate multiple new palettes
      for (int attempt = 0; attempt < 5; attempt++) {
        final next = PaletteGenerator.rollPalette(
          availablePaints: dataset,
          anchors: anchors,
          mode: HarmonyMode.designer,
        );
        
        expect(next.length, equals(size));
        expect(paintIdentity(next[2]), equals(paintIdentity(first[2])));
        expect(next[2].id, equals(first[2].id));
      }
    });

    test('Designer: all positions locked returns same palette', () {
      const size = 4;
      
      // Generate initial palette
      final first = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: List<Paint?>.filled(size, null),
        mode: HarmonyMode.designer,
      );
      
      // Lock all positions
      final anchors = List<Paint?>.generate(size, (i) => first[i]);
      
      // Generate new palette with all locks
      final next = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: anchors,
        mode: HarmonyMode.designer,
      );
      
      expect(next.length, equals(size));
      
      // All positions should be identical
      for (int i = 0; i < size; i++) {
        expect(paintIdentity(next[i]), equals(paintIdentity(first[i])));
        expect(next[i].id, equals(first[i].id));
      }
    });

    test('Designer: locked paints are excluded from other slots', () {
      const size = 6;
      
      // Create a palette with distinct paints
      final first = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: List<Paint?>.filled(size, null),
        mode: HarmonyMode.designer,
      );
      
      // Lock positions 0 and 2
      final anchors = List<Paint?>.generate(size, (i) => 
        (i == 0 || i == 2) ? first[i] : null);
      
      // Generate new palette
      final next = PaletteGenerator.rollPalette(
        availablePaints: dataset,
        anchors: anchors,
        mode: HarmonyMode.designer,
      );
      
      expect(next.length, equals(size));
      
      // Locked positions unchanged
      expect(paintIdentity(next[0]), equals(paintIdentity(first[0])));
      expect(paintIdentity(next[2]), equals(paintIdentity(first[2])));
      
      // No duplicates: locked paints shouldn't appear in other slots
      final lockedIdentities = {paintIdentity(first[0]), paintIdentity(first[2])};
      for (int i = 0; i < size; i++) {
        if (i == 0 || i == 2) continue; // Skip locked positions
        expect(lockedIdentities.contains(paintIdentity(next[i])), isFalse, 
          reason: 'Unlocked position $i should not contain a locked paint');
      }
    });
  });
}