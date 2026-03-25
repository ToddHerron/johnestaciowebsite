import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/utils/time_zone_service.dart';
import 'package:john_estacio_website/features/performances/data/performances_repository.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart' as wm;
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/core/utils/title_normalizer.dart';

String formatDateTimeHuman(Timestamp ts) {
  final dt = ts.toDate().toUtc();
  final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(dt);
  final timeStr = DateFormat('h:mm a').format(dt).toLowerCase();
  return '$dateStr • $timeStr';
}

String formatPerformanceDateTimeHuman(PerformanceItem p) {
  final perfLocal = TimeZoneService.toZonedLocal(p.dateTime.toDate().toUtc(), p.timeZoneId);
  final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(perfLocal);
  final timeStr = DateFormat('h:mm a').format(perfLocal).toLowerCase();
  return '$dateStr • $timeStr';
}

// Sorting helper moved to core/utils/title_normalizer.dart (sortKeyTitle)

class AdminPerformancesPage extends StatefulWidget {
  const AdminPerformancesPage({super.key});

  @override
  State<AdminPerformancesPage> createState() => _AdminPerformancesPageState();
}

class _AdminPerformancesPageState extends State<AdminPerformancesPage> {
  final repo = PerformancesRepository();
  String _filter = '';
  bool _hidePriorPerformances = false;
  RequestStatus? _statusFilter; // null = no status filter (show all)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Performances & Requests', style: AppTheme.theme.textTheme.headlineSmall?.copyWith(color: AppTheme.primaryOrange)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openCreateDialog(context),
                  icon: const Icon(Icons.add, color: AppTheme.darkGray),
                  label: const Text('Create Request/Performance', style: TextStyle(color: AppTheme.darkGray)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Filter by ensemble, conductor, work, or venue',
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _hidePriorPerformances,
                  onChanged: (v) => setState(() => _hidePriorPerformances = v ?? false),
                  side: WidgetStateBorderSide.resolveWith((states) => const BorderSide(color: AppTheme.primaryOrange, width: 2)),
                  checkColor: AppTheme.black,
                  fillColor: const WidgetStatePropertyAll<Color>(AppTheme.white),
                ),
                const SizedBox(width: 4),
                const Text('Hide Past Performances', style: TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<RequestStatus?>(
                    value: _statusFilter,
                    items: [
                      const DropdownMenuItem<RequestStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...RequestStatus.values.map(
                        (e) => DropdownMenuItem<RequestStatus?>(
                          value: e,
                          child: Text(_statusLabel(e)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      filled: true,
                      fillColor: AppTheme.white,
                      labelStyle: TextStyle(color: AppTheme.primaryOrange),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                      ),
                      suffixIcon: Icon(Icons.keyboard_arrow_down, color: AppTheme.lightGray),
                    ),
                    dropdownColor: AppTheme.white,
                    style: const TextStyle(color: AppTheme.darkGray),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<PerformanceRequest>>(
                stream: repo.streamAll(),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const [];
                  final nowUtc = DateTime.now().toUtc();

                  var filtered = list.where((r) {
                    // Apply status filter if selected
                    if (_statusFilter != null && r.status != _statusFilter) return false;

                    // When hiding prior performances, hide entire cards where all performances are in the past.
                    if (_hidePriorPerformances) {
                      final upcoming = r.performances
                          .where((p) => !p.dateTime.toDate().toUtc().isBefore(nowUtc))
                          .toList();
                      final hasAnyPerf = r.performances.isNotEmpty;
                      final allPast = hasAnyPerf && upcoming.isEmpty;
                      if (allPast) return false; // hide this card
                    }

                    // Apply text filter
                    if (_filter.isEmpty) return true;
                    final perfForSearch = _hidePriorPerformances
                        ? r.performances.where((p) => !p.dateTime.toDate().toUtc().isBefore(nowUtc)).toList()
                        : r.performances;
                    final text = [
                      r.ensemble,
                      r.conductor,
                      ...r.works,
                      ...perfForSearch.map((p) => '${p.venueName} ${p.city} ${p.region} ${p.country}'),
                    ].join(' ').toLowerCase();
                    return text.contains(_filter);
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No requests or performances match filters.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final perfToShow = _hidePriorPerformances
                          ? r.performances.where((p) => !p.dateTime.toDate().toUtc().isBefore(nowUtc)).toList()
                          : r.performances;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.ensemble.isNotEmpty ? r.ensemble : '—', style: AppTheme.theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryOrange)), 
                                        if (r.conductor.isNotEmpty)
                                          Text('Conductor: ${r.conductor}', style: AppTheme.theme.textTheme.bodyMedium),
                                          const SizedBox(height: 8),
                                        // Show works chips; if there are duplicate titles, append subtitle to disambiguate
                                        StreamBuilder<List<wm.Work>>(
                                          stream: WorksRepository().getWorksStream(),
                                          builder: (context, worksSnap) {
                                            final allWorks = worksSnap.data ?? const <wm.Work>[];
                                            // Group works by normalized title for subtitle lookup
                                            final Map<String, List<wm.Work>> grouped = {};
                                            for (final w in allWorks) {
                                              (grouped[normalizeTitle(w.title)] ??= <wm.Work>[]).add(w);
                                            }
                                            // Sort each group by subtitle (so duplicate occurrences have stable order)
                                            for (final list in grouped.values) {
                                              list.sort((a, b) {
                                                final sa = (a.subtitle ?? '').trim().toLowerCase();
                                                final sb = (b.subtitle ?? '').trim().toLowerCase();
                                                return sa.compareTo(sb);
                                              });
                                            }
                                            // Determine which titles are ambiguous across the catalog (normalized)
                                            final Set<String> ambiguousNorms = {
                                              for (final entry in grouped.entries)
                                                if (entry.value.length > 1) entry.key
                                            };
                                            // Build labels with optional subtitle for ambiguous catalog titles
                                            final labeled = r.works.map((t) {
                                              String label = t;
                                              final n = normalizeTitle(t);
                                              if (ambiguousNorms.contains(n)) {
                                                final list = grouped[n] ?? const <wm.Work>[];
                                                // Prefer the first non-empty subtitle found
                                                final sub = list
                                                    .map((w) => (w.subtitle ?? '').trim())
                                                    .firstWhere((s) => s.isNotEmpty, orElse: () => '');
                                                if (sub.isNotEmpty) label = '$t ($sub)';
                                              }
                                              return label;
                                            }).toList()
                                              ..sort((a, b) => sortKeyTitle(a).compareTo(sortKeyTitle(b)));
                                            return Wrap(
                                              spacing: 8,
                                              children: labeled.map((w) => Chip(label: Text(w, style: const TextStyle(color: AppTheme.primaryOrange, fontSize:18.0)))).toList(),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownButton<RequestStatus>(
                                    value: r.status,
                                    onChanged: (v) {
                                      if (v != null) repo.updateStatus(r.id, v);
                                    },
                                    items: RequestStatus.values
                                        .map((e) => DropdownMenuItem(value: e, child: Text(_statusLabel(e))))
                                        .toList(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Edit request',
                                    icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                                    onPressed: () async {
                                      final updated = await showDialog<PerformanceRequest>(
                                        context: context,
                                        builder: (_) => _EditRequestDialog(initial: r),
                                      );
                                      if (updated != null) {
                                        await repo.updateRequest(r.id, updated);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Request updated.')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete request',
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: AppTheme.white,
                                          title: const Text('Delete Request'),
                                          content: const Text('Are you sure you want to delete this request? This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await repo.deleteRequest(r.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Request deleted.')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                               ...perfToShow.map((p) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(p.venueName),
                                     subtitle: Text('${p.city}, ${p.region}, ${p.country} • ${formatPerformanceDateTimeHuman(p)}'),
                                  )),
                              if (!r.requester.isEmpty) ...[
                                const Divider(height: 24),
                                Text('Requester: ${r.requester.firstName} ${r.requester.lastName}')
                                    ,
                                Text('Email: ${r.requester.email}'),
                                Text('Phone: ${r.requester.phone}'),
                                if (r.requester.address.isNotEmpty) Text('Address: ${r.requester.address}'),
                                if (r.requester.specialInstructions.isNotEmpty) Text('Notes: ${r.requester.specialInstructions}'),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(RequestStatus s) {
    switch (s) {
      case RequestStatus.newRequest:
        return 'New';
      case RequestStatus.inProgress:
        return 'In progress';
      case RequestStatus.complete:
        return 'Complete';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final newReq = await showDialog<PerformanceRequest>(
      context: context,
      builder: (context) => _CreateRequestDialog(),
    );
    if (newReq != null) {
      await repo.addRequest(newReq);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request created.')));
      }
    }
  }
}

class _CreateRequestDialog extends StatefulWidget {
  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ensemble = TextEditingController();
  final _conductor = TextEditingController();
  final List<String> _selectedWorks = [];
  final List<PerformanceItem> _performances = [];
  RequestStatus _status = RequestStatus.complete;

  InputDecoration _adminFieldDecoration(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppTheme.white,
      labelStyle: const TextStyle(color: AppTheme.primaryOrange),
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
      ),
    );
  }

  @override
  void dispose() {
    _ensemble.dispose();
    _conductor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.white,
      title: const Text(
        'Create Request (Admin)',
        style: TextStyle(color: AppTheme.darkGray),
      ),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ensemble,
                        decoration: _adminFieldDecoration('Ensemble'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _conductor,
                        decoration: _adminFieldDecoration('Conductor'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WorksPicker(selected: _selectedWorks),
                const SizedBox(height: 12),
                _PerformancesEditor(
                  performances: _performances,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RequestStatus>(
                  value: _status,
                  items: RequestStatus.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                  decoration: _adminFieldDecoration('Status'),
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedWorks.isEmpty || _performances.isEmpty
              ? null
              : () {
                  if (_formKey.currentState?.validate() != true) return;
                  final req = PerformanceRequest(
                    id: '',
                    works: _selectedWorks,
                    conductor: _conductor.text.trim(),
                    ensemble: _ensemble.text.trim(),
                    performances: _performances,
                    requester: const RequesterInfo(),
                    status: _status,
                    createdAt: Timestamp.now(),
                  );
                  Navigator.of(context).pop(req);
                },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((_) => AppTheme.primaryOrange),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((_) => AppTheme.black),
            side: const WidgetStatePropertyAll<BorderSide>(BorderSide(color: AppTheme.black, width: 1)),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditRequestDialog extends StatefulWidget {
  const _EditRequestDialog({required this.initial});
  final PerformanceRequest initial;

  @override
  State<_EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<_EditRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ensemble;
  late final TextEditingController _conductor;
  late final List<String> _selectedWorks;
  late final List<PerformanceItem> _performances;
  late RequestStatus _status;

  InputDecoration _adminFieldDecoration(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppTheme.white,
      labelStyle: const TextStyle(color: AppTheme.primaryOrange),
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensemble = TextEditingController(text: widget.initial.ensemble);
    _conductor = TextEditingController(text: widget.initial.conductor);
    _selectedWorks = List<String>.from(widget.initial.works);
    _performances = List<PerformanceItem>.from(widget.initial.performances);
    _status = widget.initial.status;
  }

  @override
  void dispose() {
    _ensemble.dispose();
    _conductor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.white,
      title: const Text(
        'Edit Request',
        style: TextStyle(color: AppTheme.darkGray),
      ),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ensemble,
                        decoration: _adminFieldDecoration('Ensemble'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _conductor,
                        decoration: _adminFieldDecoration('Conductor'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WorksPicker(selected: _selectedWorks),
                const SizedBox(height: 12),
                _PerformancesEditor(
                  performances: _performances,
                  onChanged: () => setState(() {}),
                  prefillFromLastOnAdd: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RequestStatus>(
                  value: _status,
                  items: RequestStatus.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                  decoration: _adminFieldDecoration('Status'),
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedWorks.isEmpty || _performances.isEmpty
              ? null
              : () {
                  if (_formKey.currentState?.validate() != true) return;
                  final updated = PerformanceRequest(
                    id: widget.initial.id,
                    works: _selectedWorks,
                    conductor: _conductor.text.trim(),
                    ensemble: _ensemble.text.trim(),
                    performances: _performances,
                    requester: widget.initial.requester,
                    status: _status,
                    createdAt: widget.initial.createdAt,
                  );
                  Navigator.of(context).pop(updated);
                },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((_) => AppTheme.primaryOrange),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((_) => AppTheme.black),
            side: const WidgetStatePropertyAll<BorderSide>(BorderSide(color: AppTheme.black, width: 1)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WorksPicker extends StatelessWidget {
  const _WorksPicker({required this.selected});
  final List<String> selected;

  @override
  Widget build(BuildContext context) {
    final repo = WorksRepository();
    return StreamBuilder<List<wm.Work>>(
      stream: repo.getWorksStream(),
      builder: (context, snapshot) {
        final works = snapshot.data ?? const <wm.Work>[];
        if (works.isEmpty) {
          return const Text('No works available.');
        }
        // Sort works alphabetically by title, ignoring leading articles; tie-break by subtitle
        final sorted = List<wm.Work>.from(works)
          ..sort((a, b) {
            final t = sortKeyTitle(a.title).compareTo(sortKeyTitle(b.title));
            if (t != 0) return t;
            final sa = (a.subtitle ?? '').toLowerCase().trim();
            final sb = (b.subtitle ?? '').toLowerCase().trim();
            return sa.compareTo(sb);
          });
        // Count duplicates by normalized title
        final Map<String, int> titleCounts = {};
        for (final w in sorted) {
          final key = normalizeTitle(w.title);
          titleCounts[key] = (titleCounts[key] ?? 0) + 1;
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sorted.map((w) {
            final isSel = selected.contains(w.title);
            final hasDup = (titleCounts[normalizeTitle(w.title)] ?? 0) > 1;
            final sub = (w.subtitle ?? '').trim();
            // When duplicate titles exist, append subtitle in parentheses for disambiguation
            final labelText = hasDup && sub.isNotEmpty ? '${w.title} ($sub)' : w.title;
            return FilterChip(
              label: Text(
                labelText,
                style: TextStyle(
                  color: isSel ? AppTheme.primaryOrange : AppTheme.darkGray,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSel,
              showCheckmark: false,
              backgroundColor: AppTheme.white,
              selectedColor: AppTheme.lightGray,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSel ? AppTheme.primaryOrange : AppTheme.lightGray,
                ),
              ),
              onSelected: (_) {
                if (isSel) {
                  selected.remove(w.title);
                } else {
                  selected.add(w.title);
                }
                (context as Element).markNeedsBuild();
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _PerformancesEditor extends StatelessWidget {
  const _PerformancesEditor({
    required this.performances,
    required this.onChanged,
    this.prefillFromLastOnAdd = false,
  });
  final List<PerformanceItem> performances;
  final VoidCallback onChanged;
  final bool prefillFromLastOnAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Performances',
                style: TextStyle(color: AppTheme.darkGray),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final initial = prefillFromLastOnAdd && performances.isNotEmpty ? performances.last : null;
                final p = await _showPerformanceDialog(context, initial: initial);
                if (p != null) {
                  performances.add(p);
                  onChanged();
                }
              },
              icon: const Icon(Icons.add, color: AppTheme.darkGray),
              label: const Text('Add', style: TextStyle(color: AppTheme.darkGray)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (performances.isEmpty)
          const Text('No performances added yet.', style: TextStyle(color: AppTheme.darkGray))
        else
          Column(
            children: [
              for (int i = 0; i < performances.length; i++)
                ListTile(
                  tileColor: AppTheme.lightGray,
                  title: Text(
                    performances[i].venueName,
                    style: const TextStyle(color: AppTheme.darkGray),
                  ),
                  subtitle: Text(
                     '${performances[i].city}, ${performances[i].region}, ${performances[i].country} • ${formatPerformanceDateTimeHuman(performances[i])}',
                    style: const TextStyle(color: AppTheme.darkGray),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                        tooltip: 'Edit',
                        onPressed: () async {
                          final updated = await _showPerformanceDialog(context, initial: performances[i]);
                          if (updated != null) {
                            performances[i] = updated;
                            onChanged();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          performances.removeAt(i);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

Future<PerformanceItem?> _showPerformanceDialog(BuildContext context, {PerformanceItem? initial}) async {
  final venue = TextEditingController(text: initial?.venueName ?? '');
  final city = TextEditingController(text: initial?.city ?? '');
  final region = TextEditingController(text: initial?.region ?? '');
  final country = TextEditingController(text: initial?.country ?? '');
  final ticket = TextEditingController(text: initial?.ticketingLink ?? '');
  final now = DateTime.now();
  String timeZoneId = initial?.timeZoneId ?? '';
  // Interpret stored instant as UTC and render it in the performance zone.
  DateTime? dateTime = initial == null
      ? DateTime(now.year, now.month, now.day, 19, 30)
      : TimeZoneService.toZonedLocal(initial.dateTime.toDate().toUtc(), timeZoneId);
  final key = GlobalKey<FormState>();

  final tzIds = TimeZoneService.allTimeZoneIds;
  bool tzManuallySet = timeZoneId.trim().isNotEmpty;

  void applySuggestedTimeZoneIfNeeded() {
    if (tzManuallySet) return;
    final suggestions = TimeZoneService.suggestTimeZoneIds(
      venueName: venue.text,
      city: city.text,
      region: region.text,
      country: country.text,
    );
    if (suggestions.isEmpty) return;
    timeZoneId = suggestions.first;
  }

  applySuggestedTimeZoneIfNeeded();

  InputDecoration _adminFieldDecoration(String label, {String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppTheme.white,
      labelStyle: const TextStyle(color: AppTheme.primaryOrange),
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.lightGray),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
      ),
    );
  }

  return showDialog<PerformanceItem>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.white,
      title: Text(
        initial == null ? 'Add Performance' : 'Edit Performance',
        style: const TextStyle(color: AppTheme.darkGray),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: venue,
                  decoration: _adminFieldDecoration('Venue Name'),
                  style: const TextStyle(color: AppTheme.darkGray),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: city,
                        decoration: _adminFieldDecoration('City'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: region,
                        decoration: _adminFieldDecoration('Province/State/Region'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: country,
                        decoration: _adminFieldDecoration('Country'),
                        style: const TextStyle(color: AppTheme.darkGray),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ticket,
                  decoration: _adminFieldDecoration('Ticketing Link (optional)'),
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: timeZoneId),
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    final suggestions = TimeZoneService.suggestTimeZoneIds(
                      venueName: venue.text,
                      city: city.text,
                      region: region.text,
                      country: country.text,
                    );
                    Iterable<String> base = tzIds;
                    if (suggestions.isNotEmpty) {
                      base = [...suggestions, ...tzIds];
                    }
                    if (q.isEmpty) return base.take(25);
                    return base.where((id) => id.toLowerCase().contains(q)).take(25);
                  },
                  onSelected: (v) {
                    timeZoneId = v;
                    tzManuallySet = true;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    controller.addListener(() {
                      timeZoneId = controller.text.trim();
                      if (controller.text.trim().isEmpty) tzManuallySet = false;
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: _adminFieldDecoration(
                        'Time Zone',
                        hint: 'e.g. America/Edmonton, Europe/London',
                        suffixIcon: const Icon(Icons.search, color: AppTheme.lightGray),
                      ),
                      style: const TextStyle(color: AppTheme.darkGray),
                      validator: (v) {
                        final id = (v ?? '').trim();
                        if (id.isEmpty) return 'Required (needed for DST-safe time)';
                        if (TimeZoneService.tryGetLocation(id) == null) return 'Unknown time zone';
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.white,
                          foregroundColor: AppTheme.primaryOrange,
                          side: const BorderSide(color: AppTheme.lightGray),
                        ),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                            initialDate: (dateTime ?? now),
                          );
                          if (pickedDate == null) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: (dateTime ?? now).hour, minute: (dateTime ?? now).minute),
                          );
                          if (pickedTime == null) return;
                          dateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                        },
                        icon: const Icon(Icons.event),
                        label: const Text('Pick Date & Time'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (key.currentState?.validate() != true) return;
            if (dateTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date & time.')));
              return;
            }

            final tzId = timeZoneId.trim();
            if (tzId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a time zone.')));
              return;
            }
            final utc = TimeZoneService.wallClockToUtc(dateTime!, tzId);
            Navigator.of(context).pop(
              PerformanceItem(
                venueName: venue.text.trim(),
                dateTime: Timestamp.fromDate(utc),
                timeZoneId: tzId,
                city: city.text.trim(),
                region: region.text.trim(),
                country: country.text.trim(),
                ticketingLink: ticket.text.trim(),
              ),
            );
          },
          child: Text(initial == null ? 'Add' : 'Save'),
        ),
      ],
    ),
  );
}
