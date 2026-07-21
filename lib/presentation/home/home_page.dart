import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universbook/core/services/auth_service.dart';

import '../routes/app_routes.dart';
import 'widgets/feed_tab.dart';
import 'widgets/subscribe_tab.dart';
import 'widgets/library_tab.dart';
import 'widgets/auth_bottom_sheet.dart';
import 'widgets/app_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isAuthenticated = AuthService.instance.currentSession != null;

  @override
  void initState() {
    super.initState();

    // Listen to auth state changes
    AuthService.instance.authStateChanges.listen((data) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = data.session != null;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isAuthenticated && mounted) {
        _openAuthSheet();
      }
    });
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _handleSignIn(String email, String password) async {
    await AuthService.instance.signInWithEmail(email, password);
  }

  Future<void> _handleSignUp(String email, String password) async {
    await AuthService.instance.signUpWithEmail(email, password);
  }

  void _openAuthSheet() {
    showAuthBottomSheet(
      context,
      onSignIn: _handleSignIn,
      onSignUp: _handleSignUp,
    );
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
  }

  void _navigateTo(String location) {
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FeedTab(),
      const SubscribeTab(),
      const LibraryTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Universbook"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.go(AppRoutes.search),
          )
        ],
      ),
      drawer: AppDrawer(
        isAuthenticated: _isAuthenticated,
        onSelectTab: _onDestinationSelected,
        onNavigate: _navigateTo,
        onOpenAuthSheet: _openAuthSheet,
        onSignOut: _handleSignOut,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: 'Subscribe',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}