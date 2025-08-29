import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/utils/slug_utils.dart';

class PaintDataImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Import paint data from a list of maps
  /// Each map should contain: brandName, name, code, hex
  static Future<void> importPaintData(List<Map<String, String>> paintData) async {
    try {
      // First, create brand documents
      Map<String, String> brandIds = await _createBrands(paintData);
      
      // Then create paint documents in batches
      await _createPaints(paintData, brandIds);
      
      print('✅ Successfully imported ${paintData.length} paints');
    } catch (e) {
      print('❌ Error importing paint data: $e');
      rethrow;
    }
  }

  static Future<Map<String, String>> _createBrands(List<Map<String, String>> paintData) async {
    // Get unique brands
    Set<String> uniqueBrands = paintData.map((paint) => paint['brandName']!).toSet();
    Map<String, String> brandIds = {};

    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    for (String brandName in uniqueBrands) {
      String brandId = SlugUtils.brandKey(brandName);
      String brandSlug = SlugUtils.brandSlug(brandName);
      
      Brand brand = Brand(
        id: brandId,
        name: brandName,
        slug: brandSlug,
        website: _getBrandWebsite(brandName),
      );

      DocumentReference brandRef = _firestore.collection('brands').doc(brandId);
      batch.set(brandRef, brand.toJson());
      brandIds[brandName] = brandId;
      
      batchCount++;
      if (batchCount >= 500) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    print('✅ Created ${uniqueBrands.length} brand documents');
    return brandIds;
  }

  static Future<void> _createPaints(List<Map<String, String>> paintData, Map<String, String> brandIds) async {
    WriteBatch batch = _firestore.batch();
    int batchCount = 0;
    int totalProcessed = 0;

    for (Map<String, String> paintMap in paintData) {
      try {
        String brandName = paintMap['brandName']!;
        String paintName = paintMap['name']!;
        String paintCode = paintMap['code']!;
        String hexColor = paintMap['hex']!;

        // Ensure hex starts with #
        if (!hexColor.startsWith('#')) {
          hexColor = '#$hexColor';
        }

        // Convert hex to RGB and LAB/LCH
        List<int> rgb = ColorUtils.hexToRgb(hexColor);
        List<double> lab = ColorUtils.rgbToLab(rgb[0], rgb[1], rgb[2]);
        List<double> lch = ColorUtils.labToLch(lab);

        String paintId = _createPaintId(brandName, paintCode);
        String brandId = brandIds[brandName]!;

        Paint paint = Paint(
          id: paintId,
          brandId: brandId,
          brandName: brandName,
          name: paintName,
          code: paintCode,
          hex: hexColor.toUpperCase(),
          rgb: rgb,
          lab: lab,
          lch: lch,
        );

        DocumentReference paintRef = _firestore.collection('paints').doc(paintId);
        batch.set(paintRef, paint.toJson());
        
        batchCount++;
        totalProcessed++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
          print('📦 Processed $totalProcessed/${paintData.length} paints...');
        }
      } catch (e) {
        print('⚠️ Error processing paint ${paintMap['name']}: $e');
        continue;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }
  }

  static String _createSlug(String text) {
    // Updated to handle hyphens/dashes as spaces, remove punctuation, collapse whitespace to underscores
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[-\s]+'), '_')  // Replace hyphens and spaces with underscores
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')  // Remove all other punctuation
        .replaceAll(RegExp(r'_+'), '_')  // Collapse multiple underscores to one
        .replaceAll(RegExp(r'^_+|_+$'), '');  // Remove leading/trailing underscores
  }

  static String _createPaintId(String brandName, String code) {
    String brandSlug = _createSlug(brandName);
    String codeSlug = _createSlug(code);
    return '${brandSlug}_$codeSlug';
  }

  static String? _getBrandWebsite(String brandName) {
    switch (brandName.toLowerCase()) {
      case 'sherwin-williams':
      case 'sherwin williams':
        return 'https://www.sherwin-williams.com';
      case 'benjamin moore':
        return 'https://www.benjaminmoore.com';
      case 'behr':
        return 'https://www.behr.com';
      default:
        return null;
    }
  }

  /// Helper method to import from JSON format
  static Future<void> importFromJson(List<Map<String, dynamic>> jsonData) async {
    List<Map<String, String>> paintData = jsonData.map((item) {
      return {
        'brandName': item['brandName']?.toString() ?? item['brand']?.toString() ?? '',
        'name': item['name']?.toString() ?? item['paintName']?.toString() ?? '',
        'code': item['code']?.toString() ?? item['paintCode']?.toString() ?? '',
        'hex': item['hex']?.toString() ?? item['hexCode']?.toString() ?? '',
      };
    }).toList();

    await importPaintData(paintData);
  }

  /// Helper method to clear all paint data (use with caution!)
  static Future<void> clearAllPaintData() async {
    try {
      // Delete all paints
      QuerySnapshot paintsSnapshot = await _firestore.collection('paints').get();
      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (QueryDocumentSnapshot doc in paintsSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();

      // Delete all brands
      QuerySnapshot brandsSnapshot = await _firestore.collection('brands').get();
      batch = _firestore.batch();
      count = 0;

      for (QueryDocumentSnapshot doc in brandsSnapshot.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      if (count > 0) await batch.commit();

      print('✅ Cleared all paint and brand data');
    } catch (e) {
      print('❌ Error clearing data: $e');
      rethrow;
    }
  }

  /// Get current data count
  static Future<Map<String, int>> getDataCount() async {
    try {
      AggregateQuerySnapshot paintsSnapshot = await _firestore.collection('paints').count().get();
      AggregateQuerySnapshot brandsSnapshot = await _firestore.collection('brands').count().get();
      
      return {
        'paints': paintsSnapshot.count ?? 0,
        'brands': brandsSnapshot.count ?? 0,
      };
    } catch (e) {
      print('❌ Error getting data count: $e');
      return {'paints': 0, 'brands': 0};
    }
  }
}

/// Admin migration utilities
class AdminMigrations {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fix Sherwin-Williams brand IDs to ensure consistency
  /// This migration ensures brands/brand_sherwin_williams exists and updates all paints
  /// with mismatched brandId values to the correct standardized format
  static Future<void> fixSherwinBrandIds() async {
    try {
      print('🔧 Starting Sherwin-Williams brand ID migration...');
      
      // Step 1: Ensure the correct brand document exists
      const correctBrandId = 'brand_sherwin_williams';
      const brandName = 'Sherwin-Williams';
      
      DocumentReference correctBrandRef = _firestore.collection('brands').doc(correctBrandId);
      DocumentSnapshot correctBrandDoc = await correctBrandRef.get();
      
      if (!correctBrandDoc.exists) {
        Brand correctBrand = Brand(
          id: correctBrandId,
          name: brandName,
          slug: SlugUtils.brandSlug(brandName),
          website: 'https://www.sherwin-williams.com',
        );
        
        await correctBrandRef.set(correctBrand.toJson());
        print('✅ Created correct brand document: $correctBrandId');
      }
      
      // Step 2: Find and update paints with incorrect brandId values
      const List<String> incorrectBrandIds = [
        'brand_sherwin-williams',  // with hyphens
        'brand_sherwinwilliams',   // no separators
        'brand_sherwin_william',   // missing s
      ];
      
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      int totalUpdated = 0;
      
      for (String incorrectBrandId in incorrectBrandIds) {
        QuerySnapshot paintsSnapshot = await _firestore
            .collection('paints')
            .where('brandId', isEqualTo: incorrectBrandId)
            .get();
        
        print('🔍 Found ${paintsSnapshot.docs.length} paints with brandId: $incorrectBrandId');
        
        for (QueryDocumentSnapshot doc in paintsSnapshot.docs) {
          batch.update(doc.reference, {'brandId': correctBrandId});
          batchCount++;
          totalUpdated++;
          
          if (batchCount >= 500) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
            print('📦 Updated $totalUpdated paints so far...');
          }
        }
      }
      
      // Commit any remaining updates
      if (batchCount > 0) {
        await batch.commit();
      }
      
      // Step 3: Clean up old brand documents (optional)
      for (String incorrectBrandId in incorrectBrandIds) {
        DocumentReference oldBrandRef = _firestore.collection('brands').doc(incorrectBrandId);
        DocumentSnapshot oldBrandDoc = await oldBrandRef.get();
        
        if (oldBrandDoc.exists) {
          await oldBrandRef.delete();
          print('🗑️ Removed old brand document: $incorrectBrandId');
        }
      }
      
      print('✅ Sherwin-Williams brand ID migration completed!');
      print('📊 Total paints updated: $totalUpdated');
      
    } catch (e) {
      print('❌ Error during Sherwin-Williams brand ID migration: $e');
      rethrow;
    }
  }
}