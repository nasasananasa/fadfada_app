import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isFromUser;
  final String? sessionId;

  ChatMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isFromUser,
    this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFromUser': isFromUser,
      'sessionId': sessionId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFromUser: json['isFromUser'] ?? false,
      sessionId: json['sessionId'],
    );
  }

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage.fromJson({
      'id': doc.id,
      ...data,
    });
  }
}

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

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      moodId: json['moodId'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (json['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  ChatSession copyWith({
    String? id,
    String? userId,
    String? moodId,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moodId: moodId ?? this.moodId,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messages: messages ?? this.messages,
    );
  }
}
