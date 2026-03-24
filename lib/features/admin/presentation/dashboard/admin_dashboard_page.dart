import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/data/bugs_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/domain/bug_report_model.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = BugsRepository();
    

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        title: const Text('Dashboard', style: TextStyle(color: AppTheme.darkGray)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final horizontalGap = 16.0;

          Widget recentClosedCard = _DashboardCard(
            title: 'Recently closed bugs',
            icon: Icons.bug_report_outlined,
            accentColor: Colors.green,
            onViewAll: () => context.go('/admin/bugs?kind=bug'),
            child: StreamBuilder<List<BugReportModel>>(
              stream: repo.streamRecentClosedBugs(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _EmptyState(message: 'No recently closed bugs.');
                }
                return _SimpleList(items: items, showUpdatedTime: true);
              },
            ),
          );

          Widget recentFeaturesCard = _DashboardCard(
            title: 'Recently added features',
            icon: Icons.rocket_launch_outlined,
            accentColor: Colors.green,
            onViewAll: () => context.go('/admin/bugs?kind=feature'),
            child: StreamBuilder<List<BugReportModel>>(
              stream: repo.streamRecentFeatures(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _EmptyState(message: 'No new features yet.');
                }
                return _SimpleList(items: items, showUpdatedTime: false);
              },
            ),
          );

          Widget statusSummaryCard = _DashboardCard(
            title: 'Requests by status',
            icon: Icons.analytics_outlined,
            accentColor: Colors.blue,
            onViewAll: () => context.go('/admin/bugs'),
            child: StreamBuilder<List<BugReportModel>>(
              stream: repo.streamBugs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                  );
                }
                final items = snapshot.data ?? [];

                int countStatus(BugStatus s) => items.where((e) => e.status == s).length;
                int countBug(BugStatus s) => items.where((e) => e.status == s && e.kind == BugKind.bug).length;
                int countFeature(BugStatus s) => items.where((e) => e.status == s && e.kind == BugKind.feature).length;

                final newTotal = countStatus(BugStatus.newReport);
                final workingTotal = countStatus(BugStatus.beingWorkedOn);
                final deferredTotal = countStatus(BugStatus.deferred);
                final closedTotal = countStatus(BugStatus.closed);

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatusTile(
                        title: 'New',
                        color: Colors.orange,
                        total: newTotal,
                        bugCount: countBug(BugStatus.newReport),
                        featureCount: countFeature(BugStatus.newReport),
                      ),
                      _StatusTile(
                        title: 'Being worked on',
                        color: Colors.blue,
                        total: workingTotal,
                        bugCount: countBug(BugStatus.beingWorkedOn),
                        featureCount: countFeature(BugStatus.beingWorkedOn),
                      ),
                      _StatusTile(
                        title: 'Deferred',
                        color: Colors.purple,
                        total: deferredTotal,
                        bugCount: countBug(BugStatus.deferred),
                        featureCount: countFeature(BugStatus.deferred),
                      ),
                      _StatusTile(
                        title: 'Closed',
                        color: Colors.green,
                        total: closedTotal,
                        bugCount: countBug(BugStatus.closed),
                        featureCount: countFeature(BugStatus.closed),
                      ),
                    ],
                  ),
                );
              },
            ),
          );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  statusSummaryCard,
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: recentClosedCard),
                        SizedBox(width: horizontalGap),
                        Expanded(child: recentFeaturesCard),
                      ],
                    )
                  else ...[
                    recentClosedCard,
                    recentFeaturesCard,
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.title, required this.icon, required this.accentColor, required this.child, this.onViewAll});
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.white,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.darkGray)),
                ),
                if (onViewAll != null)
                  TextButton.icon(
                    onPressed: onViewAll,
                    icon: Icon(Icons.chevron_right, color: accentColor),
                    label: Text('View all', style: TextStyle(color: accentColor)),
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(accentColor),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({required this.items, required this.showUpdatedTime});
  final List<BugReportModel> items;
  final bool showUpdatedTime; // true for closed bugs, false for features

  String _formatTimestamp(DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt);
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
      itemBuilder: (context, index) {
        final bug = items[index];
        final when = showUpdatedTime ? bug.updatedAt.toDate() : bug.createdAt.toDate();
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(bug.title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGray)),
          subtitle: Row(
            children: [
              if (bug.urgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    border: const Border.fromBorderSide(BorderSide(color: Colors.red)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('URGENT', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                _formatTimestamp(when),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (bug.kind == BugKind.feature ? AppTheme.primaryOrange : Colors.blue).withValues(alpha: 0.12),
              border: Border.all(color: bug.kind == BugKind.feature ? AppTheme.primaryOrange : Colors.blue),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              bug.kind.label,
              style: TextStyle(
                color: bug.kind == BugKind.feature ? AppTheme.primaryOrange : Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.color,
    required this.total,
    required this.bugCount,
    required this.featureCount,
  });

  final String title;
  final Color color;
  final int total;
  final int bugCount;
  final int featureCount;

  @override
  Widget build(BuildContext context) {
    final muted = total == 0;
    final tint = color.withValues(alpha: 0.12);
    return InkWell(
      onTap: () => context.go('/admin/bugs'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: muted ? Colors.grey.withValues(alpha: 0.25) : color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color),
              ),
              child: Icon(Icons.circle, color: color, size: 14),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.darkGray.withValues(alpha: muted ? 0.6 : 1.0))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('$total total', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    const SizedBox(width: 8),
                    _CountPill(label: '${bugCount} bugs', color: Colors.blue),
                    const SizedBox(width: 6),
                    _CountPill(label: '${featureCount} features', color: AppTheme.primaryOrange),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
