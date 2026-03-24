import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:john_estacio_website/features/auth/data/auth_service.dart';
import 'package:john_estacio_website/theme.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({required this.child, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 720;

        return Scaffold(
          backgroundColor: AppTheme.lightGray,
          onDrawerChanged: (isOpened) {
            setState(() {
              _isDrawerOpen = isOpened;
            });
          },
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.lightGray,
            title: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => context.go('/'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    constraints.maxWidth >= 420
                        ? 'JOHN ESTACIO • COMPOSER'
                        : 'JOHN ESTACIO',
                    style: AppTheme.theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.darkGray,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              StreamBuilder<User?>(
                stream: AuthService().authStateChanges,
                builder: (context, snapshot) {
                  final bool isLoggedIn = snapshot.hasData;
                  return isMobile
                      ? Builder(
                          builder: (context) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: const Icon(Icons.menu, color: AppTheme.darkGray),
                              onPressed: () => Scaffold.of(context).openEndDrawer(),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            _buildNavItem(context, 'Works', '/works'),
                            _buildNavItem(context, 'Discography', '/discography'),
                            _buildPerformancesMenu(context),
                            _buildNavItem(context, 'Bio', '/bio'),
                            _buildNavItem(context, 'Photos', '/photos'),
                            _buildContactMenu(context),
                            if (isLoggedIn)
                              _buildNavItem(context, 'Admin Console', '/admin'),
                            if (!isLoggedIn)
                              IconButton(
                                icon: const Icon(Icons.login, color: AppTheme.darkGray),
                                onPressed: () => context.go('/login'),
                              ),
                            const SizedBox(width: 20),
                          ],
                        );
                },
              ),
            ],
            elevation: 1.0,
            shadowColor: AppTheme.lightGray.withValues(alpha: 0.5),
          ),
          endDrawer: isMobile ? _buildAppDrawer(context) : null,
          body: Visibility(
            visible: !_isDrawerOpen,
            maintainState: false, // This is key: removes the child from the tree
            child: widget.child,
          ),
        );
      },
    );
  }

  Drawer _buildAppDrawer(BuildContext context) {
    return Drawer(
      child: StreamBuilder<User?>(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            final bool isLoggedIn = snapshot.hasData;
            return ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: AppTheme.darkGray,
                  ),
                  child: Text(
                    'JOHN ESTACIO • COMPOSER',
                    style: AppTheme.theme.textTheme.headlineSmall,
                  ),
                ),
                const _DrawerItem(label: 'Home', route: '/'),
                const _DrawerItem(label: 'Works', route: '/works'),
                const _DrawerItem(label: 'Discography', route: '/discography'),
                const _DrawerItem(label: 'Upcoming Performances', route: '/performances/upcoming'),
                const _DrawerItem(label: 'Past Performances', route: '/performances/past'),
                const _DrawerItem(label: 'Bio', route: '/bio'),
                const _DrawerItem(label: 'Photos', route: '/photos'),
                const _DrawerItem(label: 'Get In Touch', route: '/contact'),
                const _DrawerItem(label: 'Request Score(s)', route: '/performances/request'),
                if (isLoggedIn)
                  const _DrawerItem(label: 'Admin Console', route: '/admin'),
                const Divider(),
                if (!isLoggedIn)
                  ListTile(
                    leading: const Icon(Icons.login, color: AppTheme.lightGray),
                    title: const Text(
                      'LOGIN',
                      style: TextStyle(color: AppTheme.lightGray),
                    ),
                    onTap: () {
                      context.go('/login');
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            );
          }),
    );
  }

  Widget _buildNavItem(BuildContext context, String label, String route) {
    final bool isSelected = GoRouterState.of(context).uri.toString().startsWith(route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextButton(
        onPressed: () => context.go(route),
        style: TextButton.styleFrom(
          foregroundColor: isSelected ? AppTheme.primaryOrange : AppTheme.darkGray,
          textStyle: AppTheme.theme.textTheme.labelLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        child: Text(label.toUpperCase()),
      ),
    );
  }

  Widget _buildPerformancesMenu(BuildContext context) {
    // Only highlight PERFORMANCES for the Upcoming/Past routes, not Request Scores
    final uri = GoRouterState.of(context).uri.toString();
    final isActive = uri.startsWith('/performances/upcoming') ||
        uri.startsWith('/performances/past');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: PopupMenuButton<String>(
        tooltip: 'Performances',
        onSelected: (value) => context.go(value),
        itemBuilder: (context) => const [
          PopupMenuItem(value: '/performances/upcoming', child: Text('UPCOMING PERFORMANCES')),
          PopupMenuItem(value: '/performances/past', child: Text('PAST PERFORMANCES')),
        ],
        child: Text(
          'PERFORMANCES',
          style: AppTheme.theme.textTheme.labelLarge?.copyWith(
            color: isActive ? AppTheme.primaryOrange : AppTheme.darkGray,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContactMenu(BuildContext context) {
    final uri = GoRouterState.of(context).uri.toString();
    final isActive = uri.startsWith('/contact') || uri.startsWith('/performances/request');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: PopupMenuButton<String>(
        tooltip: 'Contact',
        onSelected: (value) => context.go(value),
        itemBuilder: (context) => const [
          PopupMenuItem(value: '/contact', child: Text('GET IN TOUCH')),
          PopupMenuItem(value: '/performances/request', child: Text('REQUEST SCORE(S)')),
        ],
        child: Text(
          'CONTACT',
          style: AppTheme.theme.textTheme.labelLarge?.copyWith(
            color: isActive ? AppTheme.primaryOrange : AppTheme.darkGray,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  const _DrawerItem({
    required this.label,
    required this.route,
  });

  final String label;
  final String route;

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final String currentLocation = GoRouterState.of(context).uri.toString();
    final bool isSelected = widget.route == '/'
        ? currentLocation == '/'
        : currentLocation.startsWith(widget.route);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: ListTile(
        title: Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            color: isSelected || _isHovering
                ? AppTheme.primaryOrange
                : AppTheme.lightGray,
          ),
        ),
        onTap: () {
          context.go(widget.route);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}