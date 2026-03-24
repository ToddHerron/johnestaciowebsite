import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/categories/data/categories_repository.dart';
import 'package:john_estacio_website/features/categories/domain/work_category.dart';
import 'package:john_estacio_website/theme.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  final CategoriesRepository _repo = CategoriesRepository();
  final TextEditingController _addController = TextEditingController();
  bool _savingOrder = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    try {
      await _repo.addCategory(name);
      if (!mounted) return;
      _addController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category added'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding category: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _renameCategory(WorkCategory cat) async {
    final controller = TextEditingController(text: cat.name);
    final newName = await showDialog<String>(
      context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename Category'),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.darkGray),
            cursorColor: AppTheme.darkGray,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null) return;
    if (newName.isEmpty || newName == cat.name) return;
    try {
      await _repo.renameCategory(cat.id, newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category renamed'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteCategory(WorkCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${cat.name}"? This only removes it from the master list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(cat.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 1,
        title: const Text('Manage Categories', style: TextStyle(color: AppTheme.darkGray)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    style: const TextStyle(color: AppTheme.darkGray),
                    cursorColor: AppTheme.darkGray,
                    decoration: const InputDecoration(
                      labelText: 'New category name',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppTheme.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<WorkCategory>>(
                stream: _repo.getCategoriesStream(includeInactive: true),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = List<WorkCategory>.from(snapshot.data!);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_savingOrder) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: items.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final moving = items.removeAt(oldIndex);
                            items.insert(newIndex, moving);
                            setState(() => _savingOrder = true);
                            try {
                              await _repo.updateOrder(items);
                            } finally {
                              if (mounted) setState(() => _savingOrder = false);
                            }
                          },
                          itemBuilder: (context, index) {
                            final cat = items[index];
                            return Card(
                              key: ValueKey(cat.id),
                              color: AppTheme.lightGray.withAlpha(64),
                              child: ListTile(
                                leading: const Icon(Icons.drag_handle, color: AppTheme.darkGray),
                                title: Text(cat.name, style: const TextStyle(color: AppTheme.darkGray, fontWeight: FontWeight.w600)),
                                subtitle: Text(cat.isActive ? 'Active' : 'Inactive', style: TextStyle(color: cat.isActive ? Colors.green : AppTheme.lightGray)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: cat.isActive,
                                      onChanged: (val) => _repo.setActive(cat.id, val),
                                    ),
                                    IconButton(
                                      tooltip: 'Rename',
                                      icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                                      onPressed: () => _renameCategory(cat),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteCategory(cat),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
