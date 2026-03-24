import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart' hide ButtonStyle;
import 'package:john_estacio_website/features/works/presentation/widgets/work_card.dart';
import 'package:john_estacio_website/theme.dart';

enum _PreviewViewMode { draft, live }

class WorkPreviewDialog extends StatefulWidget {
  final Work work; // Published or local snapshot
  // If true (Edit page), Draft view should prefer local form snapshot over Firestore draft
  final bool preferLocalDraft;

  const WorkPreviewDialog({super.key, required this.work, this.preferLocalDraft = false});

  @override
  State<WorkPreviewDialog> createState() => _WorkPreviewDialogState();
}

class _WorkPreviewDialogState extends State<WorkPreviewDialog> {
  final WorksRepository _repo = WorksRepository();

  Work? _draftWork; // parsed from doc['draft'] map
  Work? _liveWork;  // parsed from live/top-level fields
  bool _loading = true;
  String? _loadError;
  // Start in Draft view so the preview matches current edits by default
  _PreviewViewMode _viewMode = _PreviewViewMode.draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _repo.getWorkDoc(widget.work.id);
      final data = snap.data() ?? {};
      // Build the latest live/top-level work (for Live preview)
      try {
        _liveWork = Work.fromFirestore(snap);
      } catch (e) {
        // swallow parse error for live work; preview can still show the passed-in snapshot
      }
      final draftMap = data['draft'] as Map<String, dynamic>?;
      if (draftMap != null) {
        final draft = Work.fromDataMap(id: widget.work.id, data: draftMap);
        setState(() {
          _draftWork = draft;
        });
      }
    } catch (e) {
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDraft = _draftWork != null;
    final bool canShowDraft = hasDraft || widget.preferLocalDraft;
    // Prefer the passed-in work (current form snapshot) while the saved draft is loading
    // so the preview immediately reflects on-screen edits. Once the saved draft arrives
    // we switch to it to match server state.
    final Work visibleWork = _viewMode == _PreviewViewMode.draft
        ? (widget.preferLocalDraft ? widget.work : (_draftWork ?? widget.work))
        : (_liveWork ?? widget.work);


    return Dialog(
      backgroundColor: AppTheme.black,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with segmented control + close
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Public Page Preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppTheme.white),
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                      ),
                    )
                  else if (_loadError != null)
                    Tooltip(
                      message: 'Failed to load draft: $_loadError',
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.error_outline, color: Colors.orange),
                      ),
                    )
                  else
                    Flexible(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          segmentedButtonTheme: SegmentedButtonThemeData(
                            style: ButtonStyle(
                              side: WidgetStateProperty.all(const BorderSide(color: AppTheme.primaryOrange)),
                              backgroundColor: WidgetStateProperty.all(AppTheme.darkGray),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                // We custom-color text below; keep default here
                                return AppTheme.primaryOrange;
                              }),
                            ),
                          ),
                        ),
                        child: SegmentedButton<_PreviewViewMode>(
                        // Use built-in selected icon; keep labels compact to avoid overflows
                        showSelectedIcon: true,
                        segments: <ButtonSegment<_PreviewViewMode>>[
                          ButtonSegment<_PreviewViewMode>(
                            value: _PreviewViewMode.draft,
                            label: Text(
                              'Draft',
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: _viewMode == _PreviewViewMode.draft
                                    ? AppTheme.primaryOrange
                                    : AppTheme.lightGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ButtonSegment<_PreviewViewMode>(
                            value: _PreviewViewMode.live,
                            label: Text(
                              'Live',
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: _viewMode == _PreviewViewMode.live
                                    ? AppTheme.primaryOrange
                                    : AppTheme.lightGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        selected: <_PreviewViewMode>{
                          canShowDraft ? _viewMode : _PreviewViewMode.live,
                        },
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          final next = selection.first;
                          if (next == _PreviewViewMode.draft && !canShowDraft) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No draft available.'), backgroundColor: Colors.orange),
                            );
                            setState(() => _viewMode = _PreviewViewMode.live);
                          } else {
                            setState(() => _viewMode = next);
                          }
                        },
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),

            // Scrollable Preview Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: WorkCard(work: visibleWork),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
