import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String fromAdminId;
  final String subject;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.messageId,
    required this.fromAdminId,
    required this.subject,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      messageId:   doc.id,
      fromAdminId: d['fromAdminId'] ?? '',
      subject:     d['subject']     ?? '',
      body:        d['body']        ?? '',
      isRead:      d['isRead']      ?? false,
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromAdminId': fromAdminId,
    'subject':     subject,
    'body':        body,
    'isRead':      isRead,
    'createdAt':   Timestamp.fromDate(createdAt),
  };
}
