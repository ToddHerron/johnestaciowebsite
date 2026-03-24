import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/data/stored_files_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/domain/stored_file_model.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/file_preview_dialog.dart';
import 'package:john_estacio_website/theme.dart';

enum PickerFileKind { audio, pdf, image }

class StorageFilePickerResult {
  final Reference ref;
  final String url;
  final String titleOrName;
  final PickerFileKind kind;
  const StorageFilePickerResult({
    required this.ref,
    required this.url,
    required this.titleOrName,
    required this.kind,
  });
}

class StorageFilePickerDialog extends StatefulWidget {
  final PickerFileKind kind;
  const StorageFilePickerDialog({super.key, required this.kind});

  @override
  State<StorageFilePickerDialog> createState() => _StorageFilePickerDialogState();
}

class _StorageFilePickerDialogState extends State<StorageFilePickerDialog> {
  final _repo = StoredFilesRepository();
  late Future<List<StoredFile>> _future;
  final TextEditingController _filterCtrl = TextEditingController();
  String _filter = '';
  StoredFile? _selected;
  Future<String>? _previewUrlFuture;

  @override
  void initState() {
    super.initState();
    _future = _repo.listFiles();
    _filterCtrl.addListener(() {
      setState(() => _filter = _filterCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  bool _matchesKind(StoredFile f) {
    final n = f.ref.name.toLowerCase();
    switch (widget.kind) {
      case PickerFileKind.audio:
        return n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a') || n.endsWith('.aac') || n.endsWith('.ogg');
      case PickerFileKind.pdf:
        return n.endsWith('.pdf');
      case PickerFileKind.image:
        return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.gif') || n.endsWith('.webp');
    }
  }

  IconData _iconFor(StoredFile f) {
    final n = f.ref.name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a') || n.endsWith('.aac') || n.endsWith('.ogg')) return Icons.audiotrack;
    if (n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.gif') || n.endsWith('.webp')) return Icons.image;
    return Icons.insert_drive_file;
  }

  PickerFileKind _kindOf(StoredFile f) {
    final n = f.ref.name.toLowerCase();
    if (n.endsWith('.pdf')) return PickerFileKind.pdf;
    if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a') || n.endsWith('.aac') || n.endsWith('.ogg')) return PickerFileKind.audio;
    return PickerFileKind.image;
  }

  String _displayTitle(StoredFile f) {
    return (f.title.isNotEmpty ? f.title : f.ref.name);
  }

  void _select(StoredFile f) {
    setState(() {
      _selected = f;
      _previewUrlFuture = f.ref.getDownloadURL();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose from Stored ${widget.kind.name.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.darkGray),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _filterCtrl,
                decoration: InputDecoration(
                  labelText: 'Filter by title',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, color: AppTheme.darkGray),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.darkGray),
                          onPressed: () => _filterCtrl.clear(),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<StoredFile>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final all = (snapshot.data ?? []);
                  final filtered = all
                      .where(_matchesKind)
                      .where((f) => _filter.isEmpty || _displayTitle(f).toLowerCase().contains(_filter.toLowerCase()))
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No files found.'));
                  }
                  return Row(
                    children: [
                      // List
                      Expanded(
                        flex: 5,
                        child: Material(
                          color: AppTheme.white,
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final f = filtered[index];
                              final isSel = _selected?.ref.fullPath == f.ref.fullPath;
                              return ListTile(
                                selected: isSel,
                                selectedTileColor: Colors.orange.withValues(alpha: 0.08),
                                leading: Material(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(_iconFor(f), color: AppTheme.darkGray),
                                  ),
                                ),
                                title: Text(_displayTitle(f), overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.darkGray)),
                                subtitle: Text(f.ref.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.darkGray)),
                                onTap: () => _select(f),
                                trailing: IconButton(
                                  tooltip: 'Preview',
                                  icon: const Icon(Icons.open_in_new, color: AppTheme.darkGray),
                                  onPressed: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (_) => FilePreviewDialog(file: f),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      // Preview pane
                      Expanded(
                        flex: 6,
                        child: _selected == null
                            ? const Center(child: Text('Select a file to preview'))
                            : FutureBuilder<String>(
                                future: _previewUrlFuture,
                                builder: (context, s) {
                                  if (s.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (s.hasError || !s.hasData) {
                                    return const Center(child: Text('Could not load preview'));
                                  }
                                  final url = s.data!;
                                  final kind = _kindOf(_selected!);
                                  switch (kind) {
                                    case PickerFileKind.image:
                                      return InteractiveViewer(child: Image.network(url, fit: BoxFit.contain));
                                    case PickerFileKind.pdf:
                                      return Center(child: Text('PDF preview opens in the edit dialog.'));
                                    case PickerFileKind.audio:
                                      return AudioPreview(url: url);
                                  }
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => setState(() => _future = _repo.listFiles(forceRefresh: true)),
                    icon: const Icon(Icons.refresh, color: AppTheme.darkGray),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () async {
                            final sel = _selected!;
                            final url = await sel.ref.getDownloadURL();
                            final res = StorageFilePickerResult(
                              ref: sel.ref,
                              url: url,
                              titleOrName: _displayTitle(sel),
                              kind: _kindOf(sel),
                            );
                            if (mounted) Navigator.of(context).pop(res);
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
