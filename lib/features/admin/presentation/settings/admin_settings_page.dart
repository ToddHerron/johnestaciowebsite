import 'package:flutter/material.dart';
import 'package:john_estacio_website/features/admin/presentation/settings/settings_repository.dart';
import 'package:john_estacio_website/theme.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _settingsRepo = SettingsRepository();
  bool _isLoading = false;
  late Future<String> _emailFuture;

  @override
  void initState() {
    super.initState();
    _emailFuture = _settingsRepo.getRecipientEmail();
    _emailFuture.then((email) => _emailController.text = email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await _settingsRepo.updateRecipientEmail(_emailController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                  ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _emailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact Form', style: AppTheme.theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Enter the email address where messages from the public contact form should be sent.'),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Recipient Email', border: OutlineInputBorder()),
                        validator: (value) {
                           if (value?.isEmpty ?? true) return 'Please enter an email';
                           if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value!)) return 'Please enter a valid email';
                           return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}