// lib/models/onboarding_data.dart

import 'onboarding_question.dart';

final List<OnboardingQuestion> onboardingQuestions = [
  OnboardingQuestion(
    userModelKey: 'displayName',
    leadingBotMessage: 'أهلاً بك في "فضفضة"! أنا هنا لمساعدتك. لبداية أفضل، أود أن أطرح عليك بعض الأسئلة لنتعرف على بعضنا البعض بشكل أفضل. هل أنت مستعد؟',
    questionText: 'بدايةً، ما الاسم الذي تحب أن أناديك به؟',
  ),
  OnboardingQuestion(
    userModelKey: 'age',
    questionText: 'جميل! وكم يبلغ عمرك؟',
    answerType: AnswerType.number,
  ),
  OnboardingQuestion(
    userModelKey: 'job',
    questionText: 'شكرًا لك. وما هي مهنتك أو ماذا تدرس حاليًا؟',
  ),
  OnboardingQuestion(
    userModelKey: 'currentResidence',
    questionText: 'أين تقيم حاليًا؟',
  ),
  // --- بداية التعديل: إضافة سؤال بخيارات ---
  OnboardingQuestion(
    userModelKey: 'maritalStatus',
    questionText: 'وما هي حالتك الاجتماعية؟',
    answerType: AnswerType.choice, // تغيير النوع إلى خيارات
    choices: ['أعزب', 'متزوج', 'مطلق', 'أرمل', 'غير محدد'],
  ),
  // --- نهاية التعديل ---
  OnboardingQuestion(
    userModelKey: 'seesTherapist',
    questionText: 'شكرًا لمشاركتك. هل تسمح لي بسؤال آخر؟ هل تتابع مع معالج نفسي حاليًا؟',
    answerType: AnswerType.choice,
    choices: ['نعم', 'لا'],
  ),
  OnboardingQuestion(
    userModelKey: 'hobbies',
    leadingBotMessage: 'رائع، لقد انتهينا من المعلومات الأساسية. الآن لنتحدث عن اهتماماتك.',
    questionText: 'ما هي الهوايات أو الأنشطة التي تستمتع بالقيام بها في وقت فراغك؟ (يمكنك ذكر أكثر من هواية بفصلها بفاصلة)',
  ),
  OnboardingQuestion(
    userModelKey: 'lifeChallenges',
    questionText: 'شكرًا لمشاركتي هذا. هل هناك تحديات أو ضغوطات معينة تواجهها في حياتك حاليًا؟',
  ),
  OnboardingQuestion(
    userModelKey: 'dreams',
    questionText: 'وما هي الطموحات أو الأحلام الكبيرة التي تسعى لتحقيقها في المستقبل؟',
    leadingBotMessage: 'هذا كل شيء في الوقت الحالي! شكرًا لك على مشاركة هذه المعلومات معي. يمكنك دائمًا مراجعتها وتعديلها من ملفك الشخصي.',
  ),
];