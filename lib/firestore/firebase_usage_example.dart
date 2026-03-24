import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_provider.dart';
import 'auth_service.dart';
import 'firestore_data_schema.dart';

/// Example widget showing how to use Firebase services
class FirebaseUsageExample extends StatefulWidget {
  const FirebaseUsageExample({super.key});

  @override
  State<FirebaseUsageExample> createState() => _FirebaseUsageExampleState();
}

class _FirebaseUsageExampleState extends State<FirebaseUsageExample> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Integration Demo'),
        actions: [
          Consumer<AuthStateProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isAuthenticated) {
                return TextButton(
                  onPressed: () => authProvider.signOut(),
                  child: const Text('Sign Out'),
                );
              } else {
                return TextButton(
                  onPressed: () => _showAuthDialog(context),
                  child: const Text('Sign In'),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<FirebaseProvider>(
        builder: (context, firebaseProvider, child) {
          if (firebaseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (firebaseProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${firebaseProvider.error}'),
                  ElevatedButton(
                    onPressed: () {
                      firebaseProvider.clearError();
                      firebaseProvider.refreshData();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auth Status
                _buildAuthStatus(),
                const SizedBox(height: 24),
                
                // Featured Compositions
                _buildFeaturedCompositions(firebaseProvider.featuredCompositions),
                const SizedBox(height: 24),
                
                // Upcoming Events
                _buildUpcomingEvents(firebaseProvider.upcomingEvents),
                const SizedBox(height: 24),
                
                // Bio Section
                _buildBioSection(firebaseProvider.bio),
                const SizedBox(height: 24),
                
                // Contact Form
                _buildContactForm(firebaseProvider),
                const SizedBox(height: 24),
                
                // Admin Actions
                Consumer<AuthStateProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.isAuthenticated) {
                      return _buildAdminActions(firebaseProvider);
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthStatus() {
    return Consumer<AuthStateProvider>(
      builder: (context, authProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Authentication Status', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                if (authProvider.isAuthenticated) ...[
                  Text('✓ Signed in as: ${authProvider.currentUser?.email}'),
                  Text('Display Name: ${authProvider.currentUser?.displayName ?? 'Not set'}'),
                ] else ...[
                  const Text('✗ Not signed in'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturedCompositions(List<Composition> compositions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Featured Compositions', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (compositions.isEmpty) ...[
              const Text('No featured compositions found.'),
            ] else ...[
              ...compositions.map((composition) => ListTile(
                title: Text(composition.title),
                subtitle: Text(composition.description ?? 'No description'),
                trailing: Text(composition.category),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents(List<Event> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Events', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (events.isEmpty) ...[
              const Text('No upcoming events found.'),
            ] else ...[
              ...events.map((event) => ListTile(
                title: Text(event.title),
                subtitle: Text('${event.venue} - ${event.eventDate.toString().split(' ')[0]}'),
                trailing: event.isFeatured ? const Icon(Icons.star) : null,
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection(Bio? bio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bio', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (bio == null) ...[
              const Text('No bio information available.'),
            ] else ...[
              Text(bio.content),
              if (bio.achievements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Achievements:', style: Theme.of(context).textTheme.titleSmall),
                ...bio.achievements.map((achievement) => Text('• $achievement')),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm(FirebaseProvider firebaseProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact Form', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Please enter your name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter your email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 4,
                validator: (value) => value?.isEmpty ?? true ? 'Please enter your message' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _submitContactForm(firebaseProvider),
                child: const Text('Send Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminActions(FirebaseProvider firebaseProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Actions', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => firebaseProvider.refreshData(),
                  child: const Text('Refresh Data'),
                ),
                ElevatedButton(
                  onPressed: () => _initializeSampleData(firebaseProvider),
                  child: const Text('Initialize Sample Data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitContactForm(FirebaseProvider firebaseProvider) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await firebaseProvider.submitContactMessage(
        name: _nameController.text,
        email: _emailController.text,
        subject: 'Website Contact Form',
        message: _messageController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
        _formKey.currentState!.reset();
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _initializeSampleData(FirebaseProvider firebaseProvider) async {
    try {
      await firebaseProvider.initializeSampleData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data initialized successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize sample data: $e')),
        );
      }
    }
  }

  void _showAuthDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer<AuthStateProvider>(
            builder: (context, authProvider, child) {
              return TextButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        final result = await authProvider.signIn(
                          emailController.text,
                          passwordController.text,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          if (!result.isSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message ?? 'Sign in failed')),
                            );
                          }
                        }
                      },
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}