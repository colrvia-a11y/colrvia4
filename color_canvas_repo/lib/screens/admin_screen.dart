import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:color_canvas/utils/paint_data_importer.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/widgets/auth_dialog.dart';
import 'package:color_canvas/screens/story_studio_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _jsonController = TextEditingController();
  bool _isLoading = false;
  Map<String, int> _dataCount = {'paints': 0, 'brands': 0};
  bool _isAdmin = false;
  bool _checkingAdmin = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminStatus();
    _loadDataCount();
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _checkingAdmin = true;
    });
    
    try {
      final isAdmin = await FirebaseService.isCurrentUserAdmin();
      setState(() {
        _isAdmin = isAdmin;
        _checkingAdmin = false;
      });
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
      });
    }
  }

  Future<void> _loadDataCount() async {
    try {
      final count = await PaintDataImporter.getDataCount();
      setState(() {
        _dataCount = count;
      });
    } catch (e) {
      _setStatus('Error loading data count: $e', isError: true);
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _importData() async {
    if (_jsonController.text.trim().isEmpty) {
      _setStatus('Please enter JSON data', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final jsonData = jsonDecode(_jsonController.text);
      List<Map<String, dynamic>> paintList = [];

      if (jsonData is List) {
        paintList = List<Map<String, dynamic>>.from(jsonData);
      } else if (jsonData is Map && jsonData['paints'] != null) {
        paintList = List<Map<String, dynamic>>.from(jsonData['paints']);
      } else {
        throw Exception('Invalid JSON format. Expected array or object with "paints" key.');
      }

      await PaintDataImporter.importFromJson(paintList);
      _setStatus('✅ Successfully imported ${paintList.length} paints!');
      _jsonController.clear();
      await _loadDataCount();

    } catch (e) {
      _setStatus('❌ Import failed: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete ALL paint and brand data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await PaintDataImporter.clearAllPaintData();
      _setStatus('✅ All data cleared successfully');
      await _loadDataCount();
    } catch (e) {
      _setStatus('❌ Clear failed: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runBrandIdMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Brand IDs'),
        content: const Text('This will standardize brand IDs and fix any inconsistencies, especially for Sherwin-Williams. This is safe to run.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Migration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AdminMigrations.fixSherwinBrandIds();
      _setStatus('✅ Brand ID migration completed successfully');
      await _loadDataCount();
    } catch (e) {
      _setStatus('❌ Migration failed: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDataFormat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expected Data Format'),
        content: const SingleChildScrollView(
          child: Text('''Your JSON should be an array of objects with these fields:

[
  {
    "brandName": "Sherwin-Williams",
    "name": "Alabaster",
    "code": "SW 7008",
    "hex": "#F2F0E8"
  },
  {
    "brandName": "Benjamin Moore",
    "name": "White Dove",
    "code": "OC-17",
    "hex": "#F7F5F3"
  }
]

Or wrapped in an object:
{
  "paints": [
    // ... paint objects
  ]
}

Required fields:
• brandName: Paint brand name
• name: Paint color name  
• code: Paint color code
• hex: Hex color value (with or without #)'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _pasteFromClipboard() async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipData?.text != null) {
        setState(() {
          _jsonController.text = clipData!.text!;
        });
      }
    } catch (e) {
      _setStatus('Error pasting from clipboard: $e', isError: true);
    }
  }

  Future<void> _importFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsString();
        
        setState(() {
          _jsonController.text = contents;
        });
        
        _setStatus('✅ File loaded successfully');
      }
    } catch (e) {
      _setStatus('❌ Error loading file: $e', isError: true);
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(
        onAuthSuccess: () {
          Navigator.pop(context);
          _checkAdminStatus();
          _loadDataCount();
        },
      ),
    );
  }

  void _openColorStoryWizard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoryStudioScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (user == null)
            TextButton(
              onPressed: _showAuthDialog,
              child: const Text('Sign In', style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: _checkingAdmin || user == null || !_isAdmin
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.storage), text: 'Data Import'),
                  Tab(icon: Icon(Icons.palette), text: 'Story Studio'),
                  Tab(icon: Icon(Icons.build), text: 'Maintenance'),
                  Tab(icon: Icon(Icons.people), text: 'User Management'),
                ],
              ),
      ),
      body: _checkingAdmin
        ? _buildLoadingView()
        : user == null 
        ? _buildAuthRequiredView()
        : !_isAdmin
        ? _buildNotAuthorizedView()
        : TabBarView(
            controller: _tabController,
            children: [
              _buildDataImportTab(),
              _buildStoryStudioTab(),
              _buildMaintenanceTab(),
              _buildUserManagementTab(),
            ],
          ),
    );
  }

  Widget _buildDataImportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current Data Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Database',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Brands: ${_dataCount['brands']}'),
                  Text('Paints: ${_dataCount['paints']}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _loadDataCount,
                        child: const Text('Refresh Count'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _runBrandIdMigration,
                        icon: const Icon(Icons.build),
                        label: const Text('Fix Brand IDs'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Import Section
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Import Paint Data',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showDataFormat,
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Format'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Import options buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _importFromFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Import File'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.paste),
                            label: const Text('Paste Data'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    const Text('Import JSON data from file or paste directly below:'),
                    const SizedBox(height: 8),
                    
                    Expanded(
                      child: TextField(
                        controller: _jsonController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Paste JSON data here...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _importData,
                            child: _isLoading 
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Importing...'),
                                  ],
                                )
                              : const Text('Import Data'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _clearData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryStudioTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.palette,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Story Studio',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create beautiful Color Stories for users to discover and explore. Build curated palettes with themes, moods, and room contexts.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openColorStoryWizard,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create Color Story'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Multi-step wizard coming soon',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Maintenance Tools Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.build,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Maintenance Tools',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'One-tap tools for maintaining data integrity and performance.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Maintenance Actions
          Expanded(
            child: Column(
              children: [
                // Backfill Facets
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_fix_high, color: Colors.blue),
                    title: const Text('Backfill Facets'),
                    subtitle: const Text('Update all Color Stories with facets field for efficient filtering'),
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : () => _confirmAndRun(
                        title: 'Backfill Facets',
                        message: 'This will update all Color Stories with the facets field. This is safe to run multiple times.',
                        action: _backfillFacets,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                      ),
                      child: const Text('Run'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Verify Indexes
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.search, color: Colors.orange),
                    title: const Text('Verify Indexes'),
                    subtitle: const Text('Check if required Firestore indexes are properly configured'),
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : () => _confirmAndRun(
                        title: 'Verify Indexes',
                        message: 'This will test the Explore query to verify indexes are configured correctly.',
                        action: _verifyIndexes,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange.shade700,
                      ),
                      child: const Text('Check'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Find Missing Required Roles
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: const Text('Find Missing Required Roles'),
                    subtitle: const Text('Identify Color Stories missing main or trim roles'),
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : () => _confirmAndRun(
                        title: 'Find Missing Roles',
                        message: 'This will scan all Color Stories for missing main or trim roles.',
                        action: _findMissingRequiredRoles,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                      ),
                      child: const Text('Scan'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Checking admin permissions...'),
        ],
      ),
    );
  }

  Widget _buildAuthRequiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You need to sign in to import paint data into Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAuthDialog,
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAuthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Admin Access Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You need admin privileges to import paint data.\nContact an administrator to request access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _checkAdminStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }

  /// Generic confirmation dialog wrapper for maintenance actions
  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await action();
      } catch (e) {
        _setStatus('❌ Operation failed: $e', isError: true);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Backfill facets for all Color Stories
  Future<void> _backfillFacets() async {
    try {
      final result = await FirebaseService.backfillColorStoryFacets();
      final processed = result['processedCount'] ?? 0;
      final updated = result['updatedCount'] ?? 0;
      final skipped = processed - updated;
      _setStatus('✅ Backfilled facets for $updated stories ($skipped already had facets)');
    } catch (e) {
      throw Exception('Facets backfill failed: $e');
    }
  }

  /// Verify that required Firestore indexes exist
  Future<void> _verifyIndexes() async {
    try {
      // Run a test query that requires the composite index
      await FirebaseService.getColorStoriesWithCursor(
        limit: 1,
      );
      
      _setStatus('✅ Indexes verified successfully - query executed without errors');
    } catch (e) {
      final errorMessage = e.toString();
      
      if (errorMessage.contains('index') || errorMessage.contains('requires an index')) {
        // Show detailed index error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Index Required'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Firestore requires a composite index for the Explore query:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please create the required indexes in the Firebase Console or deploy firestore.indexes.json.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _setStatus('❌ Index verification failed: $e', isError: true);
      }
    }
  }

  /// Find Color Stories missing main or trim roles
  Future<void> _findMissingRequiredRoles() async {
    try {
      // Get all color stories to check their roles
      final allStories = await FirebaseService.getAllColorStoriesForMaintenance();
      final missingRoles = <Map<String, dynamic>>[];
      
      for (final story in allStories) {
        final palette = story['palette'] as List? ?? [];
        final roles = palette.map((p) => p['role']).toSet();
        final missingMainOrTrim = <String>[];
        
        if (!roles.contains('main')) missingMainOrTrim.add('main');
        if (!roles.contains('trim')) missingMainOrTrim.add('trim');
        
        if (missingMainOrTrim.isNotEmpty) {
          missingRoles.add({
            'title': story['title'],
            'slug': story['slug'],
            'id': story['id'],
            'missingRoles': missingMainOrTrim,
          });
        }
      }
      
      if (missingRoles.isEmpty) {
        _setStatus('✅ All Color Stories have required main and trim roles');
      } else {
        // Show detailed results dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Missing Required Roles (${missingRoles.length} stories)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: missingRoles.length,
                itemBuilder: (context, index) {
                  final story = missingRoles[index];
                  final missing = (story['missingRoles'] as List<String>).join(', ');
                  
                  return ListTile(
                    dense: true,
                    title: Text(story['title']),
                    subtitle: Text('Slug: ${story['slug']} • Missing: $missing'),
                    leading: Icon(
                      Icons.warning,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        
        _setStatus('⚠️ Found ${missingRoles.length} stories with missing required roles');
      }
    } catch (e) {
      throw Exception('Role audit failed: $e');
    }
  }

  Widget _buildUserManagementTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Management Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'User Management',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage user accounts, subscriptions, and permissions.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Actions
          Expanded(
            child: Column(
              children: [
                // Upgrade specific user to Pro
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: const Text('Upgrade Testing Account to Pro'),
                    subtitle: const Text('Upgrade tchamilton64@gmail.com to Pro status for unlimited testing'),
                    trailing: ElevatedButton(
                      onPressed: _isLoading ? null : () => _confirmAndRun(
                        title: 'Upgrade User to Pro',
                        message: 'This will upgrade tchamilton64@gmail.com to Pro status with unlimited generations and palettes.\n\nThis is for testing purposes only.',
                        action: _upgradeTestUserToPro,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade50,
                        foregroundColor: Colors.amber.shade700,
                      ),
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Info Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pro User Benefits',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Unlimited color story generations\n'
                                '• Unlimited palette saves\n'
                                '• Full access to AI features\n'
                                '• No monthly limits',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Upgrade test user to Pro status for unlimited testing
  Future<void> _upgradeTestUserToPro() async {
    try {
      await FirebaseService.upgradeUserToPro('tchamilton64@gmail.com');
      _setStatus('✅ Successfully upgraded tchamilton64@gmail.com to Pro status! You now have unlimited generations and palettes.');
    } catch (e) {
      throw Exception('Failed to upgrade user: $e');
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}