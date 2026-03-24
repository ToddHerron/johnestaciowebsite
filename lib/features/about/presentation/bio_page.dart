import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/core/widgets/quill_viewer.dart';
import 'package:john_estacio_website/features/about/data/bio_repository.dart';
import 'package:john_estacio_website/features/about/domain/models/bio_model.dart';
import 'package:john_estacio_website/theme.dart';

class BioPage extends StatefulWidget {
  const BioPage({super.key});

  @override
  State<BioPage> createState() => _BioPageState();
}

/// Centers and constrains bio text content to improve readability on tablet/desktop
class _CenteredBioScroll extends StatelessWidget {
  final Widget child;

  const _CenteredBioScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BioPageState extends State<BioPage> with SingleTickerProviderStateMixin {
  final BioRepository _bioRepository = BioRepository();
  late Future<BioPageModel> _bioFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _bioFuture = _bioRepository.getBioPage();
    // Default to the "450 Words" tab (index 2)
    _tabController = TabController(length: 5, vsync: this, initialIndex: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      child: FutureBuilder<BioPageModel>(
        future: _bioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText('Error: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Bio content not found.'));
          }

          final bioData = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryOrange,
                  unselectedLabelColor: AppTheme.lightGray,
                  indicatorColor: AppTheme.primaryOrange,
                  tabs: const [
                    Tab(text: '100 Words'),
                    Tab(text: '250 Words'),
                    Tab(text: '450 Words'),
                    Tab(text: '850 Words'),
                    Tab(text: 'Curriculum Vitae'),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CenteredBioScroll(child: QuillViewer(deltaJson: bioData.bio100Words)),
                      _CenteredBioScroll(child: QuillViewer(deltaJson: bioData.bio250Words)),
                      _CenteredBioScroll(child: QuillViewer(deltaJson: bioData.bio450Words)),
                      _CenteredBioScroll(child: QuillViewer(deltaJson: bioData.bio850Words)),
                      _CenteredBioScroll(child: QuillViewer(deltaJson: bioData.cvContent)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}