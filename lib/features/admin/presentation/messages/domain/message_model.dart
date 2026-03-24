import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String message;
  final Timestamp timestamp;
  final bool isRead; // New field

  Message({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.message,
    required this.timestamp,
    this.isRead = false, // Default to unread
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false, // Read the new field from Firestore
    );
  }
}