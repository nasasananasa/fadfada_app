// lib/screens/assessment_form_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/assessment_request.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart'; 

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key});

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  UserModel? _currentUser;
  bool _shareAiSummary = true;

  late final TextEditingController _aiSummaryController;
  late final TextEditingController _mainReasonController;
  late final TextEditingController _hopesController;

  final Set<String> _selectedSymptoms = {};
  String? _traumaResponse;
  String? _selfHarmResponse;

  @override
  void initState() {
    super.initState();
    _aiSummaryController = TextEditingController();
    _mainReasonController = TextEditingController();
    _hopesController = TextEditingController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _aiSummaryController.dispose();
    _mainReasonController.dispose();
    _hopesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = await FirestoreService.getUserProfile();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _aiSummaryController.text = user?.profileSummary.join('\n\n') ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ✅ FIX 1: Corrected the SnackBar call and set duration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في جلب بيانات الملف الشخصي: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_isSubmitting || _currentUser == null) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final requestId = const Uuid().v4();
      final userId = AuthService.currentUid!;

      final Map<String, dynamic> reviewedInfo = {
        'name': _currentUser!.displayName,
        'age': _currentUser!.age,
        'gender': _currentUser!.gender,
        'maritalStatus': _currentUser!.maritalStatus,
        'job': _currentUser!.job,
        'takesMedication': _currentUser!.takesMedication,
        'medicationName': _currentUser!.medicationName,
        'seesTherapist': _currentUser!.seesTherapist,
      };

      final request = AssessmentRequest(
        id: requestId,
        userId: userId,
        submittedAt: DateTime.now(),
        reviewedInfo: reviewedInfo,
        sharedAiSummary: _shareAiSummary,
        aiSummary: _shareAiSummary ? _aiSummaryController.text : null,
        mainReason: _mainReasonController.text,
        symptoms: _selectedSymptoms.toList(),
        traumaResponse: _traumaResponse,
        selfHarmResponse: _selfHarmResponse,
        hopes: _hopesController.text,
      );

      try {
        await FirestoreService.submitAssessmentRequest(request);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تم بنجاح'),
              content: const Text('لقد تم إرسال طلبك. سيتم التواصل معك في أقرب وقت ممكن.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          // ✅ FIX 2: Set duration for the error SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      // ✅ FIX 3: Set duration for the validation SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إكمال الحقول المطلوبة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSummary = _aiSummaryController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب لقاء - تقييم أولي'),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null 
            ? _buildErrorState()
            : _buildForm(hasSummary),
      bottomNavigationBar: _isLoading || _currentUser == null
          ? null 
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                onPressed: _submitForm,
                text: 'إرسال الطلب',
                isLoading: _isSubmitting,
              ),
            ),
    );
  }

  Widget _buildForm(bool hasSummary) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('القسم الأول: مراجعة معلوماتك'),
            const SizedBox(height: 8),
            const Text(
              'يرجى مراجعة المعلومات التالية. إذا احتجت لتعديلها، يمكنك العودة إلى شاشة "ملفي الشخصي".',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildReviewInfoSection(), 
            const Divider(height: 40),

            if (hasSummary) ...[
              _buildSectionTitle('القسم الثاني: ملخص الحالة (اختياري)'),
              const SizedBox(height: 8),
              _buildAiSummarySection(),
              const Divider(height: 40),
            ],

            _buildSectionTitle('القسم الثالث: أسئلة مكملة'),
            const SizedBox(height: 8),
            _buildQuestionsSection(), 
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildReviewInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow('الاسم', _currentUser?.displayName, Icons.person_outline),
            _buildInfoRow('العمر', _currentUser?.age?.toString(), Icons.cake_outlined),
            _buildInfoRow('الجنس', _currentUser?.gender, Icons.wc_outlined),
            _buildInfoRow('مكان الإقامة', _currentUser?.currentResidence, Icons.location_on_outlined),
            _buildInfoRow('المهنة', _currentUser?.job, Icons.work_outline),
            _buildInfoRow('الحالة الاجتماعية', _currentUser?.maritalStatus, Icons.favorite_border),
            _buildInfoRow('تتناول دواء نفسي؟', (_currentUser?.takesMedication ?? false) ? 'نعم، (${_currentUser?.medicationName})' : 'لا', Icons.medication_outlined),
            _buildInfoRow('تتابع مع مختص نفسي؟', (_currentUser?.seesTherapist ?? false) ? 'نعم' : 'لا', Icons.psychology_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text('$title:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'غير محدد',
              style: TextStyle(color: Colors.grey[800]),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummarySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نقترح عليك الملخص التالي بناءً على محادثاتك. يمكنك تعديله بحرية قبل المشاركة:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aiSummaryController,
              maxLines: null, 
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            CheckboxListTile(
              title: const Text('أوافق على مشاركة هذا الملخص مع الطبيب'),
              value: _shareAiSummary,
              onChanged: (bool? value) {
                setState(() {
                  _shareAiSummary = value ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsSection() {
    final List<String> symptoms = ['قلق', 'اكتئاب', 'مشاكل نوم', 'نوبات هلع', 'غضب', 'فقدان شغف'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionTitle('ما السبب الرئيسي الذي يدفعك الآن لطلب دعم نفسي؟'),
            TextFormField(
              controller: _mainReasonController,
              decoration: const InputDecoration(hintText: 'اكتب هنا...'),
              validator: (value) => (value == null || value.isEmpty) ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 24),

            _buildQuestionTitle('هل تعاني حاليًا من أعراض معينة؟ (اختر ما ينطبق)'),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: symptoms.map((symptom) {
                final bool isSelected = _selectedSymptoms.contains(symptom);
                return FilterChip(
                  label: Text(symptom),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedSymptoms.add(symptom);
                      } else {
                        _selectedSymptoms.remove(symptom);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            _buildQuestionTitle('هل مررت بتجارب صادمة أو مؤلمة في الماضي؟'),
            _buildSegmentedOptions(
              value: _traumaResponse,
              options: ['نعم', 'لا', 'لا أرغب بالإجابة'],
              onChanged: (value) => setState(() => _traumaResponse = value),
            ),
            const SizedBox(height: 24),

            _buildQuestionTitle('هل تراودك أفكار مزعجة أو مؤذية لنفسك؟'),
            _buildSegmentedOptions(
              value: _selfHarmResponse,
              options: ['نعم', 'لا', 'أحيانًا'],
              onChanged: (value) => setState(() => _selfHarmResponse = value),
            ),
            const SizedBox(height: 24),

            _buildQuestionTitle('ما الذي تأمل أن يساعدك به الطبيب؟'),
            TextFormField(
              controller: _hopesController,
              decoration: const InputDecoration(hintText: 'اكتب هنا...'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuestionTitle(String title){
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSegmentedOptions({
    required String? value, 
    required List<String> options, 
    required ValueChanged<String?> onChanged
  }) {
    return SegmentedButton<String>(
      segments: options.map((label) {
        return ButtonSegment<String>(
          value: label,
          label: Text(label),
        );
      }).toList(),
      selected: value != null ? {value} : {},
      onSelectionChanged: (Set<String> newSelection) {
        onChanged(newSelection.firstOrNull);
      },
      emptySelectionAllowed: true,
      style: SegmentedButton.styleFrom(
        fixedSize: const Size.fromHeight(40),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'عفوًا، لم نتمكن من تحميل بيانات ملفك الشخصي. يرجى التأكد من أن لديك اتصال بالإنترنت والمحاولة مرة أخرى.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: _loadInitialData,
              text: 'حاول مرة أخرى',
            )
          ],
        ),
      ),
    );
  }
}