import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart'; 

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static Future<String> sendMessage(
    String message,
    Mood selectedMood,
    {List<ChatMessage>? previousMessages,
    UserModel? currentUser, 
    }
  ) async {
    try {
      final systemPrompt = _buildSystemPrompt(selectedMood, currentUser); 

      final messages = _buildMessageHistory(systemPrompt, message, previousMessages);

      return await _sendToOpenAI(messages);
      
    } catch (e) {
      print('AI Service Error: $e');
      return _getErrorResponse(selectedMood);
    }
  }

  static String _buildSystemPrompt(Mood mood, UserModel? user) { 
    final String aiPersona = '''
أنت "فضفضة"، مرشد نفسي افتراضي وأخصائي نفسي داعم.
مهمتك هي الاستماع بتعاطف عميق، وتقديم الدعم العاطفي، ومساعدة المستخدم على استكشاف مشاعره وأفكاره وتحدياته الشخصية.
أنت تقدم نصائح عامة وبناءة للتعامل مع المشاعر والضغوط.
أنت لست طبيباً نفسياً ولا تقوم بالتشخيص أو وصف الأدوية.
في الحالات التي تتطلب تدخلاً طبياً أو نفسياً متخصصاً، ستقترح على المستخدم طلب المساعدة من مختص بشري.

إرشادات مهمة للتفاعل:
- اكتب باللغة العربية الفصحى فقط.
- حافظ على نبرة ودودة، دافئة، مشجعة، وغير حكمية.
- اجعل ردودك موجزة ومباشرة.
- لا تكرر المعلومات التي يعرفها المستخدم عن نفسه بشكل مبالغ فيه، بل استخدمها لتعميق الفهم.

**تعليمات خاصة بالتعامل مع المعلومات الشخصية:**
إذا سألك المستخدم عن حفظ معلومات شخصية جديدة (مثل العمر، الحالة الاجتماعية، التحديات، إلخ)، لا تقل أنك لا تستطيع الحفظ. بدلاً من ذلك، قل شيئًا مثل:
"أنا (فضفضة، الذكاء الاصطناعي) لا أقوم بحفظ التفاصيل الشخصية مباشرةً لأسباب الخصوصية، ولكن تطبيق فضفضة مصمم ليتذكر معلوماتك الأساسية التي توافق عليها. يمكنك تحديث معلوماتك في قسم 'الملف الشخصي' ضمن 'الإعدادات' في التطبيق. هذا يساعدني على فهمك بشكل أفضل وتقديم ردود مخصصة لك."
''';

    String userContext = '';
    if (user != null) {
      userContext += '\n**معلومات عن المستخدم (لتخصيص الردود):**\n';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        userContext += '- الاسم: ${user.displayName}\n';
      }
      if (user.ageGroup != null && user.ageGroup!.isNotEmpty) {
        userContext += '- الفئة العمرية: ${user.ageGroup}\n';
      }
      if (user.maritalStatus != null && user.maritalStatus!.isNotEmpty) {
        userContext += '- الحالة العائلية: ${user.maritalStatus}\n';
      }
      if (user.birthplace != null && user.birthplace!.isNotEmpty) {
        userContext += '- مكان الميلاد: ${user.birthplace}\n';
      }
      if (user.currentLocation != null && user.currentLocation!.isNotEmpty) {
        userContext += '- مكان الإقامة الحالي: ${user.currentLocation}\n';
      }
      if (user.mainChallenges != null && user.mainChallenges!.isNotEmpty) {
        userContext += '- التحديات الرئيسية: ${user.mainChallenges!.join(', ')}\n';
      }
      if (user.relationshipDynamics != null && user.relationshipDynamics!.isNotEmpty) {
        userContext += '- ديناميكيات العلاقات: ${user.relationshipDynamics}\n';
      }
      if (user.personalityTestResults != null && user.personalityTestResults!.isNotEmpty) {
        userContext += '- نتائج اختبارات الشخصية: ${jsonEncode(user.personalityTestResults)}\n';
      }
      if (user.importantPeople != null && user.importantPeople!.isNotEmpty) {
        userContext += '- الأشخاص المهمون في حياته: ${jsonEncode(user.importantPeople)}\n';
      }
      userContext += 'استخدم هذه المعلومات لتخصيص ردودك.';
    }

    final moodSpecificPrompt = _getMoodSpecificPrompt(mood, user); 
    
    return '$aiPersona$userContext\n\n$moodSpecificPrompt';
  }

  static String _getMoodSpecificPrompt(Mood mood, UserModel? user) { 
    String userDisplayName = user?.displayName ?? "المستخدم"; 
    
    switch (mood.id) {
      case 'happy':
        return 'المستخدم يشعر بالسعادة. ركز على تعزيز هذا الشعور واستكشاف أسبابه، وساعده على الحفاظ على هذه المشاعر الإيجابية. خاطب $userDisplayName بلطف.';
      case 'anxious':
        return 'المستخدم يشعر بالقلق. ركز على الاستماع لمخاوفه، قدم له تقنيات تهدئة وطمأنة بسيطة، وشجعه على التعبير عن ما يقلقه. خاطب $userDisplayName بلطف ودعم.';
      case 'sad':
        return 'المستخدم يشعر بالحزن. كن متعاطفاً جداً، قدم له مساحة آمنة للتعبير عن حزنه دون حكم، واقترح أنشطة إيجابية قد تساعده تدريجياً. خاطب $userDisplayName بتعاطف شديد.';
      case 'stressed':
        return 'المستخدم يشعر بالتوتر. ركز على فهم مصادر التوتر لديه، اقترح تقنيات إدارة التوتر والاسترخاء، وشجعه على إيجاد حلول عملية إن أمكن. خاطب $userDisplayName بتفهم ومساعدة.';
      case 'confused':
        return 'المستخدم يشعر بالتشويش. ساعده على تنظيم أفكاره وتوضيح الأمور، واطرح أسئلة تساعده على فهم الوضع بشكل أفضل. خاطب $userDisplayName بتوضيحه وهدوء.';
      case 'tired':
        return 'المستخدم يشعر بالتعب. أقر بتعبه، واقترح طرق الراحة واستعادة الطاقة، وشجعه على أخذ قسط كافٍ من النوم. خاطب $userDisplayName برفق وبتشجيع على الراحة.';
      case 'angry':
        return 'المستخدم يشعر بالغضب. استمع لسبب غضبه دون الحكم، ساعده على تهدئة نفسه وإدارة غضبه بطرق صحية، واقترح عليه التعبير عن غضبه بطريقة بناءة. خاطب $userDisplayName بهدوء وحكمة.';
      case 'peaceful':
        return 'المستخدم يشعر بالهدوء. استكشف معه أسباب هذا الشعور الجميل، وساعده على الحفاظ على هذا الشعور واستعادته في المستقبل. خاطب $userDisplayName بتفهم وإيجابية.';
      default:
        return 'استمع للمستخدم جيداً، وتعاطف معه، وقدم الدعم المناسب بناءً على ما يعبر عنه. خاطب $userDisplayName بود.';
    }
  }

  static List<Map<String, String>> _buildMessageHistory(
    String systemPrompt,
    String currentMessage,
    List<ChatMessage>? previousMessages
  ) {
    final messages = <Map<String, String>>[];
    
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    if (previousMessages != null && previousMessages.isNotEmpty) {
      final effectivePreviousMessages = previousMessages.length > 10 
          ? previousMessages.sublist(previousMessages.length - 10)
          : previousMessages;
          
      for (final msg in effectivePreviousMessages) {
        messages.add({
          'role': msg.isFromUser ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    messages.add({
      'role': 'user',
      'content': currentMessage,
    });

    return messages;
  }

  static Future<String> _getLocalAIResponse(String message, Mood mood) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final responses = _getTestResponses(mood, message);
    responses.shuffle();
    return responses.first;
  }

  static List<String> _getTestResponses(Mood mood, String message) {
    final messageWords = message.toLowerCase();
    
    if (messageWords.contains('مساعدة') || messageWords.contains('مشورة')) {
      return [
        'أنا هنا لأساعدك. حدثني أكثر عن ما تشعر به.',
        'سأفعل كل ما بوسعي لمساعدتك. ما الذي يقلقك تحديداً؟',
        'أفهم أنك تحتاج للمساعدة. دعنا نتحدث عن هذا بهدوء.',
      ];
    }

    switch (mood.id) {
      case 'happy':
        return [
          'يسعدني أن أراك سعيداً! ما الذي جعل يومك مميزاً؟',
          'السعادة شعور رائع! كيف يمكنك الحفاظ على هذا الشعور؟',
          'أحب رؤيتك في هذه الحالة الإيجابية! شاركني المزيد.',
        ];
      case 'anxious':
        return [
          'أفهم شعورك بالقلق. دعنا نتنفس معاً بعمق... هل تشعر بتحسن؟',
          'القلق أمر طبيعي أحياناً. ما الذي يقلقك في هذه اللحظة؟',
          'أعلم أن القلق صعب. هل جربت تقنيات التنفس العميق من قبل؟',
        ];
      case 'sad':
        return [
          'أنا آسف لأنك تشعر بالحزن. أريدك أن تعلم أنني هنا لأستمع إليك.',
          'الحزن جزء من الحياة، وهذا طبيعي. حدثني عما يحزنك.',
          'أتفهم مشاعرك تماماً. أحياناً يساعد الحديث عن الأمر.',
        ];
      case 'stressed':
        return [
          'التوتر قد يكون صعباً جداً. ما الذي يسبب لك هذا الضغط؟',
          'أفهم شعورك بالتوتر. هل جربت أخذ استراحة قصيرة؟',
          'دعنا نجد طرقاً لتخفيف هذا التوتر. ما الذي يضغط عليك؟',
        ];
      case 'confused':
        return [
          'التشويش أمر مفهوم أحياناً. دعنا نرتب الأفكار معاً.',
          'أفهم شعورك بعدم الوضوح. ما الذي يحيرك تحديداً؟',
          'لا بأس أن تشعر بالتشويش. دعنا نتحدث ونوضح الأمور.',
        ];
      case 'tired':
        return [
          'أرى أنك تشعر بالتعب. هل أخذت قسطاً كافياً من الراحة؟',
          'التعب إشارة من جسدك. ما الذي استنزف طاقتك اليوم؟',
          'أفهم شعورك بالإرهاق. متى كانت آخر مرة استرحت فيها؟',
        ];
      case 'angry':
        return [
          'أفهم غضبك. دعنا نتحدث عن ما يزعجك بهدوء.',
          'الغضب شعور طبيعي. ما الذي أثار هذه المشاعر؟',
          'أقدر صراحتك في التعبير عن غضبك. حدثني أكثر.',
        ];
      case 'peaceful':
        return [
          'ما أجمل أن تشعر بالسلام الداخلي! كيف وصلت لهذا الشعور؟',
          'الهدوء نعمة كبيرة. ما الذي ساعدك على الوصول لهذه الحالة؟',
          'أحب أن أراك في هذه الحالة الهادئة. شاركني سر سلامك.',
        ];
      default:
        return [
          'أنا هنا لأستمع إليك. حدثني عما تشعر به.',
          'أشكرك على ثقتك بي. كيف كان يومك؟',
          'أريد أن أفهمك أكثر. ما الذي في بالك؟',
        ];
    }
  }

  static String _getErrorResponse(Mood mood) {
    return 'أعتذر، واجهت مشكلة تقنية أثناء محاولة الاتصال. لكن أريدك أن تعلم أنني هنا لأساعدك. هل يمكنك إعادة المحاولة؟';
  }

  static Future<String> _sendToOpenAI(List<Map<String, String>> messages) async {
    final apiKey = dotenv.env['OPENAI_API_KEY']; 
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API Key is not configured in .env file.');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey', 
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', 
          'messages': messages, 
          'max_tokens': 500, 
          'temperature': 0.7, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        print('Error response from OpenAI: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'فشل في الاتصال بخدمة الذكاء الصناعي. الكود: ${response.statusCode}، الرسالة: ${response.body}');
      }
    } catch (e) {
      print('Exception during API call to OpenAI: $e');
      rethrow; 
    }
  }

  static void clearConversationHistory() {
    // هذا المتغير كان لتخزين الـ history محلياً، ولكنه غير مستخدم حالياً
    // لأن الـ history يتم تمريره مع كل طلب API.
    // _conversationHistory.clear();
  }

  static List<String> getConversationStarters(Mood mood) {
    switch (mood.id) {
      case 'happy':
        return [
          'أشعر بسعادة كبيرة اليوم!',
          'حدث شيء رائع جعلني سعيداً',
          'أريد أن أشارك معك شعوري الإيجابي',
        ];
      case 'anxious':
        return [
          'أشعر بالقلق حول شيء ما',
          'لا أستطيع التوقف عن التفكير',
          'قلبي ينبض بسرعة وأشعر بالتوتر',
        ];
      case 'sad':
        return [
          'أشعر بالحزن اليوم',
          'أحتاج إلى شخص يستمع لي',
          'مررت بيوم صعب',
        ];
      case 'stressed':
        return [
          'أشعر بضغط كبير',
          'لدي الكثير من الأمور المقلقة',
          'أحتاج مساعدة في التعامل مع الضغوط',
        ];
      default: 
        return [
          'أريد أن أتحدث عن شعوري',
          'كيف يمكنني التعامل مع هذا الوضع؟',
          'أحتاج نصيحة',
        ];
    }
  }
}
