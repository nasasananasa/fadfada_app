// lib/services/ai_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';

class AIService {
  
  static Future<void> analyzeConversationV2(String sessionId) async {
    if (sessionId.isEmpty) {
      debugPrint("Session ID is empty, cannot run analysis.");
      return;
    }
    try {
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: "europe-west1");
      
      final callable = functions.httpsCallable('buildUserProfileV2');
      
      debugPrint("Calling analysis function 'buildUserProfileV2' for sessionId: $sessionId");
      await callable.call({'sessionId': sessionId});

      debugPrint("Analysis function triggered successfully for session: $sessionId");

    } on FirebaseFunctionsException catch (e) {
      debugPrint('Analysis Function Error: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('A generic error occurred during analysis trigger: $e');
    }
  }

  static Future<String> sendMessage(
    String message, {
    List<ChatMessage>? previousMessages,
    UserModel? currentUser,
    bool isFirstMessage = false,
  }) async {
    try {
      final conversationHistory = (previousMessages ?? []).map((msg) {
        return {'role': msg.isFromUser ? 'user' : 'assistant', 'content': msg.content};
      }).toList();
      conversationHistory.add({'role': 'user', 'content': message});

      return await _getChatResponseFromCloud(conversationHistory);

    } catch (e) {
      debugPrint('AI Service Error: $e');
      return _getErrorResponse();
    }
  }

  // ===================================================================
  // ✅ START: MODIFIED FUNCTION TO CALL THE NEW "THINKING BRAIN"
  // ===================================================================
  static Future<String> _getChatResponseFromCloud(List<Map<String, String>> conversation) async {
    try {
      final FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: "europe-west1");
      // تم تغيير اسم الدالة هنا لتتوافق مع "العقل المفكر" الجديد
      final callable = functions.httpsCallable('getDynamicChatResponse'); 
      
      debugPrint("Calling the new dynamic cloud function 'getDynamicChatResponse'...");

      final HttpsCallableResult result = await callable.call(
        <String, dynamic>{
          'conversation': conversation, 
        },
      );

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'success' && data['response'] != null) {
        debugPrint("AI response received successfully from the new dynamic function.");
        return data['response'];
      } else {
        debugPrint("Cloud function executed but returned an error or empty response: ${data['status']}");
        throw Exception('Failed to get a valid response from the new dynamic function.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException while getting chat response: ${e.code} ${e.message}');
      throw Exception('FirebaseFunctionsException: ${e.message}');
    } catch (e) {
      debugPrint('General exception while getting chat response: $e');
      throw Exception('General exception: $e');
    }
  }
  // ===================================================================
  // ✅ END: MODIFIED FUNCTION
  // ===================================================================

  static String _getErrorResponse() {
    return 'عفواً، صار في مشكلة تقنية صغيرة. بس أنا لسا هون معك. ممكن تجرب ترسل مرة تانية؟';
  }

  static Future<void> actionOnSummaryCard({
    required String cardId,
    required String action,
    String? editedText,
  }) async {
    try {
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: "europe-west1");
      final callable = functions.httpsCallable('confirmSummaryPoint');
      
      debugPrint("Calling cloud function 'confirmSummaryPoint' for card: $cardId with action: $action");

      await callable.call(<String, dynamic>{
        'cardId': cardId,
        'action': action,
        'editedText': editedText,
      });

      debugPrint("Action '$action' on card $cardId completed successfully in the cloud.");
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud function "confirmSummaryPoint" error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Generic error calling confirmSummaryPoint: $e');
      rethrow;
    }
  }

  // ✅ START: NEW FUNCTION FOR SMART TITLES (Chat)
  static Future<void> generateChatTitle(String sessionId) async {
    if (sessionId.isEmpty) {
      debugPrint("Session ID is empty, cannot generate title.");
      return;
    }
    try {
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: "europe-west1");
      final callable = functions.httpsCallable('generateChatTitle');
      
      debugPrint("Calling title generation function for sessionId: $sessionId");
      await callable.call({'sessionId': sessionId});

      debugPrint("Title generation function triggered successfully for session: $sessionId");

    } on FirebaseFunctionsException catch (e) {
      debugPrint('Title Generation Function Error: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('A generic error occurred during title generation trigger: $e');
    }
  }
  // ✅ END: NEW FUNCTION (Chat)

  // ✅ START: NEW FUNCTION FOR SMART TITLES (Journal Entry)
  static Future<String?> generateJournalTitleForJournalEntry({
    required String journalEntryContent,
    required String journalEntryId,
  }) async {
    if (journalEntryContent.isEmpty || journalEntryId.isEmpty) {
      debugPrint("Journal entry content or ID is empty, cannot generate title.");
      return null;
    }
    try {
      final FirebaseFunctions functions =
          FirebaseFunctions.instanceFor(region: "europe-west1");
      
      // تأكد أن هذا هو اسم دالة Firebase Function الخاصة بتوليد عنوان الخاطرة
      final callable = functions.httpsCallable('generateJournalTitle');
      
      debugPrint("Calling journal title generation function for entryId: $journalEntryId");

      final HttpsCallableResult result = await callable.call(
        <String, dynamic>{
          'entryId': journalEntryId,
          'content': journalEntryContent,
        },
      );

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'success' && data['title'] != null) {
        debugPrint("Journal title received successfully from cloud function: ${data['title']}");
        return data['title'];
      } else {
        debugPrint("Cloud function executed but returned an error or empty title: ${data['status']}");
        return null; // Return null if title generation failed or was empty
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Journal Title Generation Function Error: ${e.code} - ${e.message}');
      // يمكنك هنا إظهار رسالة خطأ للمستخدم إذا أردت
      return null;
    } catch (e) {
      debugPrint('A generic error occurred during journal title generation: $e');
      return null;
    }
  }


  static Future<String> generateDailyTip() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('generateDailyTip');
      final response = await callable.call();
      // تأكد من أن الدالة السحابية تعيد كائناً يحتوي على مفتاح 'tip'
      return response.data['tip'] as String;
    } catch (e) {
      debugPrint("Error calling generateDailyTip function: $e");
      // في حالة حدوث خطأ، أعد رمي الخطأ ليتم التعامل معه في الواجهة
      rethrow;
    }
  }
  
  }