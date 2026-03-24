import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/features/admin/presentation/messages/data/messages_repository.dart';
import 'package:john_estacio_website/features/admin/presentation/messages/domain/message_model.dart';
import 'package:john_estacio_website/theme.dart';

class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  final MessagesRepository _messagesRepository = MessagesRepository();
  bool _hideSystemMessages = false;

  String _extractSubject(String full) {
    if (full.trim().isEmpty) return 'Message';
    final firstLine = full.trimLeft().split('\n').first.trim();
    return firstLine.isEmpty ? 'Message' : firstLine;
  }

  String _extractBodyPreview(String full) {
    final parts = full.split('\n');
    String body;
    if (parts.length <= 1) {
      body = full;
    } else {
      body = parts.sublist(1).join('\n');
    }
    body = body.trim();
    const maxChars = 180;
    if (body.length > maxChars) {
      return body.substring(0, maxChars).trimRight() + '…';
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text(
          'Contact Messages',
          style: TextStyle(color: AppTheme.darkGray),
        ),
        backgroundColor: AppTheme.white,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _hideSystemMessages,
                  onChanged: (value) => setState(() => _hideSystemMessages = value ?? false),
                  activeColor: AppTheme.primaryOrange,
                  side: const BorderSide(width: 1, color: AppTheme.primaryOrange),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    return states.contains(MaterialState.selected)
                        ? AppTheme.primaryOrange
                        : Colors.transparent;
                  }),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hide System Messages',
                  style: TextStyle(color: AppTheme.darkGray),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Message>>(
        stream: _messagesRepository.getMessagesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No messages found.'));
          }

          final messages = snapshot.data!;
          final visibleMessages = _hideSystemMessages
              ? messages
                  .where((m) => (m.email).toLowerCase() != 'system@internal')
                  .toList()
              : messages;

          if (visibleMessages.isEmpty) {
            return const Center(child: Text('No messages match the current filter.'));
          }
          return ListView.separated(
            itemCount: visibleMessages.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E5E5)),
            itemBuilder: (context, index) {
              final message = visibleMessages[index];
              final subject = _extractSubject(message.message);
              final preview = _extractBodyPreview(message.message);

              return Material(
                color: AppTheme.white,
                child: InkWell(
                  onTap: () => _showMessageDialog(context, message),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        if (isNarrow) {
                          // Fallback to stacked layout on narrow screens
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${message.firstName} ${message.lastName}',
                                      style: TextStyle(
                                        color: AppTheme.darkGray,
                                        fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    DateFormat('MMM d, yyyy, h:mm a').format(message.timestamp.toDate()),
                                    style: const TextStyle(color: AppTheme.darkGray),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      message.isRead
                                          ? Icons.mark_email_unread_outlined
                                          : Icons.mark_email_read_outlined,
                                      color: AppTheme.darkGray,
                                    ),
                                    tooltip: message.isRead ? 'Mark as Unread' : 'Mark as Read',
                                    onPressed: () => _messagesRepository
                                        .updateMessageReadStatus(message.id, !message.isRead),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: 'Delete Message',
                                    onPressed: () => _confirmDelete(context, message.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message.email,
                                style: const TextStyle(color: AppTheme.darkGray),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: AppTheme.darkGray,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (preview.isNotEmpty)
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.darkGray),
                                ),
                            ],
                          );
                        }

                        // Wide layout: From info on the left, Subject/Body on the right
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // From Information (fixed width)
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${message.firstName} ${message.lastName}',
                                    style: TextStyle(
                                      color: AppTheme.darkGray,
                                      fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    message.email,
                                    style: const TextStyle(color: AppTheme.darkGray),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Subject + Body column (expands)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: const TextStyle(
                                      color: AppTheme.darkGray,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (preview.isNotEmpty)
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.darkGray),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Trailing actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('MMM d, yyyy, h:mm a').format(message.timestamp.toDate()),
                                  style: const TextStyle(color: AppTheme.darkGray),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(
                                    message.isRead
                                        ? Icons.mark_email_unread_outlined
                                        : Icons.mark_email_read_outlined,
                                    color: AppTheme.darkGray,
                                  ),
                                  tooltip: message.isRead ? 'Mark as Unread' : 'Mark as Read',
                                  onPressed: () => _messagesRepository
                                      .updateMessageReadStatus(message.id, !message.isRead),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  tooltip: 'Delete Message',
                                  onPressed: () => _confirmDelete(context, message.id),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showMessageDialog(BuildContext context, Message message) {
    // Automatically mark the message as read when it's opened
    if (!message.isRead) {
      _messagesRepository.updateMessageReadStatus(message.id, true);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: Text(
            'Message from ${message.firstName} ${message.lastName}',
            style: const TextStyle(color: AppTheme.darkGray),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'From: ${message.firstName} ${message.lastName} - ${message.email}',
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
                const SizedBox(height: 16),
                Text(
                  message.message,
                  style: const TextStyle(color: AppTheme.darkGray),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                await _messagesRepository.deleteMessage(messageId);
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}