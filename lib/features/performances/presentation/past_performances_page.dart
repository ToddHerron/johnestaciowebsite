import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/utils/time_zone_service.dart';
import 'package:john_estacio_website/core/utils/link_proxy.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/features/performances/data/performances_repository.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/work_card_dialog.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart' as wm;
import 'package:url_launcher/url_launcher.dart';
import 'package:john_estacio_website/core/utils/title_normalizer.dart';

class PastPerformancesPage extends StatelessWidget {
  const PastPerformancesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PublicPageScaffold(
      child: _PastBody(),
    );
  }
}

class _PastBody extends StatelessWidget {
  const _PastBody();

  @override
  Widget build(BuildContext context) {
    final repo = PerformancesRepository();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Past Performances', style: AppTheme.theme.textTheme.headlineLarge?.copyWith(color: AppTheme.primaryOrange)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<PerformanceRequest>>(
                  stream: repo.streamPastComplete(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(child: Text('No past performances yet.', style: TextStyle(color: AppTheme.lightGray)));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _RequestCard(item: items[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final PerformanceRequest item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.ensemble.isNotEmpty)
              Text(item.ensemble, style: AppTheme.theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryOrange)),
            if (item.conductor.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text('Conductor: ${item.conductor}', style: AppTheme.theme.textTheme.bodyLarge?.copyWith(color: AppTheme.lightGray)),
              ),
            if (item.works.isNotEmpty) ...[
              const SizedBox(height: 8),
              StreamBuilder<List<wm.Work>>(
                stream: WorksRepository().getWorksStream(),
                builder: (context, worksSnap) {
                  final allWorks = worksSnap.data ?? const <wm.Work>[];
                  // Group works by normalized title to detect ambiguities
                  final Map<String, List<wm.Work>> grouped = {};
                  for (final w in allWorks) {
                    (grouped[normalizeTitle(w.title)] ??= <wm.Work>[]).add(w);
                  }
                  final Set<String> ambiguousNorms = {
                    for (final e in grouped.entries) if (e.value.length > 1) e.key
                  };
                  final labeled = item.works.map((t) {
                    final n = normalizeTitle(t);
                    if (!ambiguousNorms.contains(n)) return t;
                    final list = grouped[n] ?? const <wm.Work>[];
                    final sub = list
                        .map((w) => (w.subtitle).trim())
                        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
                    return sub.isNotEmpty ? '$t ($sub)' : t;
                  }).toList()
                    ..sort((a, b) => sortKeyTitle(a).compareTo(sortKeyTitle(b)));
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: labeled
                        .map((w) => ActionChip(
                              label: Text(
                                w,
                                style: const TextStyle(color: AppTheme.primaryOrange, fontSize: 18.0),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => WorkCardDialog(workTitle: w),
                                );
                              },
                            ))
                        .toList(),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            ...item.performances.map((p) => _PerformanceTile(p)),
          ],
        ),
      ),
    );
  }
}

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile(this.p);
  final PerformanceItem p;

  @override
  Widget build(BuildContext context) {
    final dt = TimeZoneService.toPublicZonedLocal(p.dateTime.toDate().toUtc(), p.timeZoneId);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(dt);
    final timeStr = DateFormat('h:mma').format(dt).toLowerCase();
    final location = [p.city, p.region, p.country].where((e) => e.trim().isNotEmpty).join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.venueName, style: const TextStyle(color: AppTheme.lightGray)),
      subtitle: Text('$location • $dateStr, $timeStr', style: const TextStyle(color: AppTheme.lightGray)),
      trailing: (p.ticketingLink.trim().isNotEmpty && p.dateTime.toDate().toUtc().isAfter(DateTime.now().toUtc()))
          ? TextButton.icon(
              icon: const Icon(Icons.open_in_new, color: AppTheme.lightGray),
              label: const Text('FIND TICKETS', style: TextStyle(color: AppTheme.lightGray)),
              onPressed: () => _launch(context, p.ticketingLink.trim()),
            )
          : null,
    );
  }

  void _launch(BuildContext context, String url) async {
    try {
      final uri = LinkProxy.build(url);
      // ignore: use_build_context_synchronously
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open ticketing link')),
        );
      }
    }
  }
}
