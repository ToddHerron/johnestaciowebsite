import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:john_estacio_website/features/admin/presentation/works/data_mapping_dialog.dart';
import 'package:john_estacio_website/features/admin/presentation/works/edit_work_detail_dialog.dart';
import 'package:john_estacio_website/features/admin/presentation/works/work_preview_dialog.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart'
    hide ButtonStyle;
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/features/categories/data/categories_repository.dart';
import 'package:john_estacio_website/features/categories/domain/work_category.dart';

// Indicates which version is currently being displayed/edited in the UI
enum AdminWorkViewMode { draft, live }

class EditWorkPage extends StatefulWidget {
  final String workId;
  const EditWorkPage({super.key, required this.workId});

  @override
  State<EditWorkPage> createState() => _EditWorkPageState();
}

class _EditWorkPageState extends State<EditWorkPage> {
  final _formKey = GlobalKey<FormState>();
  final WorksRepository _worksRepository = WorksRepository();
  final CategoriesRepository _categoriesRepository = CategoriesRepository();

  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _subtitleController;
  late TextEditingController _instrumentationController;
  late TextEditingController _durationController;
  late ScrollController _scrollController;
  List<WorkDetail> _details = [];
  int _originalOrder = 0;
  List<String> _categories = [];
  bool _hasDataIntegrityIssue = false;
  bool _allowMixedCaseTitle = false; // default to ALL CAPS

  bool _isLoading = true;
  bool get _isNewWork => widget.workId == 'new';

  // Represents whether a draft exists on the server (currentStatus)
  WorkStatus _status = WorkStatus.published;

  // The currently visible view (Draft | Live)
  AdminWorkViewMode _viewMode = AdminWorkViewMode.live;

  // Cached copies of live and draft for switching views
  Work? _liveWork;
  Work? _draftWork;
  bool get _hasDraft => _draftWork != null;
  // Local override for live visibility to support optimistic UI updates
  bool? _liveVisibility;
  bool _isTogglingVisibility = false;

  // Edit interception
  bool _suspendEditListener = false;
  bool _editPromptActive = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _yearController = TextEditingController();
    _subtitleController = TextEditingController();
    _instrumentationController = TextEditingController();
    _durationController = TextEditingController();
    _scrollController = ScrollController();

    void Function() onFieldEdit = _handleAnyEdit;
    _titleController.addListener(onFieldEdit);
    _yearController.addListener(onFieldEdit);
    _subtitleController.addListener(onFieldEdit);
    _instrumentationController.addListener(onFieldEdit);
    _durationController.addListener(onFieldEdit);

    if (!_isNewWork) {
      _loadWorkData();
    } else {
      _status = WorkStatus.draft; // new work implies creating a draft
      _viewMode = AdminWorkViewMode.draft;
      setState(() {
        _isLoading = false;
        _hasDataIntegrityIssue = false;
      });
    }
  }

  Future<void> _loadWorkData() async {
    try {
      final doc = await _worksRepository.getWorkDoc(widget.workId);
      final data = doc.data() ?? <String, dynamic>{};
      final rawStatus = (data['currentStatus'] ?? 'published').toString();
      _status = rawStatus == 'draft' ? WorkStatus.draft : WorkStatus.published;

      // Build live and draft models
      _liveWork = Work.fromFirestore(doc);
      final Map<String, dynamic>? draftMap =
          data['draft'] as Map<String, dynamic>?;
      _draftWork = draftMap != null
          ? Work.fromDataMap(id: doc.id, data: draftMap)
          : null;
      _liveVisibility = _liveWork?.isVisible;

      // Pick initial view: Draft if a draft exists; otherwise Live
      _viewMode = _hasDraft ? AdminWorkViewMode.draft : AdminWorkViewMode.live;

      // Populate form based on current view
      _applyWorkToForm(_hasDraft ? _draftWork! : _liveWork!);

      setState(() {
        _isLoading = false;
        _originalOrder = _liveWork?.order ?? 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading work data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyWorkToForm(Work work) {
    _suspendEditListener = true;
    try {
      _titleController.text = work.title;
      _yearController.text = work.year;
      _subtitleController.text = work.subtitle;
      _instrumentationController.text = work.instrumentation;
      _durationController.text = work.duration;
      _details = List<WorkDetail>.from(work.details);
      _categories = List<String>.from(work.categories);
      _hasDataIntegrityIssue = work.hasDataIntegrityIssue;
      _allowMixedCaseTitle = work.allowMixedCaseTitle;
    } finally {
      _suspendEditListener = false;
    }
  }

  Future<void> _togglePublicVisibility() async {
    if (_isNewWork || _liveWork == null || _isTogglingVisibility) return;
    final current = _liveVisibility ?? (_liveWork?.isVisible ?? true);
    final next = !current;
    setState(() {
      _isTogglingVisibility = true;
      _liveVisibility = next; // optimistic update
    });
    try {
      await _worksRepository.setVisibility(
        widget.workId,
        isVisible: next,
        titleForCache: _liveWork?.title,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next ? 'Work is now visible publicly.' : 'Work hidden from public.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Failed to toggle visibility: $e');
      if (mounted) {
        setState(() {
          _liveVisibility = current; // revert
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update visibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingVisibility = false);
    }
  }

  Work _buildWorkFromForm() {
    // normalize order on details
    for (int i = 0; i < _details.length; i++) {
      final d = _details[i];
      _details[i] = WorkDetail(
        id: d.id,
        order: i,
        displayType: d.displayType,
        buttonStyle: d.buttonStyle,
        buttonText: d.buttonText,
        detailType: d.detailType,
        content: d.content,
        isCorrupted: d.isCorrupted,
        isTitleVisible: d.isTitleVisible,
        isVisibleDetailTitle: d.isVisibleDetailTitle,
        width: d.width,
        height: d.height,
        storagePath: d.storagePath,
      );
    }

    return Work(
      id: _isNewWork ? '' : widget.workId,
      title: _titleController.text,
      year: _yearController.text,
      subtitle: _subtitleController.text,
      instrumentation: _instrumentationController.text,
      duration: _durationController.text,
      details: _details,
      order: _isNewWork
          ? ((GoRouterState.of(context).extra as int?) ?? 0)
          : _originalOrder,
      categories: _categories,
      hasDataIntegrityIssue: _hasDataIntegrityIssue,
      status: _status,
      allowMixedCaseTitle: _allowMixedCaseTitle,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _subtitleController.dispose();
    _instrumentationController.dispose();
    _durationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAnyEdit() async {
    if (_suspendEditListener) return;
    if (_viewMode == AdminWorkViewMode.draft) return; // normal editing in Draft

    // When editing while viewing Live
    if (_isNewWork) {
      setState(() {
        _viewMode = AdminWorkViewMode.draft;
        _status = WorkStatus.draft;
      });
      return;
    }

    if (_editPromptActive) return;
    _editPromptActive = true;

    if (_hasDraft) {
      // Ask user whether to overwrite existing draft
      final action = await showDialog<_EditLiveAction>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Draft exists'),
            content:
                const Text('Do you want to overwrite the current draft work?'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_EditLiveAction.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_EditLiveAction.switchToDraft),
                child: const Text('Edit Existing Draft'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_EditLiveAction.overwriteDraft),
                child: const Text('Overwrite Draft'),
              ),
            ],
          );
        },
      );

      if (action == _EditLiveAction.overwriteDraft) {
        // Keep current (live) form values, but switch to Draft mode so saves go to draft
        setState(() {
          _viewMode = AdminWorkViewMode.draft;
          _status = WorkStatus.draft;
        });
      } else if (action == _EditLiveAction.switchToDraft) {
        // Load the existing draft into the form and switch view
        setState(() {
          _viewMode = AdminWorkViewMode.draft;
        });
        if (_draftWork != null) {
          _applyWorkToForm(_draftWork!);
        }
      } else {
        // Cancel: revert any accidental input by restoring live values
        if (_liveWork != null) {
          _applyWorkToForm(_liveWork!);
        }
      }
    } else {
      // No draft exists: switch to Draft automatically for edits
      setState(() {
        _viewMode = AdminWorkViewMode.draft;
        _status = WorkStatus.draft;
      });
      // Keep current (live) values in the form as the starting draft content
    }

    _editPromptActive = false;
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final draftWork = _buildWorkFromForm();
    try {
      if (_isNewWork) {
        final newRef = await _worksRepository.createDraft(
          draftWork,
          explicitOrder: draftWork.order,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft created.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/admin/works/edit/${newRef.id}');
        return;
      } else {
        await _worksRepository.saveDraft(widget.workId, draftWork);
        if (!mounted) return;
        setState(() {
          _status = WorkStatus.draft;
          _draftWork = draftWork;
          _viewMode = AdminWorkViewMode.draft;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving draft: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _publish() async {
    // Always save current form as draft before publishing
    await _saveDraft();
    if (_isNewWork) return; // navigation has occurred

    setState(() => _isLoading = true);
    try {
      await _worksRepository.publishDraft(widget.workId);
      if (!mounted) return;
      setState(() => _status = WorkStatus.published);
      await _loadWorkData();
      if (!mounted) return;
      _viewMode = AdminWorkViewMode.live;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Published.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error publishing: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToLive() async {
    if (_isNewWork) {
      // Just clear the form
      setState(() {
        _titleController.clear();
        _yearController.clear();
        _subtitleController.clear();
        _instrumentationController.clear();
        _durationController.clear();
        _details = [];
        _categories = [];
        _hasDataIntegrityIssue = false;
        _status = WorkStatus.draft;
        _viewMode = AdminWorkViewMode.draft;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _worksRepository.resetDraft(widget.workId);
      await _loadWorkData();
      if (!mounted) return;
      setState(() {
        _status = WorkStatus.published;
        _viewMode = AdminWorkViewMode.live;
      });
      if (_liveWork != null) _applyWorkToForm(_liveWork!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Draft discarded. Reverted to live copy.'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error discarding draft: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOrEditDetail({WorkDetail? existingDetail, int? index}) async {
    final result = await showDialog<WorkDetail>(
      context: context,
      builder: (context) => EditWorkDetailDialog(detail: existingDetail),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _details[index] = result;
        } else {
          _details.add(result);
        }
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final WorkDetail item = _details.removeAt(oldIndex);
      _details.insert(newIndex, item);
    });
  }

  String _getDetailSubtitle(WorkDetail detail) {
    try {
      return 'Type: ${detail.detailType.name} | Display: ${detail.displayType.name}';
    } catch (e) {
      return 'Invalid/Corrupted Data';
    }
  }

  void _populateFormWithMappedData(Work mappedWork) {
    setState(() {
      _applyWorkToForm(mappedWork);
      _status = WorkStatus.draft;
      _viewMode = AdminWorkViewMode.draft;
    });
  }

  Future<void> _showDataMappingDialog() async {
    final mappedWork = await showDialog<Work>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          DataMappingDialog(currentWorkTitle: _titleController.text),
    );

    if (mappedWork != null && mounted) {
      _populateFormWithMappedData(mappedWork);
    }
  }

  void _showPreviewDialog() {
    final previewWork = _buildWorkFromForm();
    showDialog(
      context: context,
      builder: (context) =>
          WorkPreviewDialog(work: previewWork, preferLocalDraft: true),
    );
  }

  List<Widget> _buildCategoryChipsFrom(List<String> availableNames) {
    final selectedSet = _categories.map((e) => e.toUpperCase()).toSet();
    final merged = {
      ...availableNames.map((e) => e.toUpperCase()),
      ...selectedSet
    }.toList();
    // Preserve master order first, then any unknown selected items alphabetically at end
    final masterOrdered = [
      ...availableNames.map((e) => e.toUpperCase()),
      ...merged
          .where((e) => !availableNames.map((x) => x.toUpperCase()).contains(e))
          .toList()
        ..sort(),
    ];
    return masterOrdered.map((cat) {
      final isSelected = selectedSet.contains(cat.toUpperCase());
      return ChoiceChip(
        label: Text(cat.toUpperCase()),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            if (val) {
              if (!_categories
                  .map((e) => e.toUpperCase())
                  .contains(cat.toUpperCase())) {
                _categories = [..._categories, cat.toUpperCase()];
              }
            } else {
              _categories = _categories
                  .where((c) => c.toUpperCase() != cat.toUpperCase())
                  .toList();
            }
          });
        },
        showCheckmark: true,
        checkmarkColor: AppTheme.black,
        selectedColor: AppTheme.primaryOrange,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.black : AppTheme.primaryOrange,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: AppTheme.white,
        side: const BorderSide(color: AppTheme.primaryOrange),
      );
    }).toList();
  }

  void _switchView(AdminWorkViewMode mode) {
    setState(() => _viewMode = mode);
    if (mode == AdminWorkViewMode.live) {
      if (_liveWork != null) _applyWorkToForm(_liveWork!);
    } else {
      if (_draftWork != null) {
        _applyWorkToForm(_draftWork!);
      } else {
        // No draft exists; keep current form values (acts as starting draft)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final uniqueDetails =
        _details.where((detail) => seen.add(detail.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
          _isNewWork ? 'Add New Work' : 'Edit Work',
          style: const TextStyle(color: AppTheme.darkGray),
        ),
        backgroundColor: AppTheme.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.darkGray),
          tooltip: 'Close',
          onPressed: () => context.go('/admin/works'),
        ),
        actions: [
          // Save Draft
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveDraft,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_as),
            label: Text(_isLoading ? 'Saving...' : 'Save Draft'),
          ),
          const SizedBox(width: 8),
          // Publish
          ElevatedButton.icon(
            onPressed: _isLoading || _isNewWork ? null : _publish,
            icon: const Icon(Icons.publish),
            label: const Text('Publish'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // View switcher (Draft | Live)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Viewing:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: AppTheme.darkGray),
                            ),
                            // Segmented: Draft | Live (custom styled)
                            Theme(
                              data: Theme.of(context).copyWith(
                                segmentedButtonTheme: SegmentedButtonThemeData(
                                  style: ButtonStyle(
                                    side: WidgetStateProperty.all(
                                        const BorderSide(
                                            color: AppTheme.primaryOrange)),
                                    backgroundColor:
                                        WidgetStateProperty.all(AppTheme.white),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith<Color>(
                                            (states) {
                                      return states
                                              .contains(WidgetState.selected)
                                          ? AppTheme.primaryOrange
                                          : AppTheme.darkGray;
                                    }),
                                  ),
                                ),
                              ),
                              child: SegmentedButton<AdminWorkViewMode>(
                                // Use built-in selected icon to avoid adding width inside labels
                                showSelectedIcon: true,
                                segments: <ButtonSegment<AdminWorkViewMode>>[
                                  ButtonSegment<AdminWorkViewMode>(
                                    value: AdminWorkViewMode.draft,
                                    label: Text(
                                      'Draft',
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: _viewMode ==
                                                AdminWorkViewMode.draft
                                            ? AppTheme.primaryOrange
                                            : AppTheme.darkGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  ButtonSegment<AdminWorkViewMode>(
                                    value: AdminWorkViewMode.live,
                                    label: Text(
                                      'Live',
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: _viewMode ==
                                                AdminWorkViewMode.live
                                            ? AppTheme.primaryOrange
                                            : AppTheme.darkGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                selected: <AdminWorkViewMode>{_viewMode},
                                onSelectionChanged: (selection) {
                                  if (selection.isEmpty) return;
                                  _switchView(selection.first);
                                },
                              ),
                            ),
                            // Status indicators aligned with work list: visibility, preview, draft presence
                            Builder(builder: (context) {
                              final bool visibleToPublic =
                                  _liveVisibility ?? (_liveWork?.isVisible ?? true);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Visible to public toggle
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Tooltip(
                                      message: _isTogglingVisibility
                                          ? 'Updating…'
                                          : visibleToPublic
                                              ? 'Visible to public (tap to hide)'
                                              : 'Hidden from public (tap to show)',
                                      child: _isTogglingVisibility
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                visibleToPublic
                                                    ? Icons.visibility
                                                    : Icons.visibility_off,
                                                color: visibleToPublic
                                                    ? Colors.green
                                                    : AppTheme.darkGray,
                                              ),
                                              onPressed: (_isNewWork || _liveWork == null)
                                                  ? null
                                                  : _togglePublicVisibility,
                                            ),
                                    ),
                                  ),
                                  // Preview
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new, color: AppTheme.darkGray),
                                    tooltip: 'Preview',
                                    onPressed: _showPreviewDialog,
                                  ),
                                  // Draft presence indicator
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Tooltip(
                                      message: _hasDraft ? 'Draft exists' : 'No draft',
                                      child: Icon(
                                        Icons.edit_document,
                                        color: _hasDraft
                                            ? AppTheme.primaryOrange
                                            : AppTheme.lightGray,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            TextButton.icon(
                              onPressed: _showDataMappingDialog,
                              icon: const Icon(Icons.sync_alt),
                              label: const Text('Pull Work Data'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.darkGray),
                            ),
                            TextButton.icon(
                              onPressed: _isLoading || _isNewWork
                                  ? null
                                  : _resetToLive,
                              icon: const Icon(Icons.restore),
                              label: const Text('Reset to Live'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.darkGray),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Expandable top metadata fields
                        ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(right: 48.0),
                          collapsedIconColor: AppTheme.primaryOrange,
                          iconColor: AppTheme.primaryOrange,
                          title: TextFormField(
                            controller: _titleController,
                            style: const TextStyle(color: AppTheme.darkGray),
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              labelStyle: TextStyle(color: AppTheme.darkGray),
                              filled: true,
                              fillColor: AppTheme.white,
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Please enter a title' : null,
                          ),
                          children: [
                            const SizedBox(height: 16),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Allow mixed case title',
                                  style: TextStyle(color: AppTheme.darkGray)),
                              subtitle: const Text(
                                'When off, the title is displayed in ALL CAPS on the public site.',
                                style: TextStyle(color: AppTheme.darkGray),
                              ),
                              activeColor: AppTheme.primaryOrange,
                              value: _allowMixedCaseTitle,
                              onChanged: (val) {
                                setState(() => _allowMixedCaseTitle = val);
                                _handleAnyEdit();
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _yearController,
                              style: const TextStyle(color: AppTheme.darkGray),
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                labelStyle: TextStyle(color: AppTheme.darkGray),
                                filled: true,
                                fillColor: AppTheme.white,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Please enter a year' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _subtitleController,
                              style: const TextStyle(color: AppTheme.darkGray),
                              decoration: const InputDecoration(
                                labelText: 'Subtitle',
                                labelStyle: TextStyle(color: AppTheme.darkGray),
                                filled: true,
                                fillColor: AppTheme.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _instrumentationController,
                              style: const TextStyle(color: AppTheme.darkGray),
                              decoration: const InputDecoration(
                                labelText: 'Instrumentation',
                                labelStyle: TextStyle(color: AppTheme.darkGray),
                                filled: true,
                                fillColor: AppTheme.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _durationController,
                              style: const TextStyle(color: AppTheme.darkGray),
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                labelStyle: TextStyle(color: AppTheme.darkGray),
                                filled: true,
                                fillColor: AppTheme.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Categories section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categories',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: AppTheme.darkGray),
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<List<WorkCategory>>(
                                stream: _categoriesRepository
                                    .getCategoriesStream(includeInactive: true),
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return Text(
                                        'Error loading categories: ${snap.error}',
                                        style:
                                            const TextStyle(color: Colors.red));
                                  }
                                  if (!snap.hasData) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child:
                                          LinearProgressIndicator(minHeight: 2),
                                    );
                                  }
                                  final activeOrAll = snap.data!;
                                  final available =
                                      activeOrAll.map((c) => c.name).toList();
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _buildCategoryChipsFrom(available),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Details',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: AppTheme.darkGray)),
                            TextButton.icon(
                              onPressed: () => _addOrEditDetail(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Detail'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: uniqueDetails.isEmpty
                              ? const Center(
                                  child: Text('No details added yet.'))
                              : Scrollbar(
                                  thumbVisibility: true,
                                  controller: _scrollController,
                                  child: ReorderableListView.builder(
                                    scrollController: _scrollController,
                                    buildDefaultDragHandles: false,
                                    proxyDecorator: (Widget child, int index,
                                        Animation<double> animation) {
                                      return Material(
                                        color: AppTheme.white,
                                        elevation: 4.0,
                                        child: child,
                                      );
                                    },
                                    itemCount: uniqueDetails.length,
                                    onReorder: (oldIndex, newIndex) =>
                                        _onReorder(oldIndex, newIndex),
                                    itemBuilder: (context, index) {
                                      final detail = uniqueDetails[index];
                                      final bool isVisuallyCorrupted =
                                          detail.isCorrupted ||
                                              detail.buttonText ==
                                                  '[Title Missing]' ||
                                              detail.buttonText ==
                                                  '[Button Text Missing]';

                                      return Card(
                                        key: ValueKey(detail.id),
                                        color: isVisuallyCorrupted
                                            ? Colors.red.withAlpha(25)
                                            : AppTheme.lightGray.withAlpha(128),
                                        child: ListTile(
                                          leading: ReorderableDragStartListener(
                                            index: index,
                                            child: const Icon(Icons.drag_handle,
                                                color: AppTheme.darkGray),
                                          ),
                                          title: Text(
                                            detail.buttonText,
                                            style: TextStyle(
                                              color: isVisuallyCorrupted
                                                  ? Colors.red
                                                  : AppTheme.darkGray,
                                              fontWeight: isVisuallyCorrupted
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _getDetailSubtitle(detail),
                                            style: TextStyle(
                                              color: isVisuallyCorrupted
                                                  ? Colors.red
                                                  : AppTheme.darkGray,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: AppTheme.darkGray),
                                                onPressed: () =>
                                                    _addOrEditDetail(
                                                        existingDetail: detail,
                                                        index: index),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red),
                                                onPressed: () {
                                                  setState(() {
                                                    _details.removeAt(index);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

enum _EditLiveAction { overwriteDraft, switchToDraft, cancel }
