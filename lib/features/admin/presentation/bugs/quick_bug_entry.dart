import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/data/bugs_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/bugs/domain/bug_report_model.dart';
import 'package:john_estacio_website/theme.dart';

class QuickBugDialogResult {
  final String title;
  final String body;
  final bool urgent;
  final BugStatus status;
  final BugKind kind;
  QuickBugDialogResult(this.title, this.body, this.urgent, this.status, this.kind);
}

class QuickBugEditDialog extends StatefulWidget {
  const QuickBugEditDialog({super.key});

  @override
  State<QuickBugEditDialog> createState() => _QuickBugEditDialogState();
}

class _QuickBugEditDialogState extends State<QuickBugEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _urgent = false;
  BugStatus _status = BugStatus.newReport;
  BugKind _kind = BugKind.bug;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bug or Feature', style: TextStyle(color: AppTheme.darkGray)),
      backgroundColor: AppTheme.white,
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  filled: true,
                  fillColor: AppTheme.white,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.lightGray),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  labelStyle: TextStyle(color: AppTheme.primaryOrange),
                ),
                style: const TextStyle(color: AppTheme.darkGray),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  filled: true,
                  fillColor: AppTheme.white,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.lightGray),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  labelStyle: TextStyle(color: AppTheme.primaryOrange),
                ),
                style: const TextStyle(color: AppTheme.darkGray),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<BugStatus>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        filled: true,
                        fillColor: AppTheme.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelStyle: TextStyle(color: AppTheme.primaryOrange),
                      ),
                      items: const [
                        DropdownMenuItem(value: BugStatus.newReport, child: Text('New')),
                        DropdownMenuItem(value: BugStatus.beingWorkedOn, child: Text('Being worked on')),
                        DropdownMenuItem(value: BugStatus.deferred, child: Text('Deferred')),
                        DropdownMenuItem(value: BugStatus.closed, child: Text('Closed')),
                      ],
                      onChanged: (val) => setState(() => _status = val ?? BugStatus.newReport),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<BugKind>(
                      value: _kind,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        filled: true,
                        fillColor: AppTheme.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        labelStyle: TextStyle(color: AppTheme.primaryOrange),
                      ),
                      items: const [
                        DropdownMenuItem(value: BugKind.bug, child: Text('Bug')),
                        DropdownMenuItem(value: BugKind.feature, child: Text('Feature')),
                      ],
                      onChanged: (val) => setState(() => _kind = val ?? BugKind.bug),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: CheckboxListTile(
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v ?? false),
                  title: const Text('Urgent', style: TextStyle(color: AppTheme.darkGray)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  checkboxShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                  side: const BorderSide(color: AppTheme.lightGray, width: 2),
                  checkColor: AppTheme.black,
                  fillColor: WidgetStateProperty.resolveWith<Color?>((states) => AppTheme.white),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              QuickBugDialogResult(
                _titleController.text.trim(),
                _bodyController.text.trim(),
                _urgent,
                _status,
                _kind,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Future<void> showQuickAddBugDialog(BuildContext context) async {
  final result = await showDialog<QuickBugDialogResult>(
    context: context,
    builder: (context) => const QuickBugEditDialog(),
  );
  if (result == null) return;
  final repo = BugsRepository();
  try {
    await repo.addBug(
      title: result.title,
      body: result.body,
      urgent: result.urgent,
      status: result.status,
      kind: result.kind,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug added'), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add bug: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
