import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../routes/app_routes.dart';

/// Drawer shown from HomePage.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.isAuthenticated,
    required this.onSelectTab,
    required this.onNavigate,
    required this.onOpenAuthSheet,
    required this.onSignOut,
  });

  /// Current auth state.
  final bool isAuthenticated;

  /// Bottom navigation callback.
  final ValueChanged<int> onSelectTab;

  /// Route navigation callback.
  final ValueChanged<String> onNavigate;

  /// Opens the authentication sheet.
  final VoidCallback onOpenAuthSheet;

  /// Signs the user out.
  final VoidCallback onSignOut;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Future<Map<String, dynamic>>? _profileFuture;

  @override
  void initState() {
    super.initState();
    if (widget.isAuthenticated) {
      _profileFuture = _loadProfile();
    }
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only refetch when auth state actually flips (e.g. sign in/out),
    // not on every rebuild HomePage triggers (tab switches, etc.).
    if (widget.isAuthenticated != oldWidget.isAuthenticated) {
      setState(() {
        _profileFuture = widget.isAuthenticated ? _loadProfile() : null;
      });
    }
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final authService = AuthService.instance;
    final profile = await authService.fetchCurrentProfile();
    final user = authService.currentUser;

    final username = profile?['username'] as String?;
    final displayName = profile?['display_name'] as String?;
    final avatarUrl = profile?['avatar_url'] as String?;
    final email = user?.email;

    return {
      'displayName': displayName ?? username ?? 'User',
      'email': email ?? '',
      'avatarUrl': avatarUrl,
      'initials': (displayName ?? username ?? 'U').substring(0, 1).toUpperCase(),
    };
  }

  void _selectTab(BuildContext context, int index) {
    Navigator.of(context).pop();
    widget.onSelectTab(index);
  }

  void _navigate(BuildContext context, String location) {
    Navigator.of(context).pop();
    widget.onNavigate(location);
  }

  Widget _buildGuestHeader(BuildContext context) {
    return DrawerHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Universbook',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenAuthSheet();
            },
            child: const Text('Sign in / Sign up'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (!widget.isAuthenticated || _profileFuture == null) {
      return _buildGuestHeader(context);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DrawerHeader(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const DrawerHeader(
            child: Center(
              child: Text('Failed to load profile'),
            ),
          );
        }

        final data = snapshot.data;

        final displayName = data?['displayName'] as String? ?? 'User';
        final email = data?['email'] as String? ?? '';
        final avatarUrl = data?['avatarUrl'] as String?;
        final initials = data?['initials'] as String? ?? 'U';

        return UserAccountsDrawerHeader(
          accountName: Text(displayName),
          accountEmail: Text(email),
          currentAccountPicture: CircleAvatar(
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? Text(initials) : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            ListTile(
              leading: const Icon(Icons.dynamic_feed_outlined),
              title: const Text('Feed'),
              onTap: () => _selectTab(context, 0),
            ),

            ListTile(
              leading: const Icon(Icons.subscriptions_outlined),
              title: const Text('Subscribe'),
              onTap: () => _selectTab(context, 1),
            ),

            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Library'),
              onTap: () => _selectTab(context, 2),
            ),

            const Divider(),

            if (widget.isAuthenticated) ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                // TODO: point at a real profile route once one exists —
                // both this and Settings currently go to AppRoutes.about.
                onTap: () => _navigate(context, AppRoutes.about),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                // TODO: point at a real settings route once one exists.
                onTap: () => _navigate(context, AppRoutes.about),
              ),
            ],

            const Spacer(),

            const Divider(),

            if (widget.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSignOut();
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onOpenAuthSheet();
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}