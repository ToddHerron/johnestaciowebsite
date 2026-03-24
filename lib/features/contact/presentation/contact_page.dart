import 'package:flutter/material.dart';
import 'package:john_estacio_website/core/widgets/public_page_scaffold.dart';
import 'package:john_estacio_website/features/contact/data/contact_repository.dart';
import 'package:john_estacio_website/theme.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  // Honeypot (hidden) field to trap basic bots
  final _hpController = TextEditingController();

  final _contactRepository = ContactRepository();
  bool _isLoading = false;
  late final DateTime _openedAt;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final elapsedMs = DateTime.now().difference(_openedAt).inMilliseconds;
        await _contactRepository.sendMessage(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: _emailController.text,
          message: _messageController.text,
          honeypot: _hpController.text,
          elapsedMs: elapsedMs,
        );

        _formKey.currentState?.reset();
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _messageController.clear();
         _hpController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you! Your message has been sent.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sorry, an error occurred. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
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
    return PublicPageScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get In Touch',
                    style: AppTheme.theme.textTheme.displaySmall?.copyWith(color: AppTheme.primaryOrange),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Eager to explore a collaboration or have a question? I'd love to hear from you. Please fill out the form below and I'll get back to you as soon as possible.",
                    style: AppTheme.theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    validator: (value) => (value?.isEmpty ?? true) ? 'Please enter your first name' : null,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                     validator: (value) => (value?.isEmpty ?? true) ? 'Please enter your last name' : null,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    keyboardType: TextInputType.emailAddress,
                     validator: (value) {
                      if (value?.isEmpty ?? true) return 'Please enter your email';
                      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value!)) return 'Please enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                    maxLines: 5,
                     validator: (value) => (value?.isEmpty ?? true) ? 'Please enter a message' : null,
                  ),
                  // Honeypot input (hidden). Bots tend to fill generic fields like "website".
                  Offstage(
                    offstage: true,
                    child: TextFormField(
                      controller: _hpController,
                      decoration: const InputDecoration(labelText: 'Website'),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        textStyle: AppTheme.theme.textTheme.labelLarge,
                      ),
                      child: const Text('SEND MESSAGE'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}