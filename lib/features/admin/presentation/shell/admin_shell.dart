import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:john_estacio_website/features/auth/data/auth_service.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/quick_bug_entry.dart';
import 'package:john_estacio_website/features/admin/presentation/messages/data/messages_repository.dart';
import 'package:john_estacio_website/theme.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 720;
        final currentRoute = GoRouterState.of(context).uri.toString();
        final selectedIndex = _getSelectedIndex(currentRoute);

        // Stream unread message count
        final MessagesRepository messagesRepository = MessagesRepository();
        final Stream<int> unreadCountStream = messagesRepository
            .getMessagesStream()
            .map((messages) => messages.where((m) => !m.isRead).length);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Console'),
            backgroundColor: AppTheme.darkGray,
            foregroundColor: AppTheme.white,
            leading: isMobile
                ? Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  )
                : null,
          ),
          drawer: isMobile ? _buildDrawer(context, selectedIndex, unreadCountStream) : null,
          body: isMobile
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: child,
                    ),
                  ),
                )
              : Row(
                  children: [
                    NavigationRail(
                      backgroundColor: AppTheme.white,
                      extended: true,
                      minExtendedWidth: 200,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) {
                        _onDestinationSelected(context, index);
                      },
                      unselectedIconTheme: const IconThemeData(color: AppTheme.darkGray),
                      selectedIconTheme: const IconThemeData(color: AppTheme.primaryOrange),
                      unselectedLabelTextStyle: const TextStyle(color: AppTheme.darkGray),
                      selectedLabelTextStyle: const TextStyle(color: AppTheme.primaryOrange),
                      destinations: [
                        const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                        const NavigationRailDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: Text('Works')),
                        const NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Categories')),
                        const NavigationRailDestination(icon: Icon(Icons.album_outlined), selectedIcon: Icon(Icons.album), label: Text('Discography')),
                        const NavigationRailDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: Text('Performances')),
                        const NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Bio')),
                        const NavigationRailDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: Text('Photo Gallery')),
                        // Messages: show unread count beside label only (no icon badge)
                        NavigationRailDestination(
                          icon: const Icon(Icons.mail_outline),
                          selectedIcon: const Icon(Icons.mail),
                          label: StreamBuilder<int>(
                            stream: unreadCountStream,
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Messages'),
                                  if (count > 0) ...[
                                    const SizedBox(width: 8),
                                    _UnreadPill(count: count),
                                  ]
                                ],
                              );
                            },
                          ),
                        ),
                        const NavigationRailDestination(icon: Icon(Icons.folder_copy_outlined), selectedIcon: Icon(Icons.folder_copy), label: Text('Stored Files')),
                        const NavigationRailDestination(icon: Icon(Icons.bug_report_outlined), selectedIcon: Icon(Icons.bug_report), label: Text('Bug Reporting')),
                        const NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                        const NavigationRailDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: Text('View Live Site')),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryOrange,
                                      foregroundColor: AppTheme.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => showQuickAddBugDialog(context),
                                    icon: const Icon(Icons.bug_report),
                                    label: const Text('Report bug/feature'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  icon: const Icon(Icons.logout, color: AppTheme.darkGray),
                                  label: const Text('Logout', style: TextStyle(color: AppTheme.darkGray)),
                                  onPressed: () async {
                                    await AuthService().signOut();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Container(
                        color: AppTheme.lightGray,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Drawer _buildDrawer(BuildContext context, int selectedIndex, Stream<int> unreadCountStream) {
    return Drawer(
      backgroundColor: AppTheme.white,
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.darkGray),
            child: Text(
              'Admin Menu',
              style: TextStyle(color: AppTheme.white, fontSize: 24),
            ),
          ),
          _buildDrawerItem(context, icon: Icons.dashboard, text: 'Dashboard', index: 0, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.music_note, text: 'Works', index: 1, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.category, text: 'Categories', index: 2, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.album, text: 'Discography', index: 3, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.event, text: 'Performances', index: 4, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.person, text: 'Bio', index: 5, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.photo_library, text: 'Photo Gallery', index: 6, selectedIndex: selectedIndex),
          // Messages with unread badge in trailing
          _buildDrawerItem(
            context,
            icon: Icons.mail,
            text: 'Messages',
            index: 7,
            selectedIndex: selectedIndex,
            trailing: StreamBuilder<int>(
              stream: unreadCountStream,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count <= 0) return const SizedBox.shrink();
                return _UnreadPill(count: count);
              },
            ),
          ),
          _buildDrawerItem(context, icon: Icons.folder_copy, text: 'Stored Files', index: 8, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.bug_report, text: 'Bug Reporting', index: 9, selectedIndex: selectedIndex),
          _buildDrawerItem(context, icon: Icons.settings, text: 'Settings', index: 10, selectedIndex: selectedIndex),
          const Divider(),
           _buildDrawerItem(context, icon: Icons.public, text: 'View Live Site', index: 11, selectedIndex: selectedIndex),
          // Regular action above Logout
          ListTile(
            leading: const Icon(Icons.bug_report, color: AppTheme.primaryOrange),
            title: const Text('Report bug/feature', style: TextStyle(color: AppTheme.primaryOrange)),
            onTap: () async {
              Navigator.of(context).pop();
              await showQuickAddBugDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.darkGray),
            title: const Text('Logout', style: TextStyle(color: AppTheme.darkGray)),
            onTap: () async {
              Navigator.of(context).pop();
              await AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String text, required int index, required int selectedIndex, Widget? trailing}) {
    final bool isSelected = index == selectedIndex;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryOrange : AppTheme.darkGray),
      title: Text(text, style: TextStyle(color: isSelected ? AppTheme.primaryOrange : AppTheme.darkGray)),
      selected: isSelected,
      trailing: trailing,
      onTap: () {
        Navigator.of(context).pop();
        _onDestinationSelected(context, index);
      },
    );
  }

  int _getSelectedIndex(String currentRoute) {
    if (currentRoute.startsWith('/admin/works')) return 1;
    if (currentRoute.startsWith('/admin/categories')) return 2;
    if (currentRoute.startsWith('/admin/discography')) return 3;
    if (currentRoute.startsWith('/admin/performances')) return 4;
    if (currentRoute.startsWith('/admin/bio-gallery')) return 6;
    if (currentRoute.startsWith('/admin/bio')) return 5;
    if (currentRoute.startsWith('/admin/messages')) return 7;
    if (currentRoute.startsWith('/admin/stored-files')) return 8;
    if (currentRoute.startsWith('/admin/bugs')) return 9;
    if (currentRoute.startsWith('/admin/settings')) return 10;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/works');
        break;
      case 2:
        context.go('/admin/categories');
        break;
      case 3:
        context.go('/admin/discography');
        break;
      case 4:
        context.go('/admin/performances');
        break;
      case 5:
        context.go('/admin/bio');
        break;
      case 6:
        context.go('/admin/bio-gallery');
        break;
      case 7:
        context.go('/admin/messages');
        break;
      case 8:
        context.go('/admin/stored-files');
        break;
      case 9:
        context.go('/admin/bugs');
        break;
      case 10:
        context.go('/admin/settings');
        break;
      case 11:
        context.go('/');
        break;
    }
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count, this.dense = false});

  final int count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    final EdgeInsets padding = dense ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1) : const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
    final double minSize = dense ? 16 : 20;
    return Container(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        style: const TextStyle(
          color: AppTheme.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}