import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/features/admin/presentation/messages/domain/message_model.dart';

class MessagesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Message>> getMessagesStream() {
    return _firestore
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // New method to update the read status
  Future<void> updateMessageReadStatus(String messageId, bool isRead) {
    return _firestore.collection('messages').doc(messageId).update({'isRead': isRead});
  }

  Future<void> deleteMessage(String messageId) {
    return _firestore.collection('messages').doc(messageId).delete();
  }
}