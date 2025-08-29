import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../models/color_story.dart' as model;

/// Widget that displays step-by-step progress for color story generation
/// with error transparency and granular retry functionality.
/// 
/// Features:
/// - Shows progress for each generation step (writing, usage, hero, audio)
/// - Displays detailed error information when steps fail
/// - Provides one-tap retry for failed steps
/// - Shows user-friendly error messages with technical details on demand
/// 
/// Error Structure Expected:
/// ```dart
/// processing: {
///   'writing': {'status': 'complete'},
///   'usage': {'status': 'complete'},
///   'hero': {'status': 'error'},
///   'audio': {'status': 'pending'},
///   'lastError': {
///     'step': 'hero',
///     'code': 'quota_exceeded',
///     'message': 'Daily image generation quota exceeded',
///     'at': '2024-01-15T10:30:00Z'
///   }
/// }
/// ```
class StoryGenerationProgress extends StatefulWidget {
  final model.ColorStory story;
  final VoidCallback? onRetryCompleted;

  const StoryGenerationProgress({
    super.key,
    required this.story,
    this.onRetryCompleted,
  });

  @override
  State<StoryGenerationProgress> createState() => _StoryGenerationProgressState();
}

class _StoryGenerationProgressState extends State<StoryGenerationProgress> {
  final Set<String> _retryingSteps = <String>{};

  // Define the generation steps
  final List<Map<String, dynamic>> _generationSteps = [
    {
      'id': 'writing',
      'label': 'Writing',
      'description': 'Crafting color story narrative',
      'icon': Icons.edit,
    },
    {
      'id': 'usage',
      'label': 'Usage Guide',
      'description': 'Generating paint application tips',
      'icon': Icons.palette,
    },
    {
      'id': 'hero',
      'label': 'Hero Image',
      'description': 'Creating visual representation',
      'icon': Icons.image,
    },
    {
      'id': 'audio',
      'label': 'Audio',
      'description': 'Generating ambient audio',
      'icon': Icons.audiotrack,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creating Your Color Story',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Each step is crafted with AI precision',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Steps progress
          Column(
            children: _generationSteps.map((step) {
              final stepId = step['id'] as String;
              final stepStatus = _getStepStatus(stepId);
              final isRetrying = _retryingSteps.contains(stepId);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildStepRow(step, stepStatus, isRetrying),
              );
            }).toList(),
          ),
          
          // Error card if there's a lastError
          if (_hasLastError()) ...[
            const SizedBox(height: 8),
            _buildErrorCard(),
          ],
          
          // Overall progress indicator
          if (widget.story.status == 'processing')
            Column(
              children: [
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _calculateOverallProgress(),
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_calculateOverallProgress() * 100).round()}% complete',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildStepRow(Map<String, dynamic> step, String status, bool isRetrying) {
    final stepId = step['id'] as String;
    final label = step['label'] as String;
    final description = step['description'] as String;
    final icon = step['icon'] as IconData;
    
    Color iconColor;
    Widget trailingWidget;
    
    switch (status) {
      case 'complete':
        iconColor = Colors.green;
        trailingWidget = Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 20,
        );
        break;
      case 'processing':
        iconColor = Theme.of(context).colorScheme.primary;
        trailingWidget = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
        break;
      case 'error':
        iconColor = Colors.red;
        trailingWidget = isRetrying
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            : TextButton.icon(
                onPressed: () => _retryStep(stepId),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
        break;
      default:
        iconColor = Theme.of(context).colorScheme.outline;
        trailingWidget = Icon(
          Icons.radio_button_unchecked,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          size: 20,
        );
    }
    
    return Row(
      children: [
        // Step icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Step info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        
        // Status indicator
        trailingWidget,
      ],
    );
  }
  
  bool _hasLastError() {
    final processing = widget.story.processing;
    final lastError = processing['lastError'] as Map<String, dynamic>?;
    return lastError != null && lastError.isNotEmpty;
  }
  
  Map<String, dynamic>? _getLastError() {
    final processing = widget.story.processing;
    return processing['lastError'] as Map<String, dynamic>?;
  }
  
  Widget _buildErrorCard() {
    final lastError = _getLastError();
    if (lastError == null) return const SizedBox.shrink();
    
    final step = lastError['step'] as String? ?? 'unknown';
    final code = lastError['code'] as String? ?? '';
    final message = lastError['message'] as String? ?? 'An unknown error occurred';
    final at = lastError['at']; // Could be Timestamp
    
    // Find step info
    final stepInfo = _generationSteps.firstWhere(
      (s) => s['id'] == step,
      orElse: () => {'id': step, 'label': step.toUpperCase(), 'icon': Icons.error},
    );
    final stepLabel = stepInfo['label'] as String;
    final stepIcon = stepInfo['icon'] as IconData;
    
    // Format error message for user display
    String userMessage = _formatErrorMessage(code, message);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error header
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$stepLabel Failed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Error message
          Text(
            userMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Technical details (expandable)
              if (code.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showTechnicalDetails(step, code, message, at),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(width: 8),
              
              // Retry button
              ElevatedButton.icon(
                onPressed: _retryingSteps.contains(step)
                    ? null
                    : () => _retryStep(step),
                icon: _retryingSteps.contains(step)
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.red.shade600,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_retryingSteps.contains(step) ? 'Retrying...' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatErrorMessage(String code, String rawMessage) {
    // Convert technical error codes/messages to user-friendly text
    switch (code.toLowerCase()) {
      case 'quota_exceeded':
      case 'rate_limit':
        return 'Generation quota exceeded. Please try again in a few minutes.';
      case 'insufficient_credits':
        return 'Insufficient credits for this operation. Please upgrade your plan.';
      case 'network_timeout':
      case 'timeout':
        return 'Request timed out. Please check your connection and try again.';
      case 'invalid_input':
        return 'Invalid input data. Please try recreating the story.';
      case 'service_unavailable':
        return 'AI service is temporarily unavailable. Please try again later.';
      default:
        // For unknown codes, try to make the raw message more user-friendly
        if (rawMessage.toLowerCase().contains('quota')) {
          return 'Generation quota exceeded. Please try again later.';
        } else if (rawMessage.toLowerCase().contains('timeout')) {
          return 'Request timed out. Please try again.';
        } else if (rawMessage.toLowerCase().contains('unauthorized')) {
          return 'Authentication failed. Please sign out and back in.';
        } else if (rawMessage.toLowerCase().contains('insufficient')) {
          return 'Insufficient resources. Please try again later or upgrade your plan.';
        }
        // Fallback to raw message, but cap length
        return rawMessage.length > 120 
            ? '${rawMessage.substring(0, 120)}...'
            : rawMessage;
    }
  }
  
  void _showTechnicalDetails(String step, String code, String message, dynamic timestamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Technical Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Step:', step),
            _buildDetailRow('Error Code:', code),
            _buildDetailRow('Message:', message),
            if (timestamp != null)
              _buildDetailRow('Time:', _formatTimestamp(timestamp)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is String) {
        final dt = DateTime.parse(timestamp);
        return dt.toLocal().toString();
      }
      return timestamp.toString();
    } catch (e) {
      return timestamp.toString();
    }
  }

  String _getStepStatus(String stepId) {
    final processing = widget.story.processing;
    
    // Check if this specific step has a lastError
    final lastError = processing['lastError'] as Map<String, dynamic>?;
    if (lastError != null && lastError['step'] == stepId) {
      return 'error';
    }
    
    if (processing.isEmpty) {
      // Fallback to overall status if no detailed processing data
      if (widget.story.status == 'complete') {
        return 'complete';
      } else if (widget.story.status == 'processing') {
        return 'processing';
      } else if (widget.story.status == 'error') {
        return 'error';
      } else {
        return 'pending';
      }
    }
    
    final stepData = processing[stepId] as Map<String, dynamic>?;
    if (stepData == null) return 'pending';
    
    final status = stepData['status'] as String?;
    return status ?? 'pending';
  }
  
  double _calculateOverallProgress() {
    int completedSteps = 0;
    int totalSteps = _generationSteps.length;
    
    for (final step in _generationSteps) {
      final stepId = step['id'] as String;
      final status = _getStepStatus(stepId);
      if (status == 'complete') {
        completedSteps++;
      }
    }
    
    return completedSteps / totalSteps;
  }
  
  Future<void> _retryStep(String stepId) async {
    setState(() {
      _retryingSteps.add(stepId);
    });
    
    try {
      await AiService.retryStoryStep(
        storyId: widget.story.id,
        step: stepId,
      );
      
      // Track retry event
      AnalyticsService.instance.logEvent('story_step_retry', {
        'story_id': widget.story.id,
        'step': stepId,
        'retry_success': true,
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrying ${_generationSteps.firstWhere((s) => s['id'] == stepId)['label']} step...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Notify parent if callback provided
      widget.onRetryCompleted?.call();
      
    } catch (e) {
      // Get error details for better user messaging
      String userErrorMessage;
      String analyticsErrorCode;
      
      if (e is StepRetryException) {
        userErrorMessage = _formatErrorMessage(e.code, e.message);
        analyticsErrorCode = e.code;
      } else {
        userErrorMessage = 'Failed to retry step: ${e.toString()}';
        analyticsErrorCode = 'unknown_error';
      }
      
      // Track retry failure with structured data
      AnalyticsService.instance.logEvent('story_step_retry', {
        'story_id': widget.story.id,
        'step': stepId,
        'retry_success': false,
        'error_code': analyticsErrorCode,
        'error_message': e.toString(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userErrorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _retryingSteps.remove(stepId);
        });
      }
    }
  }
}