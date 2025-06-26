import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // **هذا هو السطر الجديد الذي كان ناقصاً**

class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_FALLBACK_API_KEY_HERE';

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

      final userId = AuthService.currentUid;
      if (userId != null) {
        await _processAndSaveUserInfo(message, userId);
      } else {
        print("Warning: No user logged in, personal information will not be saved.");
      }

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
      if (user.age != null) {
        userContext += '- العمر التقريبي: ${user.age} سنة\n';
      }
      if (user.maritalStatus != null && user.maritalStatus!.isNotEmpty) {
        userContext += '- الحالة العائلية: ${user.maritalStatus}\n';
      }
      if (user.birthPlace != null && user.birthPlace!.isNotEmpty) {
        userContext += '- مكان الميلاد: ${user.birthPlace}\n';
      }
      if (user.currentResidence != null && user.currentResidence!.isNotEmpty) {
        userContext += '- مكان الإقامة الحالي: ${user.currentResidence}\n';
      }
      if (user.lifeChallenges != null && user.lifeChallenges!.isNotEmpty) {
        userContext += '- التحديات الرئيسية: ${user.lifeChallenges!.join(', ')}\n';
      }
      if (user.importantRelationships != null && user.importantRelationships!.isNotEmpty) {
        userContext += '- العلاقات الهامة: ${user.importantRelationships!.join(', ')}\n';
      }
      if (user.personalityTestResults != null && user.personalityTestResults!.isNotEmpty) {
        userContext += '- نتائج اختبارات الشخصية: ${jsonEncode(user.personalityTestResults)}\n';
      }
      // الحقول الجديدة التي نريد لفضفضة أن يستخدمها في التخصيص
      if (user.job != null && user.job!.isNotEmpty) {
        userContext += '- المهنة/العمل: ${user.job}\n';
      }
      if (user.dreams != null && user.dreams!.isNotEmpty) {
        userContext += '- الأحلام: ${user.dreams!.join(', ')}\n';
      }
      if (user.impactfulExperiences != null && user.impactfulExperiences!.isNotEmpty) {
        userContext += '- تجارب مؤثرة: ${user.impactfulExperiences!.join(', ')}\n';
      }
      if (user.seesTherapist != null) {
        userContext += '- يراجع طبيب/مرشد نفسي: ${user.seesTherapist! ? 'نعم' : 'لا'}\n';
      }
      if (user.takesMedication != null) {
        userContext += '- يتناول أدوية نفسية: ${user.takesMedication! ? 'نعم' : 'لا'}\n';
      }
      if (user.preferencesList != null && user.preferencesList!.isNotEmpty) {
        userContext += '- التفضيلات: ${user.preferencesList!.join(', ')}\n';
      }
      if (user.hobbies != null && user.hobbies!.isNotEmpty) {
        userContext += '- الهوايات: ${user.hobbies!.join(', ')}\n';
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

  /// دالة لمعالجة رسالة المستخدم ومحاولة استخلاص المعلومات وحفظها.
  static Future<void> _processAndSaveUserInfo(String userMessage, String userId) async {
    // 1. محاولة استخلاص العمر
    final int? age = _extractAge(userMessage);
    if (age != null) {
      print("Age detected: $age");
      await FirestoreService.updateUserField(userId, 'age', age);
    }

    // 2. محاولة استخلاص الاسم
    final String? name = _extractName(userMessage);
    if (name != null) {
      print("Name detected: $name");
      await FirestoreService.updateUserField(userId, 'displayName', name);
    }

    // 3. محاولة استخلاص الحالة العائلية
    final String? maritalStatus = _extractMaritalStatus(userMessage);
    if (maritalStatus != null) {
      print("Marital Status detected: $maritalStatus");
      await FirestoreService.updateUserField(userId, 'maritalStatus', maritalStatus);
    }

    // 4. محاولة استخلاص المهنة/العمل
    final String? job = _extractJob(userMessage);
    if (job != null) {
      print("Job detected: $job");
      await FirestoreService.updateUserField(userId, 'job', job);
    }

    // 5. محاولة استخلاص الأحلام والطموحات
    final List<String>? dreams = _extractDreams(userMessage);
    if (dreams != null && dreams.isNotEmpty) {
      print("Dreams detected: $dreams");
      await FirestoreService.updateUserField(userId, 'dreams', FieldValue.arrayUnion(dreams));
    }

    // 6. محاولة استخلاص التجارب المؤثرة
    final List<String>? impactfulExperiences = _extractImpactfulExperiences(userMessage);
    if (impactfulExperiences != null && impactfulExperiences.isNotEmpty) {
      print("Impactful Experiences detected: $impactfulExperiences");
      await FirestoreService.updateUserField(userId, 'impactfulExperiences', FieldValue.arrayUnion(impactfulExperiences));
    }

    // 7. محاولة استخلاص هل يراجع طبيب/مرشد نفسي
    final bool? seesTherapist = _extractSeesTherapist(userMessage);
    if (seesTherapist != null) {
      print("Sees Therapist detected: $seesTherapist");
      await FirestoreService.updateUserField(userId, 'seesTherapist', seesTherapist);
    }

    // 8. محاولة استخلاص هل يتناول أدوية نفسية
    final bool? takesMedication = _extractTakesMedication(userMessage);
    if (takesMedication != null) {
      print("Takes Medication detected: $takesMedication");
      await FirestoreService.updateUserField(userId, 'takesMedication', takesMedication);
    }

    // 9. محاولة استخلاص الهوايات
    final List<String>? hobbies = _extractHobbies(userMessage);
    if (hobbies != null && hobbies.isNotEmpty) {
      print("Hobbies detected: $hobbies");
      await FirestoreService.updateUserField(userId, 'hobbies', FieldValue.arrayUnion(hobbies));
    }

    // 10. محاولة استخلاص الأصدقاء المقربين (كمثال لقائمة String)
    final List<String>? importantRelationships = _extractImportantRelationships(userMessage);
    if (importantRelationships != null && importantRelationships.isNotEmpty) {
      print("Important Relationships detected: $importantRelationships");
      await FirestoreService.updateUserField(userId, 'importantRelationships', FieldValue.arrayUnion(importantRelationships));
    }
  }

  /// Helper function to extract age from text.
  static int? _extractAge(String message) {
    RegExp regExp = RegExp(r'(عمري|انا عندي|أبلغ من العمر)\s*(\d{1,2})\s*(سنة|سنين)?');
    Match? match = regExp.firstMatch(message.toLowerCase());
    if (match != null && match.group(2) != null) {
      return int.tryParse(match.group(2)!);
    }
    return null;
  }

  /// Helper function to extract name from text.
  static String? _extractName(String message) {
    RegExp regExp = RegExp(r'(اسمي|أدعى)\s*([\p{L}\s]+)', unicode: true);
    Match? match = regExp.firstMatch(message);
    if (match != null && match.group(2) != null) {
      String potentialName = match.group(2)!.trim();
      final commonWords = [
        'أنا', 'لكن', 'هل', 'كيف', 'ماذا', 'من', 'أنت', 'فضفضة', 'أستطيع', 'أريد', 'مساعدتك', 'شكراً', 'أهلاً', 'مرحباً'
      ];
      if (potentialName.split(' ').any((word) => commonWords.contains(word.toLowerCase()))) {
        return null;
      }
      return potentialName.split(' ').first;
    }
    return null;
  }

  /// Helper function to extract marital status from text.
  static String? _extractMaritalStatus(String message) {
    String lowerCaseMessage = message.toLowerCase();
    if (lowerCaseMessage.contains('أنا أعزب') || lowerCaseMessage.contains('غير متزوج')) return 'أعزب';
    if (lowerCaseMessage.contains('أنا متزوج') || lowerCaseMessage.contains('متزوجة')) return 'متزوج';
    if (lowerCaseMessage.contains('أنا مطلق') || lowerCaseMessage.contains('مطلقة')) return 'مطلق';
    if (lowerCaseMessage.contains('أنا أرمل') || lowerCaseMessage.contains('أرملة')) return 'أرمل';
    return null;
  }

  /// Helper function to extract job from text.
  static String? _extractJob(String message) {
    RegExp regExp = RegExp(r'(أعمل كـ|وظيفتي|مهنتي)\s*([\p{L}\s]+)', unicode: true);
    Match? match = regExp.firstMatch(message);
    if (match != null && match.group(2) != null) {
      String job = match.group(2)!.trim();
      if (job.length > 2 && !job.contains('أنا') && !job.contains('لا')) {
        return job;
      }
    }
    return null;
  }

  /// Helper function to extract dreams/ambitions from text.
  static List<String>? _extractDreams(String message) {
    List<String> detectedDreams = [];
    RegExp regExp = RegExp(r'(أحلم بأن|أطمح إلى|أتمنى أن|أرغب في تحقيق)\s*([^\.!\?]+)', unicode: true);
    Iterable<Match> matches = regExp.allMatches(message);
    for (Match m in matches) {
      if (m.group(2) != null) {
        detectedDreams.add(m.group(2)!.trim());
      }
    }
    return detectedDreams.isNotEmpty ? detectedDreams : null;
  }

  /// Helper function to extract impactful experiences from text.
  static List<String>? _extractImpactfulExperiences(String message) {
    List<String> detectedExperiences = [];
    RegExp regExp = RegExp(r'(مررت بتجربة|تجربة غيرت حياتي|أتذكر يوماً|حدث لي موقف مؤثر)\s*([^\.!\?]+)', unicode: true);
    Iterable<Match> matches = regExp.allMatches(message);
    for (Match m in matches) {
      if (m.group(2) != null) {
        detectedExperiences.add(m.group(2)!.trim());
      }
    }
    return detectedExperiences.isNotEmpty ? detectedExperiences : null;
  }

  /// Helper function to extract if user sees a therapist.
  static bool? _extractSeesTherapist(String message) {
    String lowerCaseMessage = message.toLowerCase();
    if (lowerCaseMessage.contains('أراجع طبيب نفسي') || lowerCaseMessage.contains('لدي مرشد نفسي') || lowerCaseMessage.contains('أذهب إلى معالج')) {
      return true;
    }
    if (lowerCaseMessage.contains('لا أراجع طبيب نفسي') || lowerCaseMessage.contains('ليس لدي مرشد نفسي')) {
      return false;
    }
    return null;
  }

  /// Helper function to extract if user takes psychiatric medication.
  static bool? _extractTakesMedication(String message) {
    String lowerCaseMessage = message.toLowerCase();
    if (lowerCaseMessage.contains('أتناول أدوية نفسية') || lowerCaseMessage.contains('وصفت لي أدوية نفسية')) {
      return true;
    }
    if (lowerCaseMessage.contains('لا أتناول أدوية نفسية') || lowerCaseMessage.contains('لا توجد لدي أدوية نفسية')) {
      return false;
    }
    return null;
  }

  /// Helper function to extract hobbies from text.
  static List<String>? _extractHobbies(String message) {
    List<String> detectedHobbies = [];
    RegExp regExp = RegExp(r'(هوايتي|أحب أن|أستمتع بـ)\s*([^\.!\?]+)', unicode: true);
    Iterable<Match> matches = regExp.allMatches(message);
    for (Match m in matches) {
      if (m.group(2) != null) {
        // تقسيم الهوايات إذا كانت متعددة ومفصولة بـ "و" أو ","
        detectedHobbies.addAll(m.group(2)!.split(RegExp(r'\s*و\s*|،\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty));
      }
    }
    return detectedHobbies.isNotEmpty ? detectedHobbies : null;
  }

  /// Helper function to extract important relationships from text.
  /// (This is a simplified example, might need more complex NLP for real-world use)
  static List<String>? _extractImportantRelationships(String message) {
    List<String> detectedRelationships = [];
    String lowerCaseMessage = message.toLowerCase();

    // كلمات مفتاحية للعائلة
    if (lowerCaseMessage.contains('أمي')) detectedRelationships.add('أمي');
    if (lowerCaseMessage.contains('أبي')) detectedRelationships.add('أبي');
    if (lowerCaseMessage.contains('أخي')) detectedRelationships.add('أخي');
    if (lowerCaseMessage.contains('أختي')) detectedRelationships.add('أختي');
    if (lowerCaseMessage.contains('زوجي') || lowerCaseMessage.contains('زوجتي')) detectedRelationships.add('الزوج/الزوجة');
    
    // كلمات مفتاحية للأصدقاء المقربين
    if (lowerCaseMessage.contains('صديقي المقرب') || lowerCaseMessage.contains('صديقتي المقربة')) detectedRelationships.add('صديق مقرب');
    
    // كلمات مفتاحية للأشخاص المؤثرين
    RegExp influentialPersonRegExp = RegExp(r'(شخص مؤثر في حياتي|أثر فيني)\s*([^\.!\?]+)', unicode: true);
    Match? match = influentialPersonRegExp.firstMatch(message);
    if (match != null && match.group(2) != null) {
      detectedRelationships.add(match.group(2)!.trim());
    }

    return detectedRelationships.isNotEmpty ? detectedRelationships.toSet().toList() : null; // toSet().toList() لإزالة التكرارات
  }


  // --- دوال استجابة اختبارية محلية (موجودة لديك أصلاً) ---

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
    if (_apiKey.isEmpty || _apiKey == 'YOUR_FALLBACK_API_KEY_HERE') {
      throw Exception('OpenAI API Key is not configured or is invalid. Please check your .env file in assets.');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
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