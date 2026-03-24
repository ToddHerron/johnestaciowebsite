import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:john_estacio_website/features/admin/presentation/works/work_preview_dialog.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/features/works/data/works_migration_reporter.dart';
import 'package:john_estacio_website/core/utils/download_helper.dart';
import 'package:flutter/services.dart';

class AdminWorksPage extends StatefulWidget {
  const AdminWorksPage({super.key});

  @override
  State<AdminWorksPage> createState() => _AdminWorksPageState();
}

class _AdminWorksPageState extends State<AdminWorksPage> {
  final WorksRepository _worksRepository = WorksRepository();
  final WorksMigrationReporter _reporter = WorksMigrationReporter();

  // Maximum content width for the list to reduce excessive horizontal spacing.
  static const double _maxContentWidth = 960;

  // UI state
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  bool _sortAlphabetically = false;
  bool _isPersistingAlphabetical = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _deleteWork(String id, String title) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to permanently delete the work "$title"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      try {
        await _worksRepository.deleteWork(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting work: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _persistAlphabeticalOrder(List<Work> baseWorks) async {
    // Create a sorted copy ignoring leading articles
    final sorted = List<Work>.from(baseWorks)
      ..sort((a, b) => _normalizedTitle(a.title).compareTo(_normalizedTitle(b.title)));
    await _worksRepository.updateWorkOrder(sorted);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alphabetical order saved.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onReorder(int oldIndex, int newIndex, List<Work> works) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Work item = works.removeAt(oldIndex);
    works.insert(newIndex, item);

    _worksRepository.updateWorkOrder(works).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving new order: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  String _normalizedTitle(String title) {
    // Ignore leading articles A/An/The (case-insensitive) for sorting
    final trimmed = title.trimLeft();
    final withoutArticle = trimmed.replaceFirst(
      RegExp(r'^(?:A|An|The)\s+', caseSensitive: false),
      '',
    );
    return withoutArticle.trimLeft().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: StreamBuilder<List<Work>>(
        stream: _worksRepository.getWorksStream(publishedOnly: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Base list from backend
          final baseWorks = snapshot.data ?? [];

          // Filter
          final String q = _filter.trim().toLowerCase();
          final bool isFiltered = q.isNotEmpty;
          List<Work> viewWorks = List<Work>.from(baseWorks);
          if (isFiltered) {
            viewWorks = viewWorks.where((w) {
              final t = w.title.toLowerCase();
              final s = w.subtitle.toLowerCase();
              return t.contains(q) || s.contains(q);
            }).toList();
          }

          // Sort alphabetically ignoring A/An/The when toggled
          if (_sortAlphabetically) {
            viewWorks.sort((a, b) => _normalizedTitle(a.title).compareTo(_normalizedTitle(b.title)));
          }

          return Column(
            children: [
              AppBar(
                title: const Text(
                  'Manage Works',
                  style: TextStyle(color: AppTheme.darkGray),
                ),
                backgroundColor: AppTheme.white,
                elevation: 1,
              ),
              // Action toolbar under the AppBar; wraps to avoid overflow.
              Material(
                color: AppTheme.white,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Filter field
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: SizedBox(
                              height: 40,
                              width: 320,
                              child: TextField(
                                controller: _filterController,
                                onChanged: (val) => setState(() => _filter = val),
                                style: const TextStyle(color: AppTheme.darkGray),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Filter by title or subtitle',
                                  hintStyle: TextStyle(color: Colors.grey.shade600),
                                  filled: true,
                                  fillColor: AppTheme.white,
                                  prefixIcon: const Icon(Icons.search, color: AppTheme.darkGray),
                                  suffixIcon: _filter.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear',
                                          onPressed: () {
                                            _filterController.clear();
                                            setState(() => _filter = '');
                                          },
                                          icon: const Icon(Icons.clear, color: AppTheme.darkGray),
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ),
                          // Sort toggle
                          TextButton.icon(
                            onPressed: _isPersistingAlphabetical
                                ? null
                                : () async {
                                    final turningOn = !_sortAlphabetically;
                                    setState(() => _sortAlphabetically = !_sortAlphabetically);
                                    // When enabling alphabetical sort, also persist this order across sessions
                                    if (turningOn) {
                                      setState(() => _isPersistingAlphabetical = true);
                                      try {
                                        await _persistAlphabeticalOrder(baseWorks);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error saving alphabetical order: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isPersistingAlphabetical = false);
                                        }
                                      }
                                    }
                                  },
                            icon: _isPersistingAlphabetical
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppTheme.darkGray,
                                    ),
                                  )
                                : const Icon(Icons.sort_by_alpha, color: AppTheme.darkGray),
                            label: const Text(
                              'Sort Alphabetically',
                              style: TextStyle(color: AppTheme.darkGray),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.darkGray,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                          // Dry-run migration
                          OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Dry-run Works Schema Migration'),
                                  content: const Text(
                                    'This will analyze all Works documents and report how many would be updated, but it will NOT write any changes to Firestore.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Dry-run'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dry-run started...')),
                                );
                              }
                              try {
                                final results = await _worksRepository.migrateSchemaForIcons(dryRun: true);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Dry-run complete. Processed: \'${results['processed']}\', Would update: \'${results['updated']}\', Unchanged: \'${results['skipped']}\', Errors: \'${results['errors']}\'. No changes were written.',
                                    ),
                                    duration: const Duration(seconds: 6),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Dry-run failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.visibility, color: AppTheme.darkGray),
                            label: const Text(
                              'Dry-run Migration',
                              style: TextStyle(color: AppTheme.darkGray),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: AppTheme.darkGray,
                              backgroundColor: AppTheme.white,
                            ),
                          ),
                          // Download Dry-run Report
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Building dry-run report...')),
                                  );
                                }
                                final html = await _reporter.buildReportHtml();
                                final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
                                final ok = downloadStringAsFile(html, 'works_migration_dryrun_$ts.html', mimeType: 'text/html');
                                if (!mounted) return;
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Report download started.')),
                                  );
                                } else {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Dry-run Report (HTML)'),
                                      content: SizedBox(
                                        width: 600,
                                        height: 400,
                                        child: SingleChildScrollView(
                                          child: SelectableText(html),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: html));
                                            Navigator.of(ctx).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Report copied to clipboard')),
                                            );
                                          },
                                          child: const Text('Copy'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not build report: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.download, color: AppTheme.darkGray),
                            label: const Text(
                              'Download Dry-run Report',
                              style: TextStyle(color: AppTheme.darkGray),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: AppTheme.darkGray,
                              backgroundColor: AppTheme.white,
                            ),
                          ),
                          // Backup + Run Migration
                          OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Backup + Run Schema Migration'),
                                  content: const Text(
                                    'This will first create a fresh backup of the Works collection into "worksBackup" (overwriting any previous backup), then run the schema migration on the live "works" collection. Continue?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Backup + Migrate'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Creating works backup...')),
                                );
                              }
                              try {
                                final backup = await _worksRepository.backupWorksCollection();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Backup complete. Copied ${backup['copiedToBackup']} docs (deleted old backup: ${backup['deletedOldBackup']}). Running migration...'),
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                                final results = await _worksRepository.migrateSchemaForIcons();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Migration complete. Processed: \'${results['processed']}\', Updated: \'${results['updated']}\', Skipped: \'${results['skipped']}\', Errors: \'${results['errors']}\'.',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backup/Migration failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.auto_fix_high, color: AppTheme.darkGray),
                            label: const Text(
                              'Backup + Run Migration',
                              style: TextStyle(color: AppTheme.darkGray),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: AppTheme.primaryOrange,
                              backgroundColor: AppTheme.white,
                            ),
                          ),
                          // Restore from Backup
                          OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Restore Works from Backup'),
                                  content: const Text(
                                    'This will replace the current "works" collection with the contents of "worksBackup". All current works will be deleted. Proceed?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Restore'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Restoring works from backup...')),
                                );
                              }
                              try {
                                final res = await _worksRepository.restoreWorksFromBackup();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Restore complete. Deleted current: ${res['deletedExisting']}, Restored: ${res['restoredFromBackup']} (backup total: ${res['backupCount']}).'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Restore failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.restore, color: AppTheme.darkGray),
                            label: const Text(
                              'Restore from Backup',
                              style: TextStyle(color: AppTheme.darkGray),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: AppTheme.darkGray,
                              backgroundColor: AppTheme.white,
                            ),
                          ),
                          // Add New Work
                          ElevatedButton.icon(
                            onPressed: () {
                              context.go('/admin/works/edit/new', extra: baseWorks.length);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Work'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (baseWorks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No works found. Click "Add New Work" to start.'),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false, // Disable default handle
                        proxyDecorator: (Widget child, int index, Animation<double> animation) {
                          return Material(
                            color: AppTheme.white,
                            elevation: 4.0,
                            child: child,
                          );
                        },
                        itemCount: viewWorks.length,
                        onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, viewWorks),
                        itemBuilder: (context, index) {
                          final work = viewWorks[index];
                          final hasSubtitle = work.subtitle.trim().isNotEmpty;
                          return ListTile(
                            key: ValueKey(work.id),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                            leading: isFiltered
                                ? const Icon(Icons.drag_indicator, color: Colors.grey)
                                : ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_indicator, color: AppTheme.darkGray),
                                  ),
                            title: Text(
                              work.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.darkGray,
                              ),
                            ),
                            subtitle: hasSubtitle
                                ? Text(
                                    work.subtitle,
                                    style: const TextStyle(color: AppTheme.darkGray),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Visibility indicator: replaces previous data-integrity flag
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: Tooltip(
                                    message: work.isVisible ? 'Visible to public' : 'Hidden from public',
                                    child: IconButton(
                                      icon: Icon(
                                        work.isVisible ? Icons.visibility : Icons.visibility_off,
                                        color: work.isVisible ? Colors.green : AppTheme.darkGray,
                                      ),
                                      onPressed: () async {
                                        final newValue = !work.isVisible;
                                        try {
                                          await _worksRepository.setVisibility(
                                            work.id,
                                            isVisible: newValue,
                                            titleForCache: work.title,
                                          );
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(newValue ? 'Made "${work.title}" visible to the public.' : 'Hidden "${work.title}" from the public.'),
                                              backgroundColor: newValue ? Colors.green : Colors.orange,
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to update visibility: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                // Preview icon
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: AppTheme.darkGray),
                                  tooltip: 'Preview',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (ctx) => WorkPreviewDialog(work: work),
                                    );
                                  },
                                ),
                                // Draft presence indicator
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Tooltip(
                                    message: work.hasDraft ? 'Draft exists' : 'No draft',
                                    child: Icon(
                                      Icons.edit_document,
                                      color: work.hasDraft ? AppTheme.primaryOrange : AppTheme.lightGray,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    context.go('/admin/works/edit/${work.id}');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteWork(work.id, work.title),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
