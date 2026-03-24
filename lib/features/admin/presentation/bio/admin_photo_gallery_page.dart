import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:john_estacio_website/features/about/data/photo_gallery_repository.dart';
import 'package:john_estacio_website/features/about/domain/models/photo_item.dart';
import 'package:john_estacio_website/features/admin/presentation/works/file_uploader_widget.dart';
import 'package:john_estacio_website/theme.dart';

class AdminPhotoGalleryPage extends StatefulWidget {
  const AdminPhotoGalleryPage({super.key});

  @override
  State<AdminPhotoGalleryPage> createState() => _AdminPhotoGalleryPageState();
}

class _AdminPhotoGalleryPageState extends State<AdminPhotoGalleryPage> {
  final PhotoGalleryRepository _repo = PhotoGalleryRepository();
  bool _savingOrder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.darkGray,
        title: const Text('Edit Photo Gallery', style: TextStyle(color: AppTheme.darkGray)),
        actions: [
          if (_savingOrder)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await showDialog<bool>(
            context: context,
            builder: (_) => _PhotoEditDialog(repo: _repo),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo saved'), backgroundColor: Colors.green),
            );
          }
        },
        icon: const Icon(Icons.add, color: AppTheme.black),
        label: const Text('Add Photo', style: TextStyle(color: AppTheme.black)),
        backgroundColor: AppTheme.primaryOrange,
      ),
      body: Container(
        color: AppTheme.lightGray,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<BioPhotoItem>>(
            stream: _repo.streamAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final err = snapshot.error;
                String message = err.toString();
                String hint = '';
                if (err is FirebaseException && err.code == 'failed-precondition') {
                  hint = 'Firestore reports that this query requires a composite index.\n'
                      'Create an index for collection "bio_gallery" with fields: order (ascending), createdAt (descending).\n'
                      'If the error message includes a link, open it to auto-create the index. After creation, it may take a minute to build.';
                  if (err.message != null && err.message!.isNotEmpty) {
                    message = err.message!;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Card(
                        color: Colors.red.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Error',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                message,
                                style: const TextStyle(color: AppTheme.white),
                              ),
                              if (hint.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SelectableText(
                                  hint,
                                  style: const TextStyle(color: AppTheme.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text('No photos yet. Click "Add Photo" to create one.', style: TextStyle(color: AppTheme.lightGray)),
                );
              }
        
              return ReorderableListView.builder(
                itemCount: items.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex -= 1;
                  setState(() => _savingOrder = true);
                  try {
                    final updated = List<BioPhotoItem>.from(items);
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    // Persist new order as 0..n
                    for (int i = 0; i < updated.length; i++) {
                      if (updated[i].order != i) {
                        await _repo.update(updated[i].id, {'order': i});
                      }
                    }
                  } finally {
                    if (mounted) setState(() => _savingOrder = false);
                  }
                },
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    key: ValueKey(item.id),
                    color: AppTheme.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      leading: SizedBox(
                        width: 110,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_indicator, color: AppTheme.darkGray),
                            ),
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: Colors.black.withValues(alpha: 0.04),
                                child: _StorageBackedImage(item: item, fit: BoxFit.cover),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        item.title.isEmpty ? '(untitled)' : item.title,
                        style: const TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.description.isNotEmpty)
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.darkGray),
                            ),
                          if (item.storagePath.isNotEmpty)
                            Text(
                              item.storagePath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.lightGray, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: item.visible ? 'Hide from public gallery' : 'Show on public gallery',
                            icon: Icon(
                              item.visible ? Icons.visibility : Icons.visibility_off,
                              color: item.visible ? Colors.green : AppTheme.darkGray,
                            ),
                            onPressed: () async {
                              await _repo.update(item.id, {'visible': !item.visible});
                            },
                          ),
                          IconButton(
                            tooltip: 'Preview',
                            icon: const Icon(Icons.photo, color: AppTheme.darkGray),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: _StorageBackedImage(item: item, fit: BoxFit.contain),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                            onPressed: () async {
                              final saved = await showDialog<bool>(
                                context: context,
                                builder: (_) => _PhotoEditDialog(repo: _repo, existing: item),
                              );
                              if (saved == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Photo updated'), backgroundColor: Colors.green),
                                );
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete Photo'),
                                  content: const Text('Are you sure you want to delete this photo? This action cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _repo.delete(item.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo deleted'), backgroundColor: Colors.green));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoEditDialog extends StatefulWidget {
  final PhotoGalleryRepository repo;
  final BioPhotoItem? existing;
  const _PhotoEditDialog({required this.repo, this.existing});

  @override
  State<_PhotoEditDialog> createState() => _PhotoEditDialogState();
}

class _PhotoEditDialogState extends State<_PhotoEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  String _imageUrl = '';
  bool _visible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description = TextEditingController(text: widget.existing?.description ?? '');
    _imageUrl = widget.existing?.imageUrl ?? '';
    _visible = widget.existing?.visible ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.existing == null ? 'Add Photo' : 'Edit Photo', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  // Thumbnail + Dropzone side by side with equal height
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail preview
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 150,
                            color: Colors.black.withValues(alpha: 0.06),
                            child: _DialogImagePreview(
                              imageUrl: _imageUrl,
                              storagePath: widget.existing?.storagePath ?? '',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Dropzone uploader
                      Expanded(
                        child: SizedBox(
                          height: 150,
                          child: FileUploaderWidget(
                            initialUrl: _imageUrl,
                            onUrlChanged: (url) => setState(() => _imageUrl = url),
                            fileTypeDescription: 'an image (JPG, PNG, WebP, GIF)',
                            showUrlField: false,
                            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
                            allowedMime: const ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _visible,
                    onChanged: (v) => setState(() => _visible = v),
                    title: const Text('Visible on public gallery'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving...' : 'Save'),
                        ),
                      ],
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hasExistingImage = widget.existing != null &&
        ((widget.existing!.imageUrl.isNotEmpty) || (widget.existing!.storagePath.isNotEmpty));
    final hasNewImage = _imageUrl.isNotEmpty;
    if (!hasExistingImage && !hasNewImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: SelectableText('Please upload an image'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await widget.repo.create(
          imageUrl: _imageUrl,
          storagePath: '',
          title: _title.text.trim(),
          description: _description.text.trim(),
          visible: _visible,
          order: 9999, // append at the end; can reorder later
        );
      } else {
        await widget.repo.update(widget.existing!.id, {
          'imageUrl': _imageUrl,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'visible': _visible,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: SelectableText('Error saving photo: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DialogImagePreview extends StatelessWidget {
  final String imageUrl;
  final String storagePath;
  const _DialogImagePreview({required this.imageUrl, required this.storagePath});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return Image.network(imageUrl, fit: BoxFit.cover);
    }
    if (storagePath.isNotEmpty) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
            return const Center(child: Icon(Icons.broken_image));
          }
          return Image.network(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    return const Center(child: Icon(Icons.image, color: AppTheme.darkGray));
  }
}

class _StorageBackedImage extends StatelessWidget {
  final BioPhotoItem item;
  final BoxFit fit;
  const _StorageBackedImage({required this.item, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl.isNotEmpty) {
      return Image.network(item.imageUrl, fit: fit);
    }
    if (item.storagePath.isEmpty) {
      return const Center(child: Icon(Icons.broken_image));
    }
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(item.storagePath).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return const Center(child: Icon(Icons.broken_image));
        }
        return Image.network(snapshot.data!, fit: fit);
      },
    );
  }
}
