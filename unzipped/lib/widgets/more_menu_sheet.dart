import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/screens/library_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'dart:ui';

class MoreMenuSheet extends StatefulWidget {
  final bool autofocusSearch;
  final void Function(String)? onOpenSearch;
  
  const MoreMenuSheet({
    super.key,
    this.autofocusSearch = false,
    this.onOpenSearch,
  });

  @override
  State<MoreMenuSheet> createState() => _MoreMenuSheetState();
}

class _MoreMenuSheetState extends State<MoreMenuSheet>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    
    HapticFeedback.selectionClick();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 210),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    _scaleController.forward();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = '1.0.0'; // Static version for now
    });
  }

  void _dismissSheet() {
    Navigator.of(context).pop();
  }

  void _onSearchSubmit(String query) {
    if (query.trim().isEmpty) return;
    if (widget.onOpenSearch != null) {
      widget.onOpenSearch!(query.trim());
      return;
    }
    // fallback (Plan A logic)
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: query.trim())),
      );
    });
  }

  void _navigateToSaved() {
    Navigator.of(context).pop(); // Close sheet first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LibraryScreen(initialFilter: LibraryFilter.palettes),
      ),
    );
  }

  void _navigateToAccount() {
    Navigator.of(context).pop(); // Close sheet first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final user = FirebaseService.currentUser;
    
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            Navigator.of(context).pop();
            return null;
          }),
        },
        child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                height: mediaQuery.size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity( 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: Column(
                        children: [
                          // Search Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: TextField(
                              controller: _searchController,
                              autofocus: widget.autofocusSearch,
                              decoration: InputDecoration(
                                hintText: 'Search paints, palettes, rooms…',
                                hintStyle: TextStyle(
                                  color: Colors.black.withOpacity( 0.5),
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.black.withOpacity( 0.7),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity( 0.1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity( 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onSubmitted: _onSearchSubmit,
                            ),
                          ),
                          
                          // Primary Items
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                _buildMenuItem(
                                  icon: Icons.bookmark_border,
                                  title: 'Saved',
                                  onTap: _navigateToSaved,
                                  showBadge: false, // TODO: implement badge logic
                                ),
                                _buildMenuItem(
                                  icon: Icons.person_outline,
                                  title: 'Account',
                                  onTap: _navigateToAccount,
                                ),
                                
                                // Secondary Section
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                  child: Text(
                                    'MORE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withOpacity( 0.7),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                
                                _buildMenuItem(
                                  icon: Icons.auto_awesome,
                                  title: "What's New",
                                  onTap: () => _showComingSoon("What's New"),
                                ),
                                _buildMenuItem(
                                  icon: Icons.chat_bubble_outline,
                                  title: 'Feedback',
                                  onTap: () => _showComingSoon('Feedback'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.help_outline,
                                  title: 'FAQ',
                                  onTap: () => _showComingSoon('FAQ'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.support_agent,
                                  title: 'Support',
                                  onTap: () => _showComingSoon('Support'),
                                ),
                                _buildMenuItem(
                                  icon: Icons.gavel_outlined,
                                  title: 'Legal',
                                  onTap: () => _showComingSoon('Legal'),
                                ),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                          
                          // Sticky Footer
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(
                                  color: Colors.black.withOpacity( 0.08),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                children: [
                                  // Auth Section
                                  if (user != null) ...[
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.grey[300],
                                          child: Text(
                                            user.email?.substring(0, 1).toUpperCase() ?? 'U',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.email ?? 'User',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              await FirebaseService.signOut();
                                              if (mounted) {
                                                Navigator.of(context).pop();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Signed out successfully'),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error signing out: $e')),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text(
                                            'Sign out',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pushNamed('/login');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Sign in',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  
                                  // Version
                                  const SizedBox(height: 12),
                                  Text(
                                    'Version $_appVersion',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black.withOpacity( 0.5),
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
              ),
            ),
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      onHover: (hovering) {
        if (hovering) {
          HapticFeedback.selectionClick();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: Colors.black.withOpacity( 0.8),
                  size: 24,
                ),
                if (showBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}