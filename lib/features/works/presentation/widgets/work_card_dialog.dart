import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/work_card.dart';
import 'package:john_estacio_website/theme.dart';

class WorkCardDialog extends StatelessWidget {
  const WorkCardDialog({super.key, required this.workTitle});

  final String workTitle;

  Future<Work?> _loadWork() async {
    final repo = WorksRepository();
    try {
      return await repo.getWorkByTitle(workTitle);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: AppTheme.black,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: FutureBuilder<Work?>(
          future: _loadWork(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final work = snapshot.data;
            if (work == null) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Work not found', style: AppTheme.theme.textTheme.titleLarge?.copyWith(color: AppTheme.primaryOrange)),
                    const SizedBox(height: 8),
                    Text('Could not find a work titled "$workTitle".', style: const TextStyle(color: AppTheme.lightGray)),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CLOSE', style: TextStyle(color: AppTheme.primaryOrange)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button row
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.lightGray),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  WorkCard(work: work),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
