// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/assessment_request.dart';
import '../models/journal_entry.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../models/clarification_card_model.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- دوال إدارة اليوميات (Journal Entries) ---

  static Stream<List<JournalEntry>> getUserJournalEntries() {
    final userId = AuthService.currentUid;
    if (userId == null) {
      debugPrint('Error: User not logged in for journal entries.');
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
      debugPrint('Error creating journal entry: $e');
      rethrow;
    }
  }

  static Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      await _db.collection('journal_entries').doc(entry.id).update(entry.toJson());
    } catch (e) {
      debugPrint('Error updating journal entry: $e');
      rethrow;
    }
  }

  static Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _db.collection('journal_entries').doc(entryId).delete();
    } catch (e) {
      debugPrint('Error deleting journal entry: $e');
      rethrow;
    }
  }

  // --- دوال إدارة جلسات الدردشة (Chat Sessions) ---

  static Future<String?> createChatSession() async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        debugPrint('Error: User not logged in for chat session.');
        return null;
      }
      final newSessionRef = await _db.collection('chat_sessions').add({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'title': null,
      });
      return newSessionRef.id;
    } catch (e) {
      debugPrint('Error creating chat session: $e');
      return null;
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> getChatSession(String sessionId) async {
    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        debugPrint('Error: User not logged in to fetch chat session.');
        return null;
      }
      final docSnapshot = await _db.collection('chat_sessions').doc(sessionId).get();
      if (docSnapshot.exists && docSnapshot.data()?['userId'] == userId) {
        return docSnapshot;
      } else {
        debugPrint('Chat session not found or access denied for ID: $sessionId');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting chat session: $e');
      rethrow;
    }
  }

  static Future<void> addChatMessage(ChatMessage message) async {
    try {
      await _db.collection('chat_messages').doc(message.id).set(message.toJson());
      
      if (message.sessionId != null) {
        final sessionRef = _db.collection('chat_sessions').doc(message.sessionId!);
        final snippet = message.content.length > 50 
            ? '${message.content.substring(0, 50)}...' 
            : message.content;

        await sessionRef.update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSnippet': snippet,
        });
      }
    } catch (e) {
      debugPrint('Error adding chat message: $e');
      rethrow;
    }
  }

  static Stream<List<ChatMessage>> getChatMessages(String sessionId) {
    final userId = AuthService.currentUid;
    if (userId == null) return Stream.value([]);
    
    return _db
        .collection('chat_messages')
        .where('userId', isEqualTo: userId)
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  static Future<void> deleteChatSession(String sessionId) async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      throw Exception("User not logged in to delete session");
    }
    try {
      final batch = _db.batch();
      final messagesSnapshot = await _db
          .collection('chat_messages')
          .where('userId', isEqualTo: userId)
          .where('sessionId', isEqualTo: sessionId)
          .get();
          
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_db.collection('chat_sessions').doc(sessionId));
      await batch.commit();

    } catch (e) {
      debugPrint('Error deleting chat session: $e');
      rethrow;
    }
  }

  static Future<void> updateChatSessionTitle(String sessionId, String newTitle) async {
    if (sessionId.isEmpty || newTitle.isEmpty) {
      debugPrint("Session ID or new title is empty, cannot update.");
      return;
    }
    try {
      await _db.collection('chat_sessions').doc(sessionId).update({
        'title': newTitle,
      });
      debugPrint("Successfully updated title for session $sessionId.");
    } catch (e) {
      debugPrint("Error updating chat session title for $sessionId: $e");
      rethrow;
    }
  }

  // --- دوال إدارة بيانات المستخدم (User Profile Data) ---

  static Future<UserModel?> getUserProfile() async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      debugPrint('Error: User not logged in to fetch profile.');
      return null;
    }

    try {
      final docSnapshot = await _db.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot);
      } else {
        debugPrint('User profile not found for ID: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  static Future<void> saveUserProfile(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toJson(), SetOptions(merge: true));
      debugPrint('User profile for ${user.uid} saved/updated successfully.');
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }
  
  static Future<void> updateUserField(String userId, String fieldName, dynamic value) async {
    try {
      await _db.collection('users').doc(userId).update({
        fieldName: value,
      });
      debugPrint('تم تحديث حقل "$fieldName" للمستخدم "$userId" بنجاح بالقيمة: $value');
    } catch (e) {
      debugPrint('خطأ في تحديث حقل "$fieldName" للمستخدم "$userId": $e');
      rethrow;
    }
  }
  
  static Future<void> addUserValueToList(String field, String valueToAdd) async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      debugPrint("Error: User not logged in to update list field.");
      return;
    }
    try {
      await _db.collection('users').doc(userId).update({
        field: FieldValue.arrayUnion([valueToAdd]),
      });
      debugPrint("Successfully added '$valueToAdd' to field '$field' for user $userId");
    } catch (e) {
      debugPrint("Error updating list field '$field': $e");
      rethrow;
    }
  }

  static Future<void> removeImportantRelationship(String relationshipName) async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      debugPrint("Error: User not logged in to remove relationship.");
      return;
    }
    try {
      await _db.collection('users').doc(userId).update({
        'importantRelationships.$relationshipName': FieldValue.delete(),
      });
      debugPrint("Successfully removed relationship: $relationshipName");
    } catch (e) {
      debugPrint("Error removing relationship '$relationshipName': $e");
      rethrow;
    }
  }

  static Future<void> submitAssessmentRequest(AssessmentRequest request) async {
    try {
      await _db
          .collection('assessment_requests')
          .doc(request.id)
          .set(request.toJson());
      debugPrint("Assessment request ${request.id} submitted successfully.");
    } catch (e) {
      debugPrint("Error submitting assessment request: $e");
      rethrow;
    }
  }
  
  static Stream<List<ClarificationCardModel>> getPendingSummaryCards() {
    final userId = AuthService.currentUid;
    if (userId == null) {
      return Stream.value([]);
    }
    return _db
        .collection('pending_summaries')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClarificationCardModel.fromFirestore(doc);
      }).toList();
    });
  }

  static Future<List<ClarificationCardModel>> getPendingSummaryCardsOnce() async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      return [];
    }
    try {
      final snapshot = await _db
          .collection('pending_summaries')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get(); 

      return snapshot.docs.map((doc) {
        return ClarificationCardModel.fromFirestore(doc);
      }).toList();
    } catch (e) {
      debugPrint('Error getting summary cards once: $e');
      return [];
    }
  }
  
  static Future<void> addUserFact({required String content, required String category}) async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      return;
    }
    try {
      final factData = {
        'content': content,
        'category': category,
        'source': 'session_analysis',
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('users')
          .doc(userId)
          .collection('user_memory')
          .add(factData);
    } catch (e) {
      debugPrint("Error adding user fact: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPersonalitySettings() async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      return {};
    }
    try {
      final docRef = _db.collection('users').doc(userId).collection('profile').doc('settings');
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        return docSnapshot.data() ?? {};
      } else {
        const defaultSettings = {
          'linguistic_gender': 'male',
          'preferred_tone': 'friendly',
          'response_length': 'medium',
        };
        await docRef.set(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      debugPrint("Error getting personality settings: $e");
      return {};
    }
  }

  static Future<void> updatePersonalitySetting(String key, dynamic value) async {
    final userId = AuthService.currentUid;
    if (userId == null) {
      return;
    }
    try {
      final docRef = _db.collection('users').doc(userId).collection('profile').doc('settings');
      await docRef.set({key: value}, SetOptions(merge: true)); 
    } catch (e) {
      debugPrint("Error updating personality setting '$key': $e");
      rethrow;
    }
  }
}