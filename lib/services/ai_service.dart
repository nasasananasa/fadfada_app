import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';
import '../models/chat_message.dart';

class AIService {
  // عنوان URL الأساسي لـ OpenAI API
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  // إرسال رسالة وتلقي الرد من AI
  static Future<String> sendMessage(
    String message,
    Mood selectedMood,
    {List<ChatMessage>? previousMessages}
  ) async {
    try {
      // بناء prompt النظام (system prompt) بناءً على الحالة المزاجية
      final systemPrompt = _buildSystemPrompt(selectedMood);

      // بناء تاريخ الرسائل الذي سيُرسل إلى API
      final messages = _buildMessageHistory(systemPrompt, message, previousMessages);

      // تفعيل كود API الحقيقي وإرسال الطلب إلى OpenAI
      return await _sendToOpenAI(messages);
      
      // الكود السابق للاستجابة المحلية (للاختبار) تم تعليقه
      // return await _getLocalAIResponse(message, selectedMood);
      
    } catch (e) {
      // طباعة الخطأ والتعامل معه بتقديم رسالة خطأ ودودة للمستخدم
      print('AI Service Error: $e');
      return _getErrorResponse(selectedMood);
    }
  }

  // بناء prompt النظام (system prompt) حسب الحالة النفسية
  static String _buildSystemPrompt(Mood mood) {
    // التعليمات الأساسية لشخصية المساعد الافتراضي
    final basePrompt = '''
أنت صديق افتراضي متفهم ومساعد في تطبيق "فضفضة" للدعم النفسي الأولي.
مهمتك تقديم الدعم العاطفي والنصائح البسيطة بطريقة ودودة ومتفهمة.

إرشادات مهمة:
- اكتب باللغة العربية فقط.
- كن متعاطفاً ومستمعاً جيداً.
- قدم نصائح بناءة وإيجابية.
- لا تقدم تشخيصات طبية أو علاجية.
- اقترح طلب المساعدة المهنية عند الحاجة (مثال: "قد يكون من المفيد التحدث مع متخصص في هذا الشأن").
- حافظ على محادثة طبيعية وودودة.
- استخدم أسلوباً بسيطاً ومفهوماً.
''';

    // إضافة تعليمات خاصة بالحالة النفسية المحددة
    final moodSpecificPrompt = _getMoodSpecificPrompt(mood);
    
    // دمج التعليمات الأساسية مع التعليمات الخاصة بالمزاج
    return '$basePrompt\n\n$moodSpecificPrompt';
  }

  // نصائح خاصة بكل حالة نفسية (لتضمينها في System Prompt)
  static String _getMoodSpecificPrompt(Mood mood) {
    switch (mood.id) {
      case 'happy':
        return 'المستخدم يشعر بالسعادة. ركز على تعزيز هذا الشعور واستكشاف أسبابه، وساعده على الحفاظ على هذه المشاعر الإيجابية.';
      case 'anxious':
        return 'المستخدم يشعر بالقلق. ركز على الاستماع لمخاوفه، قدم له تقنيات تهدئة وطمأنة بسيطة، وشجعه على التعبير عن ما يقلقه.';
      case 'sad':
        return 'المستخدم يشعر بالحزن. كن متعاطفاً جداً، قدم له مساحة آمنة للتعبير عن حزنه دون حكم، واقترح أنشطة إيجابية قد تساعده تدريجياً.';
      case 'stressed':
        return 'المستخدم يشعر بالتوتر. ركز على فهم مصادر التوتر لديه، اقترح تقنيات إدارة التوتر والاسترخاء، وشجعه على إيجاد حلول عملية إن أمكن.';
      case 'confused':
        return 'المستخدم يشعر بالتشويش. ساعده على تنظيم أفكاره وتوضيح الأمور، واطرح أسئلة تساعده على فهم الوضع بشكل أفضل.';
      case 'tired':
        return 'المستخدم يشعر بالتعب. أقر بتعبه، واقترح طرق الراحة واستعادة الطاقة، وشجعه على أخذ قسط كافٍ من النوم.';
      case 'angry':
        return 'المستخدم يشعر بالغضب. استمع لسبب غضبه دون الحكم، ساعده على تهدئة نفسه وإدارة غضبه بطرق صحية، واقترح عليه التعبير عن غضبه بطريقة بناءة.';
      case 'peaceful':
        return 'المستخدم يشعر بالهدوء. استكشف معه أسباب هذا الشعور الجميل، وساعده على الحفاظ على هذا الشعور واستعادته في المستقبل.';
      default:
        return 'استمع للمستخدم جيداً، وتعاطف معه، وقدم الدعم المناسب بناءً على ما يعبر عنه.';
    }
  }

  // بناء تاريخ الرسائل (يتضمن System Prompt والرسائل السابقة والحالية)
  static List<Map<String, String>> _buildMessageHistory(
    String systemPrompt,
    String currentMessage,
    List<ChatMessage>? previousMessages
  ) {
    final messages = <Map<String, String>>[];
    
    // 1. إضافة prompt النظام في البداية لتحديد شخصية AI
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // 2. إضافة الرسائل السابقة (من المستخدم و AI) للحفاظ على السياق
    // نأخذ آخر 10 رسائل فقط (أو عدد أقل إذا كانت المحادثة أقصر) لتجنب تجاوز حد الـ tokens
    if (previousMessages != null && previousMessages.isNotEmpty) {
      // هذا الجزء تم تعديله في chat_screen، ولكن هنا نضمن أنه إذا تم تمرير القائمة كاملة
      // فإننا نأخذ منها آخر 10 رسائل فقط قبل إضافتها إلى الـ messages
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

    // 3. إضافة الرسالة الحالية من المستخدم
    messages.add({
      'role': 'user',
      'content': currentMessage,
    });

    return messages;
  }

  // دالة الاستجابة المحلية (للاختبار) - معطلة الآن
  static Future<String> _getLocalAIResponse(String message, Mood mood) async {
    // محاكاة تأخير API
    await Future.delayed(const Duration(milliseconds: 1500));

    // ردود تجريبية حسب الحالة النفسية والرسالة
    final responses = _getTestResponses(mood, message);
    responses.shuffle();
    return responses.first;
  }

  // ردود تجريبية للاختبار (تُستخدم فقط من _getLocalAIResponse)
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

  // رسالة خطأ ودودة ليتم عرضها للمستخدم في حالة فشل الاتصال بالـ AI
  static String _getErrorResponse(Mood mood) {
    return 'أعتذر، واجهت مشكلة تقنية أثناء محاولة الاتصال. لكن أريدك أن تعلم أنني هنا لأساعدك. هل يمكنك إعادة المحاولة؟';
  }

  // إرسال الطلب إلى OpenAI API الحقيقي
  static Future<String> _sendToOpenAI(List<Map<String, String>> messages) async {
    final apiKey = dotenv.env['OPENAI_API_KEY']; // جلب مفتاح API من ملف .env
    if (apiKey == null || apiKey.isEmpty) {
      // إلقاء استثناء إذا كان المفتاح غير موجود أو فارغ
      throw Exception('OpenAI API Key is not configured in .env file.');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl), // استخدام عنوان الـ API الثابت
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey', // تمرير المفتاح في Header
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // اسم النموذج المستخدم
          'messages': messages, // تاريخ المحادثة بالكامل
          'max_tokens': 500, // الحد الأقصى لعدد التوكنات في الرد
          'temperature': 0.7, // درجة الحرارة للتحكم في مدى عشوائية الرد
        }),
      );

      if (response.statusCode == 200) {
        // إذا كان الرد ناجحاً (HTTP 200 OK)
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        // إذا كان هناك خطأ في رد الـ API
        print('Error response from OpenAI: ${response.statusCode}');
        print('Response body: ${response.body}');
        // إلقاء استثناء مع رسالة خطأ توضح المشكلة
        throw Exception(
            'فشل في الاتصال بخدمة الذكاء الصناعي. الكود: ${response.statusCode}، الرسالة: ${response.body}');
      }
    } catch (e) {
      // التعامل مع الأخطاء التي قد تحدث أثناء عملية إرسال الطلب (مثل مشاكل الشبكة)
      print('Exception during API call to OpenAI: $e');
      rethrow; // إعادة إلقاء الاستثناء للتعامل معه في الطبقة الأعلى (ChatScreen)
    }
  }

  // دالة لتنظيف تاريخ المحادثة المخزن (إذا كان هناك تاريخ محلي مخزن)
  static void clearConversationHistory() {
    // هذا المتغير كان لتخزين الـ history محلياً، ولكنه غير مستخدم حالياً
    // لأن الـ history يتم تمريره مع كل طلب API.
    // _conversationHistory.clear();
  }

  // الحصول على اقتراحات للرسائل الأولى بناءً على الحالة المزاجية
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
      default: // تشمل confused, tired, angry, peaceful وأي مزاج غير معرف
        return [
          'أريد أن أتحدث عن شعوري',
          'كيف يمكنني التعامل مع هذا الوضع؟',
          'أحتاج نصيحة',
        ];
    }
  }
}