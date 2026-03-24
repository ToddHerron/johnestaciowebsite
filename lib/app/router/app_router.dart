import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:john_estacio_website/app/shell/app_shell.dart';
import 'package:john_estacio_website/features/about/presentation/bio_page.dart';
import 'package:john_estacio_website/features/about/presentation/photos_page.dart';
import 'package:john_estacio_website/features/admin/presentation/bio/admin_bio_page.dart';
import 'package:john_estacio_website/features/admin/presentation/bio/admin_photo_gallery_page.dart';
import 'package:john_estacio_website/features/admin/presentation/dashboard/admin_dashboard_page.dart';
import 'package:john_estacio_website/features/admin/presentation/discography/admin_discography_page.dart';
import 'package:john_estacio_website/features/admin/presentation/messages/admin_messages_page.dart';
import 'package:john_estacio_website/features/admin/presentation/settings/admin_settings_page.dart';
import 'package:john_estacio_website/features/admin/presentation/shell/admin_shell.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/admin_stored_files_page.dart'; // Import new page
import 'package:john_estacio_website/features/admin/presentation/works/admin_works_page.dart';
import 'package:john_estacio_website/features/admin/presentation/works/edit_work_page.dart';
import 'package:john_estacio_website/features/admin/presentation/categories/admin_categories_page.dart';
import 'package:john_estacio_website/features/auth/data/auth_service.dart';
import 'package:john_estacio_website/features/auth/presentation/login_page.dart';
import 'package:john_estacio_website/features/contact/presentation/contact_page.dart';
import 'package:john_estacio_website/features/discography/presentation/discography_page.dart';
import 'package:john_estacio_website/features/home/presentation/home_page.dart';
import 'package:john_estacio_website/features/works/presentation/works_page.dart';
import 'package:john_estacio_website/features/performances/presentation/upcoming_performances_page.dart';
import 'package:john_estacio_website/features/performances/presentation/past_performances_page.dart';
import 'package:john_estacio_website/features/performances/presentation/request_scores_page.dart';
import 'package:john_estacio_website/features/admin/presentation/performances/admin_performances_page.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/admin_bugs_page.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/domain/bug_report_model.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(AuthService().authStateChanges),
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/works', builder: (context, state) => const WorksPage()),
        GoRoute(path: '/discography', builder: (context, state) => const DiscographyPage()),
        GoRoute(path: '/bio', builder: (context, state) => const BioPage()),
        GoRoute(path: '/photos', builder: (context, state) => const PhotosPage()),
        GoRoute(path: '/contact', builder: (context, state) => const ContactPage()),
        GoRoute(path: '/performances/upcoming', builder: (context, state) => const UpcomingPerformancesPage()),
        GoRoute(path: '/performances/past', builder: (context, state) => const PastPerformancesPage()),
        GoRoute(path: '/performances/request', builder: (context, state) => const RequestScoresPage()),
      ],
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
        GoRoute(path: '/admin/works', builder: (context, state) => const AdminWorksPage()),
        GoRoute(path: '/admin/works/edit/:workId', builder: (context, state) => EditWorkPage(workId: state.pathParameters['workId']!)),
        GoRoute(path: '/admin/categories', builder: (context, state) => const AdminCategoriesPage()),
        GoRoute(path: '/admin/discography', builder: (context, state) => const AdminDiscographyPage()),
        GoRoute(path: '/admin/bio', builder: (context, state) => const AdminBioPage()),
        GoRoute(path: '/admin/bio-gallery', builder: (context, state) => const AdminPhotoGalleryPage()),
        GoRoute(path: '/admin/messages', builder: (context, state) => const AdminMessagesPage()),
        GoRoute(path: '/admin/stored-files', builder: (context, state) => const AdminStoredFilesPage()), // Add new route
        GoRoute(path: '/admin/settings', builder: (context, state) => const AdminSettingsPage()),
        GoRoute(path: '/admin/performances', builder: (context, state) => const AdminPerformancesPage()),
        GoRoute(
          path: '/admin/bugs',
          builder: (context, state) {
            final kindStr = state.uri.queryParameters['kind'];
            BugKind? initialKind;
            switch ((kindStr ?? '').toLowerCase()) {
              case 'bug':
                initialKind = BugKind.bug;
                break;
              case 'feature':
                initialKind = BugKind.feature;
                break;
              default:
                initialKind = null;
            }
            return AdminBugsPage(initialKind: initialKind);
          },
        ),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = AuthService().currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    
    final publicRoutes = ['/', '/works', '/discography', '/bio', '/photos', '/contact', '/performances/upcoming', '/performances/past', '/performances/request'];
    final bool isPublicRoute = publicRoutes.contains(state.matchedLocation);

    if (!loggedIn && !loggingIn && !isPublicRoute) {
      return '/login';
    }
    
    if (loggedIn && loggingIn) {
      return '/admin';
    }

    return null;
  },
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}