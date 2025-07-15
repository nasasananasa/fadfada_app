// lib/models/onboarding_question.dart

// تحديث أنواع الإجابات لتكون أكثر وضوحاً
enum AnswerType {
  text, // إجابة نصية عامة
  number, // إجابة رقمية (مثل العمر)
  choice, // اختيار من قائمة أزرار
}

class OnboardingQuestion {
  final String userModelKey;
  final String questionText;
  final AnswerType answerType;
  final String? leadingBotMessage;

  // --- بداية الإضافة: قائمة الخيارات ---
  final List<String>? choices;
  // --- نهاية الإضافة ---

  OnboardingQuestion({
    required this.userModelKey,
    required this.questionText,
    this.answerType = AnswerType.text,
    this.leadingBotMessage,
    this.choices, // إضافة الخيارات إلى المُنشئ
  });
}