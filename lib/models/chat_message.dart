import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isFromUser;
  final String? sessionId;
  final String userId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isFromUser,
    this.sessionId,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFromUser': isFromUser,
      'sessionId': sessionId,
      'userId': userId,
    };
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFromUser: data['isFromUser'] ?? false,
      sessionId: data['sessionId'],
      userId: data['userId'] ?? '',
    );
  }

  // ✅ START: تمت إضافة هذه الدالة بالكامل
  /// Creates a copy of this ChatMessage but with the given fields replaced with the new values.
  ChatMessage copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    bool? isFromUser,
    String? sessionId,
    String? userId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isFromUser: isFromUser ?? this.isFromUser,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
    );
  }
  // ✅ END: نهاية الدالة المضافة
}


// لم نغير هذا الكلاس
class ChatSession {
  final String id;
  final String userId;
  final String moodId;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.userId,
    required this.moodId,
    required this.createdAt,
    this.lastMessageAt,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'moodId': moodId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
    };
  }

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      moodId: data['moodId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }
}