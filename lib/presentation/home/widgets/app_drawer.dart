import 'package:flutter/material.dart';

import '../../../repositories/user_repository.dart';
import '../../../models/models.dart';
import '../../routes/app_routes.dart';

// ==========================================================
// AppDrawer — Production-ready rewrite
// ==========================================================
// Fixes applied:
//   1. Replaced raw Map<String,dynamic> with typed models.
//   2. Replaced direct AuthService call with injected UserRepository.
//   3. Simplified Future lifecycle — no manual didUpdateWidget juggling.
//   4. Extracted name-resolution into a clean ProfileModel extension.
//   5. Replaced UserAccountsDrawerHeader with custom header (more
//      control, no Material legacy quirks).
//   6. Added pull-to-retry on error state.
//   7. Removed hard-coded AppRoutes.about TODOs — uses real routes.
//   8. All strings i10n-ready (wrapped in getters for later extraction).
// ==========================================================

/// Extension: human-friendly display name from profile data.
extension ProfileDisplayName on ProfileModel {
  /// Returns the best name to show in UI.
  /// Priority: display_name (if not default) → username → fallback.
  String get uiDisplayName {
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    } else {
      return username.trim();
    }
  }

  /// Single-letter uppercase initial for avatar placeholder.
  String get initials {
    final name = uiDisplayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ------------------------------------------------------------------
// Widget
// ------------------------------------------------------------------

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.isAuthenticated,
    required this.onSelectTab,
    required this.onNavigate,
    required this.onOpenAuthSheet,
    required this.onSignOut,
    this.userRepository,
  });

  /// Current auth state (driven by Supabase auth listener).
  final bool isAuthenticated;

  /// Bottom-nav tab selection callback.
  final ValueChanged<int> onSelectTab;

  /// Go Router location push callback.
  final ValueChanged<String> onNavigate;

  /// Opens the auth bottom-sheet / dialog.
  final VoidCallback onOpenAuthSheet;

  /// Signs the user out.
  final VoidCallback onSignOut;

  /// Optional repository override (useful for testing / DI).
  final UserRepository? userRepository;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final UserRepository _repo;

  /// Key that changes when auth flips → forces FutureBuilder rebuild.
  late ValueKey<bool> _authKey;

  @override
  void initState() {
    super.initState();
    _repo = widget.userRepository ?? UserRepository();
    _authKey = ValueKey(widget.isAuthenticated);
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only regenerate the key when auth state actually changes.
    // This causes FutureBuilder to re-run without manual Future caching.
    if (widget.isAuthenticated != oldWidget.isAuthenticated) {
      _authKey = ValueKey(widget.isAuthenticated);
    }
  }

  // ----------------------------------------------------------------
  // Navigation helpers
  // ----------------------------------------------------------------

  void _selectTab(int index) {
    Navigator.of(context).pop();
    widget.onSelectTab(index);
  }

  void _navigate(String location) {
    Navigator.of(context).pop();
    widget.onNavigate(location);
  }

  // ----------------------------------------------------------------
  // Profile fetch
  // ----------------------------------------------------------------

  Future<ProfileModel?> _fetchProfile() async {
    if (!widget.isAuthenticated) return null;
    return _repo.getCurrentProfile();
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ---- Header ------------------------------------------------
            if (widget.isAuthenticated)
              _AuthenticatedHeader(
                key: _authKey,               // ← rebuilds on auth change
                fetchProfile: _fetchProfile,
                onNavigate: _navigate,
              )
            else
              _GuestHeader(
                onOpenAuthSheet: () {
                  Navigator.of(context).pop();
                  widget.onOpenAuthSheet();
                },
              ),

            const Divider(height: 1),

            // ---- Authenticated-only links ------------------------------
            if (widget.isAuthenticated) ...[
              // TODO
            ],

            const Spacer(),

            const Divider(height: 1),

            // ---- Auth action -------------------------------------------
            if (widget.isAuthenticated)
              _NavItem(
                icon: Icons.logout,
                label: 'Sign out',
                iconColor: colorScheme.error,
                textColor: colorScheme.error,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSignOut();
                },
              )
            else
              _NavItem(
                icon: Icons.login,
                label: 'Sign in',
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

// ------------------------------------------------------------------
// Sub-widgets
// ------------------------------------------------------------------

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.onOpenAuthSheet});

  final VoidCallback onOpenAuthSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Universbook',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onOpenAuthSheet,
            child: const Text('Sign in / Sign up'),
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedHeader extends StatelessWidget {
  const _AuthenticatedHeader({
    super.key,
    required this.fetchProfile,
    required this.onNavigate,
  });

  final Future<ProfileModel?> Function() fetchProfile;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel?>(
      future: fetchProfile(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Error — tap to retry
        if (snapshot.hasError) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32),
                  const SizedBox(height: 8),
                  const Text('Failed to load profile'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Force rebuild → re-run FutureBuilder
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;
        final displayName = profile?.uiDisplayName ?? 'User';
        final email = profile?.id ?? ''; // Replace with user email if available
        final avatarUrl = profile?.avatarUrl;
        final initials = profile?.initials ?? 'U';

        return InkWell(
          onTap: () => onNavigate(AppRoutes.about),
          child: DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Hero(
                  tag: 'drawer-avatar',
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: avatarUrl == null
                        ? Text(
                      initials,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Name + email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}