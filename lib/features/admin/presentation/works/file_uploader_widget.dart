import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:john_estacio_website/features/admin/presentation/works/data/file_storage_service.dart';
import 'package:john_estacio_website/theme.dart';

class FileUploaderWidget extends StatefulWidget {
  final String? initialUrl;
  final ValueChanged<String> onUrlChanged;
  final String fileTypeDescription;

  // New: optionally hide the internal read-only URL field
  final bool showUrlField;

  // New: restrict selectable file types
  final List<String>? allowedExtensions; // e.g. ['mp3', 'wav', 'm4a']
  final List<String>? allowedMime; // e.g. ['audio/mpeg', 'audio/wav']

  const FileUploaderWidget({
    super.key,
    this.initialUrl,
    required this.onUrlChanged,
    required this.fileTypeDescription,
    this.showUrlField = true,
    this.allowedExtensions,
    this.allowedMime,
  });

  @override
  State<FileUploaderWidget> createState() => _FileUploaderWidgetState();
}

class _FileUploaderWidgetState extends State<FileUploaderWidget> {
  final FileStorageService _storageService = FileStorageService();
  late final TextEditingController _urlController;
  DropzoneViewController? _dropzoneController;

  UploadTask? _uploadTask;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: widget.allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      _upload(fileBytes, fileName);
    }
  }

  void _upload(Uint8List fileBytes, String fileName) {
    // Directly get the UploadTask from the service
    final uploadTask = _storageService.uploadFile(fileBytes, fileName);

    // Set the task in the state to show the progress bar
    setState(() {
      _uploadTask = uploadTask;
    });

    // Listen to the stream of events from the UploadTask
    _uploadTask!.snapshotEvents.listen((snapshot) {
      if (snapshot.state == TaskState.success) {
        // When complete, get the URL and update the state
        _storageService.getDownloadUrl(snapshot).then((url) {
          if (mounted) {
            _urlController.text = url;
            widget.onUrlChanged(url);
            setState(() {
              _uploadTask = null; // Hide progress bar
            });
          }
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _uploadTask = null; // Hide progress bar on error
        });
      }
      // You could add a snackbar here to show the error
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              // DropzoneView is only available on web
              if (kIsWeb)
                DropzoneView(
                  onCreated: (controller) => _dropzoneController = controller,
                  mime: widget.allowedMime, // restrict accepted mime on web
                  onDropFile: (file) async {
                    if (_dropzoneController != null) {
                      final bytes = await _dropzoneController!.getFileData(file);
                      final fileName = await _dropzoneController!.getFilename(file);
                      _upload(bytes, fileName);
                    }
                  },
                  onHover: () => setState(() => _isHovering = true),
                  onLeave: () => setState(() => _isHovering = false),
                ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isHovering ? AppTheme.primaryOrange : AppTheme.lightGray,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.white,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 40, color: AppTheme.darkGray),
                      const SizedBox(height: 8),
                      Text('Drag & Drop ${widget.fileTypeDescription}', style: const TextStyle(color: AppTheme.darkGray)),
                      const SizedBox(height: 8),
                      const Text('OR', style: TextStyle(color: AppTheme.darkGray)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.darkGray,
                          side: const BorderSide(color: AppTheme.lightGray),
                          backgroundColor: AppTheme.white,
                        ),
                        onPressed: _pickAndUploadFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Choose a File'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_uploadTask != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: StreamBuilder<TaskSnapshot>(
              stream: _uploadTask!.snapshotEvents,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final progress = snapshot.data!.bytesTransferred / snapshot.data!.totalBytes;
                  return LinearProgressIndicator(value: progress);
                }
                return const LinearProgressIndicator();
              },
            ),
          ),
        if (widget.showUrlField) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            readOnly: true,
            style: const TextStyle(color: AppTheme.darkGray),
            decoration: const InputDecoration(
              labelText: 'Uploaded File URL',
              labelStyle: TextStyle(color: AppTheme.darkGray),
              filled: true,
              fillColor: AppTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                borderSide: BorderSide(color: AppTheme.lightGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                borderSide: BorderSide(color: AppTheme.lightGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
              ),
            ),
          ),
        ],
      ],
    );
  }
}