import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/screens/login_screen.dart';
import 'package:color_canvas/utils/color_utils.dart';

class SavePaletteDialog extends StatefulWidget {
  final List<Paint> paints;
  final VoidCallback onSaved;

  const SavePaletteDialog({
    super.key,
    required this.paints,
    required this.onSaved,
  });

  @override
  State<SavePaletteDialog> createState() => _SavePaletteDialogState();
}

class _SavePaletteDialogState extends State<SavePaletteDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Generate default name
    final brandNames = widget.paints
        .map((p) => p.brandName)
        .toSet()
        .take(2)
        .join(' & ');
    _nameController.text = '$brandNames Palette';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _savePalette() async {
    // Get current user with robust checking and timeout
    var currentUser = FirebaseService.currentUser;
    
    if (currentUser == null) {
      // Double-check by waiting for auth state with timeout
      try {
        final authStream = FirebaseService.authStateChanges.take(1);
        currentUser = await authStream.first.timeout(const Duration(seconds: 3));
      } catch (e) {
        // Auth state check timed out or failed
      }
      
      if (currentUser == null) {
        _showSignInPrompt();
        return;
      }
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    // Pre-flight check bypassed - always allow palette saves for testing
    debugPrint('Palette save limits bypassed for testing');

    setState(() => _isSaving = true);

    try {
      // Debug: Check Firebase status before saving
      final firebaseStatus = await FirebaseService.getFirebaseStatus();
      print('Firebase Status before save: $firebaseStatus');
      
      final colors = widget.paints.asMap().entries.map((entry) {
        return PaletteColor(
          paintId: entry.value.id,
          locked: false,
          position: entry.key,
          brand: entry.value.brandName,
          name: entry.value.name,
          code: entry.value.code,
          hex: entry.value.hex,
        );
      }).toList();

      final palette = UserPalette(
        id: '', // Will be set by Firestore
        userId: currentUser.uid,
        name: _nameController.text.trim(),
        colors: colors,
        tags: _tags,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Attempting to save palette: ${palette.name} for user: ${currentUser.uid}');
      final paletteId = await FirebaseService.createPalette(
        userId: currentUser.uid,
        name: _nameController.text.trim(),
        colors: colors,
        tags: _tags,
        notes: _notesController.text.trim(),
      );
      print('Palette saved successfully with ID: $paletteId');
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${palette.name}" saved to your library!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } on FirebaseException catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        String errorMessage = 'Failed to save palette';
        
        // Handle specific Firebase errors with actionable messages
        if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Firebase project not configured properly.\n\nYou need to:\n1. Connect to a real Firebase project\n2. Deploy Firestore security rules\n\nError: ${e.code}';
        } else if (e.code == 'unauthenticated') {
          errorMessage = 'Authentication failed. Please sign out and sign back in. Error: ${e.code}';
        } else {
          errorMessage = 'Failed to save palette. Error: ${e.code} - ${e.message}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      print('General error saving palette: $e');
      if (mounted) {
        String errorMessage = 'Failed to save palette: ${e.toString()}';
        
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

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  List<String> _getQuickTags() {
    return [
      'living room', 'bedroom', 'kitchen', 'bathroom', 'office',
      'neutral', 'warm', 'cool', 'bold', 'modern', 'cozy'
    ];
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text(
          'You need to sign in to save palettes to your library. Would you like to sign in now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close this dialog
              Navigator.pop(context); // Close save dialog
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showPalettePaywallDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Pro'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Free accounts can save up to 5 palettes. Upgrade to Pro for unlimited palette saves.'),
              SizedBox(height: 16),
              Text(
                'Pro benefits:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Unlimited palette saves'),
              Text('• Unlimited color story generations'),
              Text('• HD room visualizations'),
              Text('• Priority support'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to upgrade screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgrade feature coming soon!'),
                  ),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Palette'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Palette preview
            Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: widget.paints.map((paint) {
                  final color = ColorUtils.getPaintColor(paint.hex);
                  
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: widget.paints.indexOf(paint) == 0
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                              )
                            : widget.paints.indexOf(paint) == widget.paints.length - 1
                                ? const BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  )
                                : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Palette Name',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tags
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.w500)),
            const Text(
              'Add tags to organize your palettes (room type, mood, style)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            
            // Quick tag suggestions
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _getQuickTags().map((tag) => GestureDetector(
                onTap: () {
                  if (!_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tags.contains(tag) 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _tags.contains(tag)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: _tags.contains(tag)
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.grey[700],
                      fontWeight: _tags.contains(tag) ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              )).toList(),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Add custom tag',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                )).toList(),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePalette,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}