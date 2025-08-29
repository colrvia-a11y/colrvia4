import 'package:flutter/material.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/login_screen.dart';
import 'package:color_canvas/screens/admin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _harmonyModesEnabled = true;
  bool _brandDiversityEnabled = true;
  bool _isAdmin = false;
  
  // Color Story preferences
  bool _autoPlayStoryAudio = false;
  bool _reduceMotion = false;  
  bool _wifiOnlyForStoryAssets = false;
  String _defaultStoryVisibility = 'private';
  String _ambientAudioMode = 'off';
  int _paintCount = 0;
  int _brandCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppStats();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      try {
        final profile = await FirebaseService.getUserProfile(user.uid);
        final adminStatus = await FirebaseService.checkAdminStatus(user.uid);
        await _loadColorStoryPreferences();
        setState(() {
          _userProfile = profile;
          _isAdmin = adminStatus;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadColorStoryPreferences() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseService.getUserDocument(user.uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        setState(() {
          _autoPlayStoryAudio = data['autoPlayStoryAudio'] ?? false;
          _reduceMotion = data['reduceMotion'] ?? false;
          _wifiOnlyForStoryAssets = data['wifiOnlyAssets'] ?? false;
          _defaultStoryVisibility = data['defaultStoryVisibility'] ?? 'private';
          _ambientAudioMode = data['ambientAudioMode'] ?? 'off';
        });
      }
    } catch (e) {
      // Use defaults if loading fails
    }
  }

  Future<void> _saveColorStoryPreferences() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseService.updateUserColorStoryPreferences(
        uid: user.uid,
        autoPlayStoryAudio: _autoPlayStoryAudio,
        reduceMotion: _reduceMotion,
        wifiOnlyAssets: _wifiOnlyForStoryAssets,
        defaultStoryVisibility: _defaultStoryVisibility,
        ambientAudioMode: _ambientAudioMode,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    }
  }

  Future<void> _loadAppStats() async {
    try {
      final paints = await FirebaseService.getAllPaints();
      final brands = await FirebaseService.getAllBrands();
      setState(() {
        _paintCount = paints.length;
        _brandCount = brands.length;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseService.signOut();
      setState(() {
        _userProfile = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _toggleAdminMode() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    try {
      final newAdminStatus = !_isAdmin;
      await FirebaseService.toggleAdminPrivileges(user.uid, newAdminStatus);
      
      // Reload user profile to get updated data
      await _loadUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newAdminStatus 
                ? 'Admin privileges enabled' 
                : 'Admin privileges disabled'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating admin status: $e')),
        );
      }
    }
  }

  void _showLoginScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    ).then((_) {
      // Refresh user data when returning from login
      _loadUserData();
    });
  }
  
  Future<void> _showFirebaseDebug(BuildContext context) async {
    final firebaseStatus = await FirebaseService.getFirebaseStatus();
    
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Firebase Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Auth Status: ${firebaseStatus['isAuthenticated'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('User ID: ${firebaseStatus['userId'] ?? 'None'}'),
                const SizedBox(height: 8),
                Text('User Email: ${firebaseStatus['userEmail'] ?? 'None'}'),
                const SizedBox(height: 8),
                Text('Firestore Online: ${firebaseStatus['isFirestoreOnline'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                if (firebaseStatus['error'] != null) ...[
                  const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text('${firebaseStatus['error']}', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('• Using placeholder Firebase project\n• Only web platform configured\n• Security rules not deployed\n• Need to connect real Firebase project'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User section
                _buildUserSection(),
                const SizedBox(height: 24),
                
                // App preferences
                _buildPreferencesSection(),
                const SizedBox(height: 24),
                
                // App info
                _buildAppInfoSection(),
                const SizedBox(height: 24),
                
                // About section
                _buildAboutSection(),
              ],
            ),
    );
  }

  Widget _buildUserSection() {
    final user = FirebaseService.currentUser;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'G',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? 'Guest User',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_userProfile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_userProfile!.plan.toUpperCase()} plan',
                          style: TextStyle(
                            color: _userProfile!.plan == 'free' 
                                ? Colors.grey[600] 
                                : Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_userProfile!.paletteCount}/10 palettes saved',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Auth buttons
            if (user == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showLoginScreen,
                  child: const Text('Sign In'),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Upgrade to Pro feature coming soon'),
                          ),
                        );
                      },
                      child: const Text('Upgrade to Pro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferences',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Enable Harmony Modes'),
              subtitle: const Text('Use color theory-based palette generation'),
              value: _harmonyModesEnabled,
              onChanged: (value) {
                setState(() => _harmonyModesEnabled = value);
                // TODO: Save to SharedPreferences
              },
            ),
            
            SwitchListTile(
              title: const Text('Brand Diversity'),
              subtitle: const Text('Prefer mixing different paint brands'),
              value: _brandDiversityEnabled,
              onChanged: (value) {
                setState(() => _brandDiversityEnabled = value);
                // TODO: Save to SharedPreferences
              },
            ),
            
            const Divider(),
            
            // Color Story Settings
            const ListTile(
              title: Text('Color Story Settings'),
              subtitle: Text('Preferences for AI-generated color stories'),
              dense: true,
            ),
            
            SwitchListTile(
              title: const Text('Auto-play story audio'),
              subtitle: const Text('Automatically play ambient audio when viewing stories'),
              value: _autoPlayStoryAudio,
              onChanged: (value) {
                setState(() => _autoPlayStoryAudio = value);
                _saveColorStoryPreferences();
              },
            ),
            
            SwitchListTile(
              title: const Text('Reduce motion'),
              subtitle: const Text('Turn off parallax and background animations'),
              value: _reduceMotion,
              onChanged: (value) {
                setState(() => _reduceMotion = value);
                _saveColorStoryPreferences();
              },
            ),
            
            SwitchListTile(
              title: const Text('Wi-Fi only for story assets'),
              subtitle: const Text('Download images and audio only on Wi-Fi'),
              value: _wifiOnlyForStoryAssets,
              onChanged: (value) {
                setState(() => _wifiOnlyForStoryAssets = value);
                _saveColorStoryPreferences();
              },
            ),
            
            ListTile(
              title: const Text('Default visibility for new stories'),
              subtitle: Text('New stories will be $_defaultStoryVisibility by default'),
              trailing: DropdownButton<String>(
                value: _defaultStoryVisibility,
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'unlisted', child: Text('Unlisted')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _defaultStoryVisibility = value);
                    _saveColorStoryPreferences();
                  }
                },
              ),
            ),
            
            // Admin toggle - only show for logged-in users
            if (FirebaseService.currentUser != null) ...[
              const Divider(),
              SwitchListTile(
                title: Row(
                  children: [
                    const Text('Admin Mode'),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.admin_panel_settings,
                      size: 18,
                      color: _isAdmin ? Colors.orange : Colors.grey,
                    ),
                  ],
                ),
                subtitle: const Text('Enable admin privileges for data management'),
                value: _isAdmin,
                onChanged: (value) => _toggleAdminMode(),
                activeColor: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paint Database',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Colors'),
                Text(
                  '$_paintCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paint Brands'),
                Text(
                  '$_brandCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            if (_brandCount > 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Includes Sherwin-Williams, Benjamin Moore, and Behr',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Admin button - only show for development
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Import Paint Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Paint Roller',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Paint Roller is a mobile-first color palette generator featuring real paint colors from leading brands. Roll, lock, refine, and visualize your perfect color combinations.',
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Version'),
                const Text('1.0.0'),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Built with'),
                const Text('Flutter & Firebase'),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy Policy feature coming soon'),
                        ),
                      );
                    },
                    child: const Text('Privacy Policy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terms of Service feature coming soon'),
                        ),
                      );
                    },
                    child: const Text('Terms'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showFirebaseDebug(context),
                icon: const Icon(Icons.bug_report),
                label: const Text('Debug Firebase Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}