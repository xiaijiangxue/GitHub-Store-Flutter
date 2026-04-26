import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/apps/presentation/apps_screen.dart';
import '../../features/details/presentation/details_screen.dart';
import '../../features/dev_profile/presentation/dev_profile_screen.dart';
import '../../features/download/presentation/download_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/installer/presentation/installer_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/recently_viewed/presentation/recently_viewed_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/starred/presentation/starred_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';

/// Enum for all named routes in the app.
enum AppRoute {
  home,
  search,
  details,
  download,
  installer,
  apps,
  favorites,
  starred,
  recentlyViewed,
  devProfile,
  profile,
  settings,
}

/// Provider for the GoRouter instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home.path,
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => _ErrorScreen(
      message: 'Page not found: ${state.uri.path}',
    ),
    redirect: (context, state) {
      // Add authentication guards here if needed
      return null;
    },
    routes: [
      // ── Shell Route with Bottom Navigation ─────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home.path,
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Apps (Categories)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.apps.path,
                name: AppRoute.apps.name,
                builder: (context, state) => const AppsScreen(),
              ),
            ],
          ),
          // Tab 2: Search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.search.path,
                name: AppRoute.search.name,
                builder: (context, state) {
                  final query = state.uri.queryParameters['q'];
                  return SearchScreen(initialQuery: query);
                },
              ),
            ],
          ),
          // Tab 3: Favorites / Starred
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.favorites.path,
                name: AppRoute.favorites.name,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Detail & Secondary Routes (outside bottom nav) ────────────────
      GoRoute(
        path: AppRoute.details.path,
        name: AppRoute.details.name,
        builder: (context, state) {
          final owner = state.pathParameters['owner']!;
          final repo = state.pathParameters['repo']!;
          return DetailsScreen(owner: owner, repo: repo);
        },
      ),
      GoRoute(
        path: AppRoute.download.path,
        name: AppRoute.download.name,
        builder: (context, state) {
          final owner = state.pathParameters['owner']!;
          final repo = state.pathParameters['repo']!;
          final tag = state.pathParameters['tag'];
          final asset = state.uri.queryParameters['asset'];
          return DownloadScreen(
            owner: owner,
            repo: repo,
            tag: tag,
            assetName: asset,
          );
        },
      ),
      GoRoute(
        path: AppRoute.installer.path,
        name: AppRoute.installer.name,
        builder: (context, state) {
          final owner = state.pathParameters['owner']!;
          final repo = state.pathParameters['repo']!;
          final filePath = state.uri.queryParameters['filePath'];
          return InstallerScreen(
            owner: owner,
            repo: repo,
            filePath: filePath,
          );
        },
      ),
      GoRoute(
        path: AppRoute.starred.path,
        name: AppRoute.starred.name,
        builder: (context, state) => const StarredScreen(),
      ),
      GoRoute(
        path: AppRoute.recentlyViewed.path,
        name: AppRoute.recentlyViewed.name,
        builder: (context, state) => const RecentlyViewedScreen(),
      ),
      GoRoute(
        path: AppRoute.devProfile.path,
        name: AppRoute.devProfile.name,
        builder: (context, state) {
          final username = state.pathParameters['username']!;
          return DevProfileScreen(username: username);
        },
      ),
      GoRoute(
        path: AppRoute.settings.path,
        name: AppRoute.settings.name,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
});

// ── Extension for route paths ─────────────────────────────────────────────

extension AppRoutePath on AppRoute {
  String get path => switch (this) {
        AppRoute.home => '/',
        AppRoute.search => '/search',
        AppRoute.details => '/details/:owner/:repo',
        AppRoute.download => '/download/:owner/:repo/:tag',
        AppRoute.installer => '/installer/:owner/:repo',
        AppRoute.apps => '/apps',
        AppRoute.favorites => '/favorites',
        AppRoute.starred => '/starred',
        AppRoute.recentlyViewed => '/recently-viewed',
        AppRoute.devProfile => '/dev/:username',
        AppRoute.profile => '/profile',
        AppRoute.settings => '/settings',
      };

  /// Build a path with parameters.
  String withParams(Map<String, String> params) {
    String result = path;
    for (final entry in params.entries) {
      result = result.replaceAll(':${entry.key}', entry.value);
    }
    return result;
  }
}

// ── Shell Scaffold with Bottom Navigation ─────────────────────────────────

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ── Error Screen ──────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
