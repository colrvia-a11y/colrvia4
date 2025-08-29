/// Demo file showing the expected Cloud Function error structure
/// This should NOT be included in production builds - it's for development/testing only

/// Example of how Cloud Functions should structure error responses:

/// For stories/{storyId}.processing.lastError:
final Map<String, dynamic> exampleLastError = {
  'step': 'hero',           // 'writing', 'usage', 'hero', 'audio'
  'code': 'quota_exceeded', // Error code for programmatic handling
  'message': 'Daily image generation quota exceeded. Try again tomorrow.',
  'at': '2024-01-15T10:30:00Z', // ISO timestamp when error occurred
};

/// Example processing state with lastError:
final Map<String, dynamic> exampleProcessingWithError = {
  'writing': {'status': 'complete'},
  'usage': {'status': 'complete'},
  'hero': {'status': 'error'},  // This step failed
  'audio': {'status': 'pending'},
  'lastError': exampleLastError,
};

/// Common error codes that should be handled:
final Map<String, String> commonErrorCodes = {
  // Quota/Rate limiting
  'quota_exceeded': 'Generation quota exceeded',
  'rate_limit': 'Rate limit reached',
  'insufficient_credits': 'Insufficient credits',
  
  // Network/Service issues
  'network_timeout': 'Request timed out',
  'service_unavailable': 'AI service temporarily unavailable',
  'timeout': 'Operation timed out',
  
  // Authentication/Authorization
  'unauthorized': 'Authentication failed',
  'permission_denied': 'Permission denied',
  
  // Input validation
  'invalid_input': 'Invalid input data',
  'invalid_palette': 'Invalid palette configuration',
  
  // Generation-specific
  'content_policy': 'Content policy violation',
  'generation_failed': 'AI generation failed',
  'model_error': 'AI model error',
  
  // Infrastructure
  'storage_error': 'Storage operation failed',
  'database_error': 'Database operation failed',
};

/// Example Cloud Function response structure for retry operations:
final Map<String, dynamic> retrySuccessResponse = {
  'success': true,
  'message': 'Retry initiated successfully',
};

final Map<String, dynamic> retryFailureResponse = {
  'success': false,
  'code': 'quota_exceeded',
  'message': 'Cannot retry: quota still exceeded',
};

/// How to test error transparency:
/// 
/// 1. Artificial Error Injection (for QA):
///    - Cloud Functions can check for a debug flag in the request
///    - If debug=true and step='hero', always fail with a test error
/// 
/// 2. Example test request:
///    ```
///    {
///      "storyId": "test123",
///      "step": "hero", 
///      "debug": true,
///      "debugErrorCode": "quota_exceeded"
///    }
///    ```
/// 
/// 3. Expected client behavior:
///    - Error card appears under progress indicator
///    - Shows user-friendly message: "Generation quota exceeded..."
///    - "Retry" button calls retryStoryStep with same storyId/step
///    - "Details" button shows technical information
/// 
/// 4. QA test scenarios:
///    - Fail writing step → see writing error + retry button
///    - Fail hero step → see hero error + retry button  
///    - Retry succeeds → error card disappears, step continues
///    - Retry fails → updated error message shown