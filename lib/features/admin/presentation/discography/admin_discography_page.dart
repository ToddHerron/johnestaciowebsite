import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/discography/edit_discography_dialog.dart';
import 'package:john_estacio_website/features/discography/data/discography_repository.dart';
import 'package:john_estacio_website/features/discography/domain/models/discography_model.dart';
import 'package:john_estacio_website/theme.dart';

class AdminDiscographyPage extends StatefulWidget {
  const AdminDiscographyPage({super.key});

  @override
  State<AdminDiscographyPage> createState() => _AdminDiscographyPageState();
}

class _AdminDiscographyPageState extends State<AdminDiscographyPage> {
  final DiscographyRepository _discographyRepository = DiscographyRepository();

  void _showEditDialog({DiscographyItem? item}) async {
    final result = await showDialog<DiscographyItem>(
      context: context,
      builder: (context) => EditDiscographyDialog(item: item),
    );

    if (result != null) {
      try {
        if (item == null) {
          await _discographyRepository.addDiscographyItem(result);
        } else {
          await _discographyRepository.updateDiscographyItem(result);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item saved successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving item: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(DiscographyItem item) async {
     final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm ?? false) {
       try {
        await _discographyRepository.deleteDiscographyItem(item.id);
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex, List<DiscographyItem> items) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final DiscographyItem item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    
    _discographyRepository.updateDiscographyOrder(items).catchError((error) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving new order: $error'), backgroundColor: Colors.red),
        );
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Manage Discography',
          style: TextStyle(color: AppTheme.darkGray),
        ),
        backgroundColor: AppTheme.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Item'),
            ),
          )
        ],
      ),
      body: StreamBuilder<List<DiscographyItem>>(
        stream: _discographyRepository.getDiscographyItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No discography items found.'));
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return Material(
                color: AppTheme.white,
                elevation: 4.0,
                child: child,
              );
            },
            itemCount: items.length,
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, items),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                key: ValueKey(item.id),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: AppTheme.darkGray),
                ),
                title: Text(item.title, style: const TextStyle(color: AppTheme.darkGray)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.darkGray),
                      onPressed: () => _showEditDialog(item: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteItem(item),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}