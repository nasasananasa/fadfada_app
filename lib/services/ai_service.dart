import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';
import '../models/chat_message.dart';

class AIService {
  // يمكن استخدام OpenAI أو MiniMax API
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  
  // تخزين السياق للمحادثة
  static List<Map<String, String>> _conversationHistory = [];

  // إرسال رسالة وتلقي الرد
  static Future<String> sendMessage(
    String message, 
    Mood selectedMood, 
    {List<ChatMessage>? previousMessages}
  ) async {
    try {
      // بناء السياق للمحادثة
      final systemPrompt = _buildSystemPrompt(selectedMood);
      final messages = _buildMessageHistory(systemPrompt, message, previousMessages);

      // استعمال واجهة برمجية محلية للاختبار
      // في الإنتاج، يتم استخدام OpenAI أو MiniMax API الحقيقي
      return await _getLocalAIResponse(message, selectedMood);
      
      // كود API الحقيقي (يتم تفعيله لاحقاً):
      // return await _sendToOpenAI(messages);
      
    } catch (e) {
      print('AI Service Error: $e');
      return _getErrorResponse(selectedMood);
    }
  }

  // بناء prompt النظام حسب الحالة النفسية
  static String _buildSystemPrompt(Mood mood) {
    final basePrompt = '''
أنت صديق افتراضي متفهم ومساعد في تطبيق "فضفضة" للدعم النفسي الأولي.
مهمتك تقديم الدعم العاطفي والنصائح البسيطة بطريقة ودودة ومتفهمة.

إرشادات مهمة:
- اكتب باللغة العربية فقط
- كن متعاطفاً ومستمعاً جيداً
- قدم نصائح بناءة وإيجابية
- لا تقدم تشخيصات طبية
- اقترح طلب المساعدة المهنية عند الحاجة
- حافظ على محادثة طبيعية وودودة
- استخدم أسلوباً بسيطاً ومفهوماً
''';

    // إضافة نصائح خاصة بالحالة النفسية
    final moodSpecificPrompt = _getMoodSpecificPrompt(mood);
    
    return '$basePrompt\n\n$moodSpecificPrompt';
  }

  // نصائح خاصة بكل حالة نفسية
  static String _getMoodSpecificPrompt(Mood mood) {
    switch (mood.id) {
      case 'happy':
        return 'المستخدم يشعر بالسعادة. ساعده على الحفاظ على هذه المشاعر الإيجابية.';
      case 'anxious':
        return 'المستخدم يشعر بالقلق. قدم له تقنيات تهدئة وطمأنة بسيطة.';
      case 'sad':
        return 'المستخدم يشعر بالحزن. كن متعاطفاً واقترح أنشطة إيجابية.';
      case 'stressed':
        return 'المستخدم يشعر بالتوتر. اقترح تقنيات إدارة التوتر والاسترخاء.';
      case 'confused':
        return 'المستخدم يشعر بالتشويش. ساعده على تنظيم أفكاره وإيجاد وضوح.';
      case 'tired':
        return 'المستخدم يشعر بالتعب. اقترح طرق الراحة واستعادة الطاقة.';
      case 'angry':
        return 'المستخدم يشعر بالغضب. ساعده على تهدئة نفسه وإدارة غضبه.';
      case 'peaceful':
        return 'المستخدم يشعر بالهدوء. ساعده على الحفاظ على هذا الشعور.';
      default:
        return 'استمع للمستخدم وقدم الدعم المناسب.';
    }
  }

  // بناء تاريخ الرسائل
  static List<Map<String, String>> _buildMessageHistory(
    String systemPrompt, 
    String currentMessage,
    List<ChatMessage>? previousMessages
  ) {
    final messages = <Map<String, String>>[];
    
    // إضافة prompt النظام
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // إضافة الرسائل السابقة (آخر 10 رسائل فقط لتوفير الذاكرة)
    if (previousMessages != null && previousMessages.isNotEmpty) {
      final recentMessages = previousMessages.length > 10 
          ? previousMessages.sublist(previousMessages.length - 10)
          : previousMessages;
          
      for (final msg in recentMessages) {
        messages.add({
          'role': msg.isFromUser ? 'user' : 'assistant',
          'content': msg.content,
        });
      }
    }

    // إضافة الرسالة الحالية
    messages.add({
      'role': 'user',
      'content': currentMessage,
    });

    return messages;
  }

  // استجابة AI محلية للاختبار
  static Future<String> _getLocalAIResponse(String message, Mood mood) async {
    // محاكاة تأخير API
    await Future.delayed(const Duration(milliseconds: 1500));

    // ردود تجريبية حسب الحالة النفسية والرسالة
    final responses = _getTestResponses(mood, message);
    responses.shuffle();
    return responses.first;
  }

  // ردود تجريبية للاختبار
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

  // رسالة خطأ ودودة
  static String _getErrorResponse(Mood mood) {
    return 'أعتذر، واجهت مشكلة تقنية. لكن أريدك أن تعلم أنني هنا لأساعدك. هل يمكنك إعادة المحاولة؟';
  }

  // إرسال للـ OpenAI API الحقيقي (للاستخدام المستقبلي)
  static Future<String> _sendToOpenAI(List<Map<String, String>> messages) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
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
      return data['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('فشل في الاتصال بخدمة الذكاء الصناعي');
    }
  }

  // تنظيف تاريخ المحادثة
  static void clearConversationHistory() {
    _conversationHistory.clear();
  }

  // الحصول على اقتراحات للرسائل الأولى
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
