import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:john_estacio_website/core/utils/link_proxy.dart';
import 'package:john_estacio_website/core/utils/file_proxy.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/data/stored_files_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/domain/stored_file_model.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:just_audio/just_audio.dart';

enum FileType { image, pdf, audio, unknown }

class FilePreviewDialog extends StatefulWidget {
  final StoredFile file;
  final VoidCallback? onTitleSaved;

  const FilePreviewDialog({super.key, required this.file, this.onTitleSaved});

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  final StoredFilesRepository _repository = StoredFilesRepository();
  late final TextEditingController _titleController;
  late Future<String> _urlFuture;
  FileType _fileType = FileType.unknown;

  @override
  void initState() {
    super.initState();
    _urlFuture = widget.file.ref.getDownloadURL();
    _fileType = _getFileType(widget.file.ref.name);
    _titleController = TextEditingController(text: widget.file.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    final newTitle = _titleController.text;
    if (newTitle != widget.file.title) {
      try {
        await _repository.updateFileTitle(widget.file.ref, newTitle);
        widget.onTitleSaved?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Title saved successfully'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error saving title: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  FileType _getFileType(String name) {
    final lowercasedName = name.toLowerCase();
    if (lowercasedName.endsWith('.pdf')) return FileType.pdf;
    if (lowercasedName.endsWith('.mp3') ||
        lowercasedName.endsWith('.wav') ||
        lowercasedName.endsWith('.m4a')) return FileType.audio;
    if (lowercasedName.endsWith('.jpg') ||
        lowercasedName.endsWith('.jpeg') ||
        lowercasedName.endsWith('.png') ||
        lowercasedName.endsWith('.webp')) return FileType.image;
    return FileType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditable = _fileType == FileType.pdf ||
        _fileType == FileType.audio ||
        _fileType == FileType.image;

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: isEditable
                        ? TextFormField(
                            controller: _titleController,
                            style: const TextStyle(color: AppTheme.darkGray),
                            decoration: InputDecoration(
                              labelText: _fileType == FileType.pdf
                                  ? 'Document Title'
                                  : _fileType == FileType.audio
                                      ? 'Audio Clip Title'
                                      : 'Image Title',
                              labelStyle: const TextStyle(
                                  color: AppTheme.primaryOrange),
                              filled: true,
                              fillColor: AppTheme.white,
                              border: const OutlineInputBorder(),
                            ),
                          )
                        : Text('File Preview',
                            style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (isEditable) ...[
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveTitle();
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Save Title'),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<String>(
                future: _urlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                        child: Text('Could not load file URL.'));
                  }
                  final url = snapshot.data!;
                  return _buildPreviewWidget(url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewWidget(String url) {
    switch (_fileType) {
      case FileType.image:
        return InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain));
      case FileType.pdf:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf,
                  color: AppTheme.primaryOrange, size: 48),
              const SizedBox(height: 12),
              const Text('PDFs open in a new browser tab.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = FileProxy.build(url, filename: widget.file.title);
                  await launchUrl(uri, webOnlyWindowName: '_blank');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF in new tab'),
              ),
            ],
          ),
        );
      case FileType.audio:
        return AudioPreview(url: url);
      case FileType.unknown:
        return Center(
            child: SelectableText(
                'Preview is not available for this file type.\n\nURL: $url'));
    }
  }
}

class AudioPreview extends StatefulWidget {
  final String url;
  const AudioPreview({super.key, required this.url});

  @override
  State<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<AudioPreview> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setUrl(widget.url);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkGray,
      alignment: Alignment.center,
      child: StreamBuilder<PlayerState>(
        stream: _audioPlayer.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;
          final processingState = playerState?.processingState;
          final playing = playerState?.playing;
          if (processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering) {
            return const CircularProgressIndicator();
          } else if (playing != true) {
            return IconButton(
              icon: const Icon(Icons.play_circle_filled),
              iconSize: 64.0,
              color: AppTheme.primaryOrange,
              onPressed: _audioPlayer.play,
            );
          } else if (processingState != ProcessingState.completed) {
            return IconButton(
              icon: const Icon(Icons.pause_circle_filled),
              iconSize: 64.0,
              color: AppTheme.primaryOrange,
              onPressed: _audioPlayer.pause,
            );
          } else {
            return IconButton(
              icon: const Icon(Icons.replay_circle_filled),
              iconSize: 64.0,
              color: AppTheme.primaryOrange,
              onPressed: () => _audioPlayer.seek(Duration.zero),
            );
          }
        },
      ),
    );
  }
}
