import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../models/journal_entry.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === خدمات المحادثة ===

  // إنشاء جلسة محادثة جديدة
  static Future<String> createChatSession(String moodId) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final session = ChatSession(
        id: '',
        userId: userId,
        moodId: moodId,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('chat_sessions')
          .add(session.toJson());

      return docRef.id;
    } catch (e) {
      print('Error creating chat session: \$e');
      rethrow;
    }
  }

  // إضافة رسالة للمحادثة
  static Future<void> addChatMessage(ChatMessage message) async {
    try {
      await _firestore
          .collection('chat_messages')
          .add(message.toJson());

      if (message.sessionId != null) {
        await _firestore
            .collection('chat_sessions')
            .doc(message.sessionId)
            .update({
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error adding chat message: \$e');
      rethrow;
    }
  }

  // الحصول على رسائل المحادثة
  static Stream<List<ChatMessage>> getChatMessages(String sessionId) {
    return _firestore
        .collection('chat_messages')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  // الحصول على جلسات المحادثة كـ Stream
  static Stream<List<ChatSession>> getUserChatSessions() {
    final userId = AuthService.currentUid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('chat_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatSession.fromFirestore(doc))
            .toList());
  }

  // الحصول على جلسات المحادثة كـ Future
  static Future<List<Map<String, dynamic>>> getUserChatSessionsOnce() async {
  final userId = AuthService.currentUid;
  print('📛 getUserChatSessionsOnce: userId = $userId');

  if (userId == null) return [];

  final querySnapshot = await _firestore
      .collection('chat_sessions')
      .where('userId', isEqualTo: userId)
      .orderBy('lastMessageAt', descending: true)
      .get();

  print('📛 getUserChatSessionsOnce: loaded ${querySnapshot.docs.length} docs');

  return querySnapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return data;
  }).toList();
}

  // حذف جلسة محادثة
  static Future<void> deleteChatSession(String sessionId) async {
    try {
      final messages = await _firestore
          .collection('chat_messages')
          .where('sessionId', isEqualTo: sessionId)
          .get();

      for (final doc in messages.docs) {
        await doc.reference.delete();
      }

      await _firestore
          .collection('chat_sessions')
          .doc(sessionId)
          .delete();
    } catch (e) {
      print('Error deleting chat session: \$e');
      rethrow;
    }
  }






  // === خدمات اليوميات ===

  // إنشاء مدخل يومية جديد
  static Future<String> createJournalEntry(JournalEntry entry) async {
    try {
      final docRef = _firestore
          .collection('journal_entries')
          .doc(entry.id);

      await docRef.set(entry.toJson());
      return docRef.id;
    } catch (e) {
      print('Error creating journal entry: $e');
      rethrow;
    }
  }

  // تحديث مدخل يومية
  static Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      await _firestore
          .collection('journal_entries')
          .doc(entry.id)
          .update(entry.copyWith(updatedAt: DateTime.now()).toJson());
    } catch (e) {
      print('Error updating journal entry: $e');
      rethrow;
    }
  }

  // حذف مدخل يومية
  static Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _firestore
          .collection('journal_entries')
          .doc(entryId)
          .delete();
    } catch (e) {
      print('Error deleting journal entry: $e');
      rethrow;
    }
  }

  // الحصول على مدخلات اليوميات للمستخدم
  static Stream<List<JournalEntry>> getUserJournalEntries() {
    final userId = AuthService.currentUid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('journal_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JournalEntry.fromFirestore(doc))
            .toList());
  }

  // البحث في اليوميات
  static Future<List<JournalEntry>> searchJournalEntries(String query) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final entries = snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();

      return entries.where((entry) {
        final searchLower = query.toLowerCase();
        return entry.title.toLowerCase().contains(searchLower) ||
               entry.content.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      print('Error searching journal entries: $e');
      return [];
    }
  }

  // الحصول على مدخلات اليوميات لتاريخ معين
  static Future<List<JournalEntry>> getJournalEntriesForDate(DateTime date) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return [];

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting journal entries for date: $e');
      return [];
    }
  }

  // === إحصائيات ومعلومات إضافية ===

  // الحصول على عدد المحادثات
  static Future<int> getUserChatSessionsCount() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting chat sessions count: $e');
      return 0;
    }
  }

  // الحصول على عدد اليوميات
  static Future<int> getUserJournalEntriesCount() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return 0;

      final snapshot = await _firestore
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting journal entries count: $e');
      return 0;
    }
  }

  // الحصول على آخر جلسة محادثة
  static Future<ChatSession?> getLastChatSession() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return null;

      final snapshot = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('lastMessageAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ChatSession.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting last chat session: $e');
      return null;
    }
  }

  // تنظيف البيانات القديمة (اختياري)
  static Future<void> cleanupOldData({int daysToKeep = 90}) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final oldSessions = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .where('lastMessageAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in oldSessions.docs) {
        await deleteChatSession(doc.id);
      }

      print('تم تنظيف ${oldSessions.docs.length} محادثة قديمة');
    } catch (e) {
      print('Error cleaning up old data: $e');
    }
  }

  // === خدمات النسخ الاحتياطي ===

  // تصدير بيانات المستخدم
  static Future<Map<String, dynamic>> exportUserData() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

      final chatSessions = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: userId)
          .get();

      final journalEntries = await _firestore
          .collection('journal_entries')
          .where('userId', isEqualTo: userId)
          .get();

      final userData = await AuthService.getUserData(userId);

      return {
        'exportDate': DateTime.now().toIso8601String(),
        'user': userData?.toJson(),
        'chatSessions': chatSessions.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
        'journalEntries': journalEntries.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList(),
      };
    } catch (e) {
      print('Error exporting user data: $e');
      rethrow;
    }
  }
}
