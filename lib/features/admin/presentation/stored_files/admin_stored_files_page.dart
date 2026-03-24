import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/data/stored_files_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/domain/stored_file_model.dart';
import 'package:john_estacio_website/features/admin/presentation/stored_files/file_preview_dialog.dart';
import 'package:john_estacio_website/theme.dart';

class AdminStoredFilesPage extends StatefulWidget {
  const AdminStoredFilesPage({super.key});

  @override
  State<AdminStoredFilesPage> createState() => _AdminStoredFilesPageState();
}

class _AdminStoredFilesPageState extends State<AdminStoredFilesPage> {
  final StoredFilesRepository _repository = StoredFilesRepository();
  late Future<List<StoredFile>> _filesFuture;
  final TextEditingController _searchController = TextEditingController();

  String _searchTerm = '';
  bool _showPdf = true;
  bool _showAudio = true;
  bool _showImage = true;

  @override
  void initState() {
    super.initState();
    _filesFuture = _repository.listFiles();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = _repository.listFiles();
    });
  }

  IconData _getIconForFileName(String name) {
    final lowercasedName = name.toLowerCase();
    if (lowercasedName.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lowercasedName.endsWith('.mp3') || lowercasedName.endsWith('.wav') || lowercasedName.endsWith('.m4a')) return Icons.audiotrack;
    if (lowercasedName.endsWith('.jpg') || lowercasedName.endsWith('.jpeg') || lowercasedName.endsWith('.png') || lowercasedName.endsWith('.webp')) return Icons.image;
    if (lowercasedName.endsWith('.mp4') || lowercasedName.endsWith('.mov')) return Icons.videocam;
    return Icons.insert_drive_file;
  }

  Future<void> _deleteFile(StoredFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete the file "${file.ref.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _repository.deleteFile(file.ref);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully'), backgroundColor: Colors.green),
        );
        _refreshFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPreviewDialog(StoredFile file) async {
    final titleWasChanged = await showDialog<bool>(
      context: context,
      builder: (context) => FilePreviewDialog(file: file, onTitleSaved: _refreshFiles),
    );

    if (titleWasChanged == true && mounted) {
      _refreshFiles();
    }
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text('Filter:', style: TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          SizedBox(
            width: 150,
            child: CheckboxListTile(
              title: const Text('PDF', style: TextStyle(color: AppTheme.darkGray)),
              value: _showPdf,
              onChanged: (bool? value) {
                setState(() {
                  _showPdf = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              side: const BorderSide(color: AppTheme.darkGray),
            ),
          ),
          SizedBox(
            width: 150,
            child: CheckboxListTile(
              title: const Text('Audio', style: TextStyle(color: AppTheme.darkGray)),
              value: _showAudio,
              onChanged: (bool? value) {
                setState(() {
                  _showAudio = value ?? true;
                });
              },
               controlAffinity: ListTileControlAffinity.leading,
               contentPadding: EdgeInsets.zero,
               side: const BorderSide(color: AppTheme.darkGray),
            ),
          ),
          SizedBox(
            width: 150,
            child: CheckboxListTile(
              title: const Text('Image', style: TextStyle(color: AppTheme.darkGray)),
              value: _showImage,
              onChanged: (bool? value) {
                setState(() {
                  _showImage = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              side: const BorderSide(color: AppTheme.darkGray),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 250,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.darkGray),
              decoration: InputDecoration(
                labelText: 'Search by Title',
                labelStyle: const TextStyle(color: AppTheme.darkGray),
                prefixIcon: const Icon(Icons.search, color: AppTheme.darkGray),
                isDense: true,
                filled: true,
                fillColor: AppTheme.white,
                border: const OutlineInputBorder(),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.darkGray),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Stored Files', style: TextStyle(color: AppTheme.darkGray)),
        backgroundColor: AppTheme.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildFilterControls(),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<StoredFile>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading files: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No files found in storage.'));
                }

                final allFiles = snapshot.data!;
                
                final filteredFiles = allFiles.where((file) {
                  final name = file.ref.name.toLowerCase();
                  final passesTypeFilter = (_showPdf && name.endsWith('.pdf')) || 
                                           (_showAudio && (name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.m4a'))) ||
                                           (_showImage && (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp')));
                  
                  final passesSearchFilter = _searchTerm.isEmpty || 
                                             file.title.toLowerCase().contains(_searchTerm.toLowerCase());

                  return passesTypeFilter && passesSearchFilter;
                }).toList();

                filteredFiles.sort((a, b) {
                  if (a.title.isEmpty && b.title.isNotEmpty) return 1;
                  if (a.title.isNotEmpty && b.title.isEmpty) return -1;
                  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                });

                if (filteredFiles.isEmpty) {
                  return const Center(child: Text('No files match the current filter.'));
                }
                
                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Type')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Filename')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredFiles.map((file) {
                      return DataRow(cells: [
                        DataCell(Icon(_getIconForFileName(file.ref.name), color: AppTheme.darkGray)),
                        DataCell(
                          Text(file.title.isNotEmpty ? file.title : '---', style: const TextStyle(color: AppTheme.darkGray)),
                        ),
                        DataCell(Text(file.ref.name, style: const TextStyle(color: AppTheme.darkGray))),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                              tooltip: 'Preview & Edit Title',
                              onPressed: () => _showPreviewDialog(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete File',
                              onPressed: () => _deleteFile(file),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}