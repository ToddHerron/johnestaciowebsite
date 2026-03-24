import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/data/bugs_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/domain/bug_report_model.dart';
import 'package:john_estacio_website/features/contact/data/contact_repository.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:go_router/go_router.dart';

class AdminBugsPage extends StatefulWidget {
  const AdminBugsPage({super.key, this.initialKind});

  /// When provided, the page will start with this single kind selected
  /// in the Type filter (e.g., Bug or Feature). Users can still change filters.
  final BugKind? initialKind;

  @override
  State<AdminBugsPage> createState() => _AdminBugsPageState();
}

class _AdminBugsPageState extends State<AdminBugsPage> {
  final BugsRepository _repository = BugsRepository();
  final ContactRepository _contactRepository = ContactRepository();

  List<BugReportModel> _bugs = [];
  bool _isSavingOrder = false;

  // Filters (defaults: all statuses/types selected; urgent only = false)
  final Set<BugStatus> _selectedStatuses = {...BugStatus.values};
  final Set<BugKind> _selectedKinds = {...BugKind.values};
  bool _urgentOnly = false;
  bool _prefilterApplied = false; // ensure we only auto-apply once and don't override user changes

  bool get _allStatusesSelected => _selectedStatuses.length == BugStatus.values.length;
  bool get _allKindsSelected => _selectedKinds.length == BugKind.values.length;

  // Filters considered active only if not all selected, or urgent toggle is on.
  bool get _hasActiveFilters => !_allStatusesSelected || !_allKindsSelected || _urgentOnly;

  @override
  void initState() {
    super.initState();
    // Apply initial kind filter if provided via navigation (e.g., from Dashboard "View all")
    final initial = widget.initialKind;
    // ignore: avoid_print
    print('[AdminBugsPage] initState initialKind=${initial?.label ?? 'null'}');
    if (initial != null) {
      _selectedKinds
        ..clear()
        ..add(initial);
      _prefilterApplied = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdminBugsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the route query param changes while staying on the same route
    // (e.g., navigating from kind=bug to kind=feature), reflect that here.
    final newKind = widget.initialKind;
    // ignore: avoid_print
    print('[AdminBugsPage] didUpdateWidget old=${oldWidget.initialKind?.label ?? 'null'} new=${newKind?.label ?? 'null'}');
    if (newKind != null && newKind != oldWidget.initialKind) {
      setState(() {
        _selectedKinds
          ..clear()
          ..add(newKind);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback: if router didn't pass initialKind, parse query from current location once
    if (!_prefilterApplied) {
      final uri = GoRouterState.of(context).uri;
      final qp = uri.queryParameters;
      final kindStr = (qp['kind'] ?? '').toLowerCase();
      BugKind? qKind;
      if (kindStr == 'bug') qKind = BugKind.bug;
      if (kindStr == 'feature') qKind = BugKind.feature;
      if (qKind != null) {
        // ignore: avoid_print
        print('[AdminBugsPage] applying prefilter from URL kind=${qKind.label}');
        _selectedKinds
          ..clear()
          ..add(qKind);
        _prefilterApplied = true;
      }
    }
    // ignore: avoid_print
    print('[AdminBugsPage] build kindsSelected=${_selectedKinds.map((e) => e.label).join(', ')} statusesSelected=${_selectedStatuses.map((e) => e.label).join(', ')} urgentOnly=$_urgentOnly');
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Bug Reporting', style: TextStyle(color: AppTheme.darkGray)),
        backgroundColor: AppTheme.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          if (_isSavingOrder) const LinearProgressIndicator(),

          // Filters row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter by Status', style: TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _FilterCheckbox(
                            label: 'All Statuses',
                            value: _allStatusesSelected,
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedStatuses
                                  ..clear()
                                  ..addAll(BugStatus.values);
                                _urgentOnly = false;
                              } else {
                                _selectedStatuses.clear();
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugStatus.newReport.label,
                            value: _selectedStatuses.contains(BugStatus.newReport),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedStatuses.add(BugStatus.newReport);
                              } else {
                                _selectedStatuses.remove(BugStatus.newReport);
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugStatus.beingWorkedOn.label,
                            value: _selectedStatuses.contains(BugStatus.beingWorkedOn),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedStatuses.add(BugStatus.beingWorkedOn);
                              } else {
                                _selectedStatuses.remove(BugStatus.beingWorkedOn);
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugStatus.deferred.label,
                            value: _selectedStatuses.contains(BugStatus.deferred),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedStatuses.add(BugStatus.deferred);
                              } else {
                                _selectedStatuses.remove(BugStatus.deferred);
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugStatus.closed.label,
                            value: _selectedStatuses.contains(BugStatus.closed),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedStatuses.add(BugStatus.closed);
                              } else {
                                _selectedStatuses.remove(BugStatus.closed);
                              }
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Type column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter by Type', style: TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _FilterCheckbox(
                            label: 'All Types',
                            value: _allKindsSelected,
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedKinds
                                  ..clear()
                                  ..addAll(BugKind.values);
                                _urgentOnly = false;
                              } else {
                                _selectedKinds.clear();
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugKind.bug.label,
                            value: _selectedKinds.contains(BugKind.bug),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedKinds.add(BugKind.bug);
                              } else {
                                _selectedKinds.remove(BugKind.bug);
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: BugKind.feature.label,
                            value: _selectedKinds.contains(BugKind.feature),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _selectedKinds.add(BugKind.feature);
                              } else {
                                _selectedKinds.remove(BugKind.feature);
                              }
                            }),
                          ),
                          _FilterCheckbox(
                            label: 'Urgent only',
                            value: _urgentOnly,
                            onChanged: (v) => setState(() => _urgentOnly = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<BugReportModel>>(
              stream: _repository.streamBugs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                _bugs = snapshot.data ?? [];

                // Apply filters
                List<BugReportModel> visible = _bugs.where((b) {
                  final statusOk = _selectedStatuses.contains(b.status);
                  final kindOk = _selectedKinds.contains(b.kind);
                  final urgentOk = !_urgentOnly || b.urgent;
                  return statusOk && kindOk && urgentOk;
                }).toList();

                if (visible.isEmpty) {
                  return const Center(child: Text('No bug reports match the current filters.'));
                }

                if (_hasActiveFilters) {
                  // Show non-reorderable list when filters active
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final bug = visible[index];
                      return _BugTile(
                        key: ValueKey(bug.id),
                        index: index,
                        bug: bug,
                      repository: _repository,
                        onChat: () => _openChat(bug),
                        onEdit: () => _onEditBug(bug),
                        onDelete: () => _onDeleteBug(bug),
                        reorderHandleEnabled: false,
                      );
                    },
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visible.length,
                  onReorder: (oldIndex, newIndex) {
                    // Map reorder in visible list back to full list order
                    final oldBug = visible[oldIndex];
                    if (oldIndex < newIndex) newIndex -= 1;
                    final newBugBefore = visible[newIndex];

                    final fullOldIndex = _bugs.indexWhere((b) => b.id == oldBug.id);
                    final fullNewIndex = _bugs.indexWhere((b) => b.id == newBugBefore.id);
                    _onReorder(fullOldIndex, fullNewIndex);
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 6,
                      color: Colors.transparent,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final bug = visible[index];
                    return _BugTile(
                      key: ValueKey(bug.id),
                      index: index,
                      bug: bug,
                       repository: _repository,
                      onChat: () => _openChat(bug),
                      onEdit: () => _onEditBug(bug),
                      onDelete: () => _onDeleteBug(bug),
                      reorderHandleEnabled: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    setState(() => _isSavingOrder = true);

    final updated = List<BugReportModel>.from(_bugs);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    try {
      await _repository.reorderBugs(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save new order: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  Future<void> _onEditBug(BugReportModel bug) async {
    final result = await showDialog<_BugDialogResult>(
      context: context,
      builder: (context) => _BugEditDialog(existing: bug),
    );
    if (result == null) return;
    try {
      await _repository.updateBug(
        bug.id,
        title: result.title,
        body: result.body,
        urgent: result.urgent,
        status: result.status,
        kind: result.kind,
      );

      // Notify on any status change (Bug/Feature)
      if (bug.status != result.status) {
        final kindLabel = result.kind.label;
        final oldLabel = bug.status.label;
        final newLabel = result.status.label;
        await _contactRepository.sendMessage(
          firstName: 'System',
          lastName: 'Notifier',
          email: 'system@internal',
          message: "$kindLabel '${bug.title}' : status was changed from '$oldLabel' to '$newLabel'",
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bug: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onDeleteBug(BugReportModel bug) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bug'),
        content: Text('Are you sure you want to delete "${bug.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repository.deleteBug(bug.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug deleted'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete bug: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openChat(BugReportModel bug) {
    showDialog(
      context: context,
      builder: (context) => _BugChatDialog(bug: bug, repository: _repository),
    );
  }
}

class _FilterCheckbox extends StatelessWidget {
  const _FilterCheckbox({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            side: const BorderSide(color: AppTheme.lightGray, width: 2),
            checkColor: AppTheme.black,
            fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.white;
              }
              return AppTheme.white;
            }),
          ),
          Text(label, style: const TextStyle(color: AppTheme.darkGray)),
        ],
      ),
    );
  }
}

class _BugTile extends StatelessWidget {
  const _BugTile({
    super.key,
    required this.index,
    required this.bug,
    required this.repository,
    required this.onChat,
    required this.onEdit,
    required this.onDelete,
    required this.reorderHandleEnabled,
  });

  final int index;
  final BugReportModel bug;
  final BugsRepository repository;
  final VoidCallback onChat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool reorderHandleEnabled;

  Color _statusColor(BugStatus status) {
    switch (status) {
      case BugStatus.newReport:
        return Colors.blue;
      case BugStatus.beingWorkedOn:
        return Colors.orange;
      case BugStatus.deferred:
        return Colors.purple;
      case BugStatus.closed:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
      color: AppTheme.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: SizedBox(
          width: 56, // Reserve space so titles align whether urgent icon is present or not
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reorderHandleEnabled)
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator, color: AppTheme.darkGray), // 6-pip icon
                )
              else
                const Icon(Icons.drag_indicator, color: AppTheme.darkGray),
              const SizedBox(width: 8),
              if (bug.urgent)
                const Icon(Icons.priority_high, color: Colors.red)
              else
                const SizedBox(width: 24), // reserve icon width when not urgent
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                bug.title,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkGray),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(bug.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _statusColor(bug.status)),
              ),
              child: Text(
                bug.status.label,
                style: TextStyle(color: _statusColor(bug.status), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryOrange),
              ),
              child: Text(
                bug.kind.label,
                style: const TextStyle(color: AppTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (bug.urgent) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: const Border.fromBorderSide(BorderSide(color: Colors.red)),
                ),
                child: const Text(
                  'URGENT',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        subtitle: bug.body.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  bug.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat icon reflects presence of a discussion thread
            StreamBuilder<bool>(
              stream: repository.streamHasChat(bug.id),
              builder: (context, snapshot) {
                final hasChat = snapshot.data ?? false;
                final color = hasChat ? AppTheme.primaryOrange : AppTheme.darkGray;
                return IconButton(
                  tooltip: 'Chat',
                  icon: Icon(hasChat ? Icons.chat_bubble : Icons.chat_bubble_outline, color: color),
                  onPressed: onChat,
                );
              },
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit, color: AppTheme.darkGray),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _BugDialogResult {
  final String title;
  final String body;
  final bool urgent;
  final BugStatus status;
  final BugKind kind;
  _BugDialogResult(this.title, this.body, this.urgent, this.status, this.kind);
}

class _BugEditDialog extends StatefulWidget {
  const _BugEditDialog({this.existing});
  final BugReportModel? existing;

  @override
  State<_BugEditDialog> createState() => _BugEditDialogState();
}

class _BugEditDialogState extends State<_BugEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _urgent = false;
  BugStatus _status = BugStatus.newReport;
  BugKind _kind = BugKind.bug;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _bodyController = TextEditingController(text: existing?.body ?? '');
    _urgent = existing?.urgent ?? false;
    _status = existing?.status ?? BugStatus.newReport;
    _kind = existing?.kind ?? BugKind.bug;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Bug' : 'Add Bug'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Body'),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<BugStatus>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: BugStatus.newReport, child: Text('New')),
                        DropdownMenuItem(value: BugStatus.beingWorkedOn, child: Text('Being worked on')),
                        DropdownMenuItem(value: BugStatus.deferred, child: Text('Deferred')),
                        DropdownMenuItem(value: BugStatus.closed, child: Text('Closed')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<BugKind>(
                      value: _kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: BugKind.bug, child: Text('Bug')),
                        DropdownMenuItem(value: BugKind.feature, child: Text('Feature')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _kind = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Checkbox(
                      value: _urgent,
                      onChanged: (v) => setState(() => _urgent = v ?? false),
                      side: const BorderSide(color: AppTheme.lightGray, width: 2),
                      checkColor: AppTheme.black,
                      fillColor: WidgetStateProperty.all(AppTheme.white),
                    ),
                    const Text('Urgent', style: TextStyle(color: AppTheme.darkGray)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _BugDialogResult(
                _titleController.text.trim(),
                _bodyController.text.trim(),
                _urgent,
                _status,
                _kind,
              ),
            );
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _BugChatDialog extends StatefulWidget {
  const _BugChatDialog({required this.bug, required this.repository});
  final BugReportModel bug;
  final BugsRepository repository;

  @override
  State<_BugChatDialog> createState() => _BugChatDialogState();
}

class _BugChatDialogState extends State<_BugChatDialog> {
  final TextEditingController _controller = TextEditingController();
  final _auth = FirebaseAuth.instance;

  static const toddUid = 'wdpGgDoUTgXsOXluvu0NAIRlktS2';
  static const johnUid = 'vzAXwY46qHNpWZt0H203RZxq0mv1';

  String _displayNameFor(String uid) {
    switch (uid) {
      case toddUid:
        return 'Todd';
      case johnUid:
        return 'John';
      default:
        return 'Unknown';
    }
  }

  bool get _canSend {
    final uid = _auth.currentUser?.uid;
    return uid == toddUid || uid == johnUid;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!_canSend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Todd or John can send messages in this chat.'), backgroundColor: Colors.red),
      );
      return;
    }
    final uid = _auth.currentUser!.uid;
    try {
      await widget.repository.addBugChatMessage(
        bugId: widget.bug.id,
        senderUid: uid,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: AppTheme.white),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppTheme.darkGray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Discussion • ${widget.bug.title}', style: const TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.darkGray),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder(
                stream: widget.repository.streamBugChat(widget.bug.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final docs = (snapshot.data as QuerySnapshot<Map<String, dynamic>>?)?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the conversation.', style: TextStyle(color: AppTheme.darkGray)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final text = (data['text'] ?? '').toString();
                      final senderUid = (data['senderUid'] ?? '').toString();
                      final ts = data['timestamp'];
                      DateTime? time;
                      if (ts is Timestamp) time = ts.toDate();
                      final you = _auth.currentUser?.uid == senderUid;

                      return Align(
                        alignment: you ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            // Make the text bubble background white for all messages
                            color: AppTheme.white,
                            border: Border.all(color: you ? AppTheme.primaryOrange : Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Sender name should be primary orange
                                  Text(_displayNameFor(senderUid), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryOrange)),
                                  if (time != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimestamp(time),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(text, style: const TextStyle(color: AppTheme.darkGray)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                       keyboardType: TextInputType.multiline,
                       textInputAction: TextInputAction.newline,
                       // Auto-grow with content up to 4 lines, then become scrollable
                       minLines: 1,
                       maxLines: 4,
                       scrollPhysics: const BouncingScrollPhysics(),
                        // Make the send TextField text dark grey
                        style: const TextStyle(color: AppTheme.darkGray),
                      decoration: InputDecoration(
                        hintText: _canSend ? 'Type a message…' : 'Only Todd or John can send messages',
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppTheme.primaryOrange),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                       // In multiline, Enter should insert a newline; use the Send button to submit
                      enabled: _canSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _canSend ? _send : null,
                    icon: const Icon(Icons.send, color: AppTheme.black, size: 18),
                    label: const Text('Send', style: TextStyle(color: AppTheme.black)),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(AppTheme.primaryOrange),
                      side: WidgetStateProperty.all(const BorderSide(color: AppTheme.black, width: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt);
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m $ampm';
  }
}
