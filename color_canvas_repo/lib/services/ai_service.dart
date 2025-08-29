import 'package:cloud_functions/cloud_functions.dart';
import '../firestore/firestore_data_schema.dart';

class AiService {
  static final _f = FirebaseFunctions.instance;

  static Future<String> generateColorStory({
    required UserPalette palette,
    required String room,
    required String style,
    required List<String> vibeWords,
    List<String> brandHints = const [],
  }) async {
    // 🐛 DEBUG: Validate inputs before sending
    if (palette.colors.isEmpty) {
      throw Exception('Cannot generate color story: Palette has no colors');
    }
    
    final safeName = palette.name?.trim().isEmpty == true ? 'Untitled Palette' : (palette.name ?? 'Untitled Palette');
    final safeRoom = room.trim().isEmpty ? 'living room' : room;
    final safeStyle = style.trim().isEmpty ? 'modern' : style;
    
    final parameters = <String, dynamic>{
      'palette': {
        'id': palette.id,
        'name': safeName,
        'items': palette.colors.map((c) => {
          'hex': c.hex ?? '#000000', // Fallback for null hex
          'brandName': (c.brand?.trim().isEmpty == true) ? '' : (c.brand ?? ''),
          'name': (c.name?.trim().isEmpty == true) ? 'Untitled Color' : (c.name ?? 'Untitled Color'),
          'code': (c.code?.trim().isEmpty == true) ? '' : (c.code ?? ''),
        }).toList(),
      },
      'room': safeRoom,
      'style': safeStyle,
      'vibeWords': List<String>.from(vibeWords.where((v) => v.trim().isNotEmpty)),
      'brandHints': List<String>.from(brandHints.where((b) => b.trim().isNotEmpty)),
    };

    try {
      print('🐛 AiService: Calling generateColorStory with parameters: $parameters');
      
      final res = await _f.httpsCallable('generateColorStory').call(parameters);
      print('🐛 AiService: Cloud Function response type: ${res.runtimeType}');
      print('🐛 AiService: Cloud Function raw response: $res');
      
      final data = res.data as Map<String, dynamic>;
      print('🐛 AiService: Response data: $data');
      print('🐛 AiService: Data keys: ${data.keys.toList()}');
      
      if (data['error'] == true) {
        final errorMessage = data['message'] ?? 'Unknown server error';
        print('🐛 AiService: Server returned error: $errorMessage');
        throw Exception('Server error: $errorMessage');
      }
      
      // Extract storyId from standardized Cloud Function response
      String? storyId = data['storyId'] as String?;
      
      print('🐛 AiService: Extracted storyId: "$storyId" (type: ${storyId.runtimeType})');
      print('🐛 AiService: Available keys in response: ${data.keys.toList()}');
      
      if (storyId == null || storyId.isEmpty) {
        print('🐛 AiService: Invalid storyId - null or empty');
        throw Exception('Server did not return a valid story ID. Response: $data');
      }
      
      print('🐛 AiService: SUCCESS - returning storyId: $storyId');
      return storyId;
    } catch (e) {
      print('🐛 AiService.generateColorStory error: $e');
      print('🐛 AiService.generateColorStory error type: ${e.runtimeType}');
      if (e is Exception) {
        print('🐛 AiService.generateColorStory exception details: ${e.toString()}');
      }
      rethrow;
    }
  }
  static Future<String> generateVariant(String storyId, {String emphasis = '', List<String> vibeTweaks = const []}) async {
    // Create JSON-safe parameters for Cloud Function
    final Map<String, dynamic> parameters = {
      'storyId': storyId,
      'emphasis': emphasis,
      'vibeTweaks': List<String>.from(vibeTweaks),
    };
    
    final res = await _f.httpsCallable('generateColorStoryVariant').call(parameters);
    final data = res.data as Map<String, dynamic>;
    
    // Check for success response
    if (data['success'] != true || data['storyId'] == null) {
      throw Exception('Failed to generate color story variant');
    }
    
    return data['storyId'] as String;
  }
  
  /// Retry a specific generation step for a color story
  static Future<void> retryStoryStep({
    required String storyId,
    required String step, // 'writing', 'usage', 'hero', 'audio'
  }) async {
    final parameters = <String, dynamic>{
      'storyId': storyId,
      'step': step,
    };
    
    try {
      print('🐛 AiService: Retrying step $step for story $storyId');
      
      final res = await _f.httpsCallable('retryStoryStep').call(parameters);
      final data = res.data as Map<String, dynamic>;
      
      if (data['success'] != true) {
        final errorMessage = data['message'] ?? 'Unknown error occurred';
        final errorCode = data['code'] ?? 'retry_failed';
        
        print('🐛 AiService: Retry failed with code: $errorCode, message: $errorMessage');
        
        // Create a more specific exception with error details
        throw StepRetryException(
          step: step,
          code: errorCode,
          message: errorMessage,
        );
      }
      
      print('🐛 AiService: Successfully initiated retry for step $step');
    } catch (e) {
      print('🐛 AiService.retryStoryStep error: $e');
      
      // If it's already our custom exception, rethrow as-is
      if (e is StepRetryException) {
        rethrow;
      }
      
      // Wrap other exceptions in our custom type
      throw StepRetryException(
        step: step,
        code: 'network_error',
        message: e.toString(),
      );
    }
  }
}

/// Custom exception for step retry failures
class StepRetryException implements Exception {
  final String step;
  final String code;
  final String message;
  
  const StepRetryException({
    required this.step,
    required this.code,
    required this.message,
  });
  
  @override
  String toString() => 'StepRetryException(step: $step, code: $code, message: $message)';
}