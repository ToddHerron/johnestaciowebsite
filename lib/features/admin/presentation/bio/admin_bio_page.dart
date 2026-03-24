import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:john_estacio_website/core/widgets/rich_text_editor.dart';
import 'package:john_estacio_website/features/about/data/bio_repository.dart';
import 'package:john_estacio_website/features/about/domain/models/bio_model.dart';
import 'package:john_estacio_website/theme.dart';

class AdminBioPage extends StatefulWidget {
  const AdminBioPage({super.key});

  @override
  State<AdminBioPage> createState() => _AdminBioPageState();
}

class _AdminBioPageState extends State<AdminBioPage>
    with SingleTickerProviderStateMixin {
  final BioRepository _bioRepository = BioRepository();
  late Future<BioPageModel> _bioFuture;
  late TabController _tabController;
  final Map<int, QuillController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _bioFuture = _loadBioData();
  }

  Future<BioPageModel> _loadBioData() async {
    final bioData = await _bioRepository.getBioPage();
    _controllers[0] = _initializeController(bioData.bio100Words);
    _controllers[1] = _initializeController(bioData.bio250Words);
    _controllers[2] = _initializeController(bioData.bio450Words);
    _controllers[3] = _initializeController(bioData.bio850Words);
    _controllers[4] = _initializeController(bioData.cvContent);
    return bioData;
  }

  QuillController _initializeController(Map<String, dynamic> delta) {
    try {
      final ops = delta['ops'];
      if (ops is List) {
        final doc = Document.fromJson(ops);
        return QuillController(
            document: doc, selection: const TextSelection.collapsed(offset: 0));
      }
      return QuillController.basic();
    } catch (e) {
      return QuillController.basic();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> updatedData = {
        'bio100Words': {'ops': _controllers[0]!.document.toDelta().toJson()},
        'bio250Words': {'ops': _controllers[1]!.document.toDelta().toJson()},
        'bio450Words': {'ops': _controllers[2]!.document.toDelta().toJson()},
        'bio850Words': {'ops': _controllers[3]!.document.toDelta().toJson()},
        'cvContent': {'ops': _controllers[4]!.document.toDelta().toJson()},
      };
      await _bioRepository.updateBioPage(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bio updated successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating bio: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: FutureBuilder<BioPageModel>(
        future: _bioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
                child: Text('Error loading bio data.',
                    style: TextStyle(color: AppTheme.white)));
          }

          return Column(
            children: [
              AppBar(
                title: const Text('Edit Biography',
                    style: TextStyle(color: AppTheme.darkGray)),
                backgroundColor: AppTheme.white,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                    ),
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '100 Words'),
                    Tab(text: '250 Words'),
                    Tab(text: '450 Words'),
                    Tab(text: '850 Words'),
                    Tab(text: 'Curriculum Vitae'),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TabBarView(
                    controller: _tabController,
                    children: List.generate(5, (index) {
                      final controller = _controllers[index];
                      if (controller == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: AppRichTextEditor(
                              controller: controller,
                              expands: true,
                            ),
                          ),
                        ],
                      );
                    }),
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