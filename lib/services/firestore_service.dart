import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import 'dart:io'; // لاستخدام File
import 'package:path_provider/path_provider.dart'; // للحصول على مسار التخزين المؤقت
import 'dart:convert'; // لتحويل البيانات إلى JSON

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- دوال إدارة اليوميات (Journal Entries) ---

  static Stream<List<JournalEntry>> getUserJournalEntries() {
    final userId = AuthService.currentUid;
    if (userId == null) {
      print('Error: User not logged in for journal entries.');
      return Stream.value([]);
    }
    return _db
        .collection('journal_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JournalEntry.fromFirestore(doc))
            .toList());
  }

  static Future<void> createJournalEntry(JournalEntry entry) async {
    try {
      await _db.collection('journal_entries').doc(entry.id).set(entry.toJson());
    } catch (e) {
      print('Error creating journal entry: $e');
      rethrow;
    }
  }

  static Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      await _db.collection('journal_entries').doc(entry.id).update(entry.toJson());
    } catch (e) {
      print('Error updating journal entry: $e');
      rethrow;
    }
  }

  static Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _db.collection('journal_entries').doc(entryId).delete();
    } catch (e) {
      print('Error deleting journal entry: $e');
      rethrow;
    }
  }

  // --- دوال إدارة جلسات الدردشة (Chat Sessions) ---

  static Future<String?> createChatSession(String moodId) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        print('Error: User not logged in for chat session.');
        return null;
      }
      final newSessionRef = await _db.collection('chat_sessions').add({
        'userId': userId,
        'moodId': moodId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      return newSessionRef.id;
    } catch (e) {
      print('Error creating chat session: $e');
      return null;
    }
  }

  static Future<void> addChatMessage(ChatMessage message) async {
    try {
      await _db.collection('chat_messages').doc(message.id).set(message.toJson());
      if (message.sessionId != null) {
        await _db.collection('chat_sessions').doc(message.sessionId).update({
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error adding chat message: $e');
      rethrow;
    }
  }

  static Stream<List<ChatMessage>> getChatMessages(String sessionId) {
    return _db
        .collection('chat_messages')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  static Future<List<Map<String, dynamic>>> getUserChatSessionsOnce() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        print('Error: User not logged in for chat sessions.');
        return [];
      }
      final snapshot = await _db
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error fetching user chat sessions: $e');
      return [];
    }
  }

  static Future<void> deleteChatSession(String sessionId) async {
    try {
      final messagesSnapshot = await _db
          .collection('chat_messages')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      await _db.collection('chat_sessions').doc(sessionId).delete();
    } catch (e) {
      print('Error deleting chat session: $e');
      rethrow;
    }
  }

  static Future<void> updateChatSessionLastMessageAt(String sessionId, DateTime timestamp) async {
    try {
      await _db.collection('chat_sessions').doc(sessionId).update({
        'lastMessageAt': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      print('Error updating chat session last message at: $e');
      rethrow;
    }
  }

  // --- دوال جديدة للتعامل مع البيانات في SettingsScreen ---

  // دالة لتصدير بيانات المستخدم
  static Future<String> exportUserData() async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    try {
      // جمع بيانات اليوميات
      final journalSnapshot = await _db
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      final journalData = journalSnapshot.docs.map((doc) => doc.data()).toList();

      // جمع بيانات جلسات الدردشة
      final chatSessionsSnapshot = await _db
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      final chatSessionIds = chatSessionsSnapshot.docs.map((doc) => doc.id).toList();

      final List<Map<String, dynamic>> chatSessionsData = [];
      for (var sessionDoc in chatSessionsSnapshot.docs) {
        final sessionId = sessionDoc.id;
        final messagesSnapshot = await _db
            .collection('chat_messages')
            .where('sessionId', isEqualTo: sessionId)
            .orderBy('timestamp', descending: false)
            .get();
        final messagesData = messagesSnapshot.docs.map((doc) => doc.data()).toList();
        
        final sessionMap = sessionDoc.data();
        sessionMap['messages'] = messagesData; // إضافة الرسائل ضمن بيانات الجلسة
        chatSessionsData.add(sessionMap);
      }

      final userData = {
        'userId': userId,
        'journal_entries': journalData,
        'chat_sessions': chatSessionsData,
        'export_date': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(userData);
      
      // حفظ الملف في مجلد التنزيلات المؤقتة
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/user_data_${userId}.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      return filePath; // إرجاع مسار الملف الذي تم إنشاؤه
    } catch (e) {
      print('Error exporting user data: $e');
      rethrow;
    }
  }

  // دالة لتنظيف البيانات القديمة (مثال: حذف خواطر ورسائل أقدم من سنة)
  static Future<void> cleanupOldData() async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    try {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));

      // حذف خواطر أقدم من سنة
      final oldJournalEntries = await _db
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isLessThan: oneYearAgo)
          .get();
      for (var doc in oldJournalEntries.docs) {
        await doc.reference.delete();
      }
      print('Deleted ${oldJournalEntries.docs.length} old journal entries.');

      // حذف جلسات الدردشة ورسائلها المرتبطة أقدم من سنة
      final oldChatSessions = await _db
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isLessThan: oneYearAgo)
          .get();
      
      for (var sessionDoc in oldChatSessions.docs) {
        final sessionId = sessionDoc.id;
        // حذف الرسائل المرتبطة أولاً
        final oldChatMessages = await _db
            .collection('chat_messages')
            .where('sessionId', isEqualTo: sessionId)
            .get();
        for (var msgDoc in oldChatMessages.docs) {
          await msgDoc.reference.delete();
        }
        await sessionDoc.reference.delete(); // حذف الجلسة نفسها
      }
      print('Deleted ${oldChatSessions.docs.length} old chat sessions and their messages.');

    } catch (e) {
      print('Error cleaning up old data: $e');
      rethrow;
    }
  }
}