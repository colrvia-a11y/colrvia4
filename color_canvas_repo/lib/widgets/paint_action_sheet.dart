import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';

class PaintActionSheet extends StatelessWidget {
  final Paint paint;
  final VoidCallback? onRefine;
  final String primaryActionLabel; // NEW

  const PaintActionSheet({
    super.key,
    required this.paint,
    this.onRefine,
    this.primaryActionLabel = 'Refine', // NEW default
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Paint preview
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Color(int.parse(paint.hex.replaceAll('#', ''), radix: 16) | 0xFF000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                paint.name,
                style: TextStyle(
                  color: _getTextColor(),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Paint info
          Text(
            '${paint.brandName} • ${paint.code}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveFavorite(context),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Save Color'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyPaintData(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          if (onRefine != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onRefine!();
                },
                icon: const Icon(Icons.casino),
                label: Text(primaryActionLabel),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getTextColor() {
    final colorValue = int.parse(paint.hex.replaceAll('#', ''), radix: 16);
    final color = Color(0xFF000000 | colorValue);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  Future<void> _saveFavorite(BuildContext context) async {
    // Enhanced authentication check with detailed logging
    var currentUser = FirebaseService.currentUser;
    print('Initial user check - Current user: ${currentUser?.uid ?? "null"}');
    
    if (currentUser == null) {
      // Double-check by waiting for auth state stream
      try {
        print('Checking auth state stream...');
        final authStream = FirebaseService.authStateChanges.take(1);
        currentUser = await authStream.first.timeout(const Duration(seconds: 3));
        print('Auth stream result - User: ${currentUser?.uid ?? "still null"}');
      } catch (e) {
        print('Auth state check failed: $e');
      }
      
      if (currentUser == null) {
        print('User is not authenticated - showing sign in prompt');
        _showSignInPrompt(context);
        return;
      }
    }

    try {
      // Enhanced debug logging
      final firebaseStatus = await FirebaseService.getFirebaseStatus();
      print('Firebase Status: $firebaseStatus');
      print('User details - UID: ${currentUser.uid}, Email: ${currentUser.email}, isAnonymous: ${currentUser.isAnonymous}');
      print('Paint details - ID: ${paint.id}, Name: ${paint.name}');
      
      // Check if paint is already favorited first
      final isAlreadyFavorited = await FirebaseService.isPaintFavorited(paint.id, currentUser.uid);
      if (isAlreadyFavorited) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${paint.name} is already in your favorites!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      print('Attempting to save favorite paint with embedded data...');
      try {
        await FirebaseService.addFavoritePaintWithData(currentUser.uid, paint);
        print('Favorite paint saved successfully to Firebase (with embedded data)');
      } catch (embedError) {
        print('Embedded data save failed, trying ID-only fallback: $embedError');
        // If denormalized write fails for any reason, try ID-only save
        await FirebaseService.addFavoritePaint(currentUser.uid, paint.id);
        print('Favorite paint saved successfully to Firebase (ID-only fallback)');
      }
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${paint.name} saved to favorites!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving favorite paint: $e');
      print('Error type: ${e.runtimeType}');
      
      if (context.mounted) {
        Navigator.pop(context);
        String errorMessage = 'Failed to save favorite';
        
        // Handle specific Firebase errors with better messaging
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission-denied') || errorString.contains('permission denied')) {
          errorMessage = 'Permission denied. Please check Firebase configuration.';
        } else if (errorString.contains('not authenticated') || errorString.contains('unauthenticated')) {
          errorMessage = 'Authentication failed. Please sign in again.';
          _showSignInPrompt(context);
          return;
        } else if (errorString.contains('network') || errorString.contains('offline')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (errorString.contains('already in favorites') || errorString.contains('already')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${paint.name} is already in your favorites!'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        } else {
          errorMessage = 'Failed to save: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  void _showSignInPrompt(BuildContext context) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to save favorites'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () {
              // Add navigation to login if needed
            },
          ),
        ),
      );
    }
  }

  Future<void> _copyPaintData(BuildContext context) async {
    try {
      // Copy to system clipboard
      final paintInfo = '''${paint.name}
Brand: ${paint.brandName}
Code: ${paint.code}
Hex: ${paint.hex}
RGB: ${paint.rgb.join(', ')}''';
      
      await Clipboard.setData(ClipboardData(text: paintInfo));
      
      // Try to save to Firebase for user's copy history (optional)
      final currentUser = FirebaseService.currentUser;
      if (currentUser != null) {
        try {
          await FirebaseService.addCopiedPaint(currentUser.uid, paint);
        } catch (firebaseError) {
          // Silently ignore Firebase errors - copy still works
          print('Firebase save failed: $firebaseError');
        }
      }
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${paint.name} copied to clipboard!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying paint data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}