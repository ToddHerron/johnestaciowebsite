import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/works/data/source_data_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/works/data/work_mapper.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';

class DataMappingDialog extends StatefulWidget {
  final String currentWorkTitle;
  const DataMappingDialog({super.key, required this.currentWorkTitle});

  @override
  State<DataMappingDialog> createState() => _DataMappingDialogState();
}

class _DataMappingDialogState extends State<DataMappingDialog> {
  final SourceDataRepository _sourceRepository = SourceDataRepository();
  bool _isLoading = true;
  String _sourceDataJson = 'No matching work found.';
  String _mappedDataJson = 'Mapping not yet performed.';
  Work? _mappedWork;

  @override
  void initState() {
    super.initState();
    _fetchAndFindWork();
  }

  dynamic _jsonConverter(dynamic item) {
    if (item is Timestamp) {
      // Corrected typo from toIso8101String to toIso8601String
      return item.toDate().toIso8601String();
    }
    return item;
  }

  Future<void> _fetchAndFindWork() async {
    setState(() => _isLoading = true);
    try {
      final sourceData = await _sourceRepository.getSourceWebsiteData();
      final worksList = sourceData['contentWorks'] as List<dynamic>? ?? [];

      final foundIndex = worksList.indexWhere(
        (work) => work['title'] == widget.currentWorkTitle,
      );

      if (foundIndex != -1) {
        final foundWork = worksList[foundIndex];
        final jsonEncoder = JsonEncoder.withIndent('  ', _jsonConverter);
        _sourceDataJson = jsonEncoder.convert(foundWork);
        
        _mappedWork = WorkMapper.fromSourceJson(foundWork as Map<String, dynamic>);
        _mappedDataJson = jsonEncoder.convert(_mappedWork!.toJson());

      } else {
        String titleAtIndex2 = 'Not available (list has less than 3 items).';
        if (worksList.length > 2) {
          titleAtIndex2 = worksList[2]['title']?.toString() ?? '[No Title Field]';
        }

        _sourceDataJson = '''
No matching work found.

Debugging Info:
-----------------
Total items in source list: ${worksList.length}

Attempting to match this title:
"${widget.currentWorkTitle}"

Title of item at index 2 in source list:
"$titleAtIndex2"
''';
      }

    } catch (e) {
      _sourceDataJson = 'An error occurred while fetching data:\n\n$e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Data Mapping', style: Theme.of(context).textTheme.headlineSmall),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(_mappedWork);
                        },
                        child: const Text('Keep Mapping'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Source Data (userWebsites)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SelectableText(_sourceDataJson, style: const TextStyle(fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mapped Data (Current Schema)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          const SizedBox(height: 8),
                           _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SelectableText(_mappedDataJson, style: const TextStyle(fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}