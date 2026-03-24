import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/features/discography/data/discography_repository.dart';
import 'package:john_estacio_website/features/discography/domain/models/discography_model.dart';
import 'package:john_estacio_website/features/discography/presentation/widgets/discography_card.dart';
import 'package:john_estacio_website/theme.dart';

class DiscographyPage extends StatefulWidget {
  const DiscographyPage({super.key});

  @override
  State<DiscographyPage> createState() => _DiscographyPageState();
}

class _DiscographyPageState extends State<DiscographyPage> {
  final DiscographyRepository _discographyRepository = DiscographyRepository();

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discography',
                  style: AppTheme.theme.textTheme.headlineLarge?.copyWith(color: AppTheme.primaryOrange),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<DiscographyItem>>(
                    stream: _discographyRepository.getDiscographyItemsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.lightGray)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No discography items found.', style: TextStyle(color: AppTheme.lightGray)));
                      }

                      final items = snapshot.data!;
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return DiscographyCard(item: item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
