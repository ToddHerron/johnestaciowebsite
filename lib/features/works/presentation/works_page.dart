import 'dart:async';
import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/work_card.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/features/categories/data/categories_repository.dart';
import 'package:john_estacio_website/features/categories/domain/work_category.dart';

class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage> {
  final WorksRepository _worksRepository = WorksRepository();
  final CategoriesRepository _categoriesRepository = CategoriesRepository();

  final TextEditingController _filterController = TextEditingController();

  // Multi-select categories. Empty set means "ALL CATEGORIES" (no category filter)
  final Set<String> _selectedCategories = <String>{};
  String _filterQuery = '';
  // Removed explicit filtering spinner to keep UI snappy during typing

  // We keep a cached copy of all works (ordered from Firestore) and the current filtered result
  List<Work> _allWorksCache = const [];
  List<Work> _filteredWorks = const [];

  // Persist stream instances to avoid resubscribing (and refetching) on every build.
  late final Stream<List<Work>> _worksStream;
  late final Stream<List<WorkCategory>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    // Create the streams once. This prevents Firestore from being re-queried on every keystroke.
    _worksStream = _worksRepository.getWorksStream();
    _categoriesStream = _categoriesRepository.getCategoriesStream(includeInactive: false);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  // Debounce removed: we apply filters immediately on each keystroke.

  List<Work> _applyFilters(List<Work> source) {
    // Public view shows only published, and excludes data integrity issues
    Iterable<Work> filtered = source.where(
      (w) => w.status == WorkStatus.published && !w.hasDataIntegrityIssue,
    );

    // Category filter (no debounce requirement)
    // Category filter (OR logic across selected chips)
    if (_selectedCategories.isNotEmpty) {
      final lowerSel = _selectedCategories.map((e) => e.toLowerCase()).toSet();
      filtered = filtered.where(
        (w) {
          final workCats = w.categories.map((e) => e.toLowerCase()).toSet();
          return workCats.intersection(lowerSel).isNotEmpty;
        },
      );
    }

    // Text filter (debounced while typing) — OPTIMIZED: title only
    final q = _filterQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((w) => w.title.toLowerCase().contains(q));
    }

    // Preserve original order from Firestore (admin-defined)
    return filtered.toList();
  }

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
                  'Works',
                  style: AppTheme.theme.textTheme.headlineLarge?.copyWith(color: AppTheme.primaryOrange),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<Work>>(
                    stream: _worksStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.lightGray)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No works found.', style: TextStyle(color: AppTheme.lightGray)));
                      }

                       // Latest source list ordered by 'order' ascending from Firestore (admin-defined)
                      final allWorks = snapshot.data!;

                       // Update cache and immediate filtered result
                      if (_allWorksCache != allWorks) {
                        _allWorksCache = allWorks;
                         _filteredWorks = _applyFilters(_allWorksCache);
                      }

                      return StreamBuilder<List<WorkCategory>>(
                        stream: _categoriesStream,
                        builder: (context, catSnap) {
                          if (catSnap.hasError) {
                            return Center(child: Text('Error: ${catSnap.error}', style: const TextStyle(color: AppTheme.lightGray)));
                          }
                          final categories = (catSnap.data ?? const <WorkCategory>[])
                              .map((c) => c.name)
                              .toList();
                          return CustomScrollView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Filter bar
                                     TextField(
                                      controller: _filterController,
                                      onChanged: (val) {
                                         setState(() {
                                           _filterQuery = val;
                                           _filteredWorks = _applyFilters(_allWorksCache);
                                         });
                                      },
                                      style: const TextStyle(color: AppTheme.lightGray),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.filter_list, color: AppTheme.lightGray),
                                        hintText: 'Filter works...',
                                        hintStyle: const TextStyle(color: AppTheme.lightGray),
                                        suffixIcon: _filterController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, color: AppTheme.lightGray),
                                                onPressed: () {
                                                   setState(() {
                                                     _filterController.clear();
                                                     _filterQuery = '';
                                                     _filteredWorks = _applyFilters(_allWorksCache);
                                                   });
                                                },
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Category filters using ChoiceChips with wrapping and checkmark for selected
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                          ChoiceChip(
                                            avatar: _selectedCategories.isEmpty
                                                ? const Icon(Icons.check, size: 18, color: AppTheme.black)
                                                : null,
                                            label: const Text('ALL CATEGORIES'),
                                            selected: _selectedCategories.isEmpty,
                                            onSelected: (_) {
                                              setState(() {
                                                _selectedCategories.clear();
                                                _filteredWorks = _applyFilters(_allWorksCache);
                                              });
                                            },
                                            selectedColor: AppTheme.primaryOrange,
                                            labelStyle: TextStyle(
                                              color: _selectedCategories.isEmpty ? AppTheme.black : AppTheme.primaryOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            backgroundColor: AppTheme.black,
                                            side: const BorderSide(color: AppTheme.primaryOrange),
                                          ),
                                        ...categories.map((cat) {
                                          final isSelected = _selectedCategories.contains(cat);
                                          return ChoiceChip(
                                            avatar: isSelected
                                                ? const Icon(Icons.check, size: 18, color: AppTheme.black)
                                                : null,
                                            label: Text(cat.toUpperCase()),
                                            selected: isSelected,
                                            onSelected: (value) {
                                              setState(() {
                                                if (value) {
                                                  _selectedCategories.add(cat);
                                                } else {
                                                  _selectedCategories.remove(cat);
                                                }
                                                _filteredWorks = _applyFilters(_allWorksCache);
                                              });
                                            },
                                            selectedColor: AppTheme.primaryOrange,
                                            labelStyle: TextStyle(
                                              color: isSelected ? AppTheme.black : AppTheme.primaryOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            backgroundColor: AppTheme.black,
                                            side: const BorderSide(color: AppTheme.primaryOrange),
                                          );
                                        }).toList(),
                                    ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                               if (_filteredWorks.isEmpty)
                                 const SliverFillRemaining(
                                   hasScrollBody: false,
                                   child: Center(
                                     child: Text(
                                       'No works match your filters.',
                                       style: TextStyle(color: AppTheme.lightGray),
                                     ),
                                   ),
                                 )
                               else
                                SliverList.separated(
                                  itemCount: _filteredWorks.length,
                                  itemBuilder: (context, index) {
                                     final work = _filteredWorks[index];
                                         return WorkCard(
                                          work: work,
                                          highlightQuery: _filterQuery,
                                          selectedCategories: _selectedCategories,
                                         );
                                  },
                                  separatorBuilder: (_, __) => const SizedBox(height: 0),
                                ),
                            ],
                          );
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