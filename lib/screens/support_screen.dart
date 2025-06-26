import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_button.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم والمساعدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رسالة ترحيبية
            _buildWelcomeCard(context)
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideY(begin: -0.2, end: 0),
            
            const SizedBox(height: 24),
            
            // أزمات نفسية طارئة
            _buildEmergencySection(context)
                .animate(delay: const Duration(milliseconds: 200))
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 24),
            
            // مصادر الدعم المهني
            _buildProfessionalSupportSection(context)
                .animate(delay: const Duration(milliseconds: 400))
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 24),
            
            // نصائح للعناية بالصحة النفسية
            _buildMentalHealthTipsSection(context)
                .animate(delay: const Duration(milliseconds: 600))
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 24),
            
            // التواصل معنا
            _buildContactSection(context)
                .animate(delay: const Duration(milliseconds: 800))
                .fadeIn(duration: const Duration(milliseconds: 600))
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.favorite,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'أنت لست وحدك',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'نحن نهتم بسلامتك النفسية. إذا كنت تواجه صعوبات، فلا تتردد في طلب المساعدة المهنية.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySection(BuildContext context) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: [
                  Icon(
                    Icons.emergency,
                    color: Colors.red[600],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded( // تم إضافة Expanded هنا
                    child: Text(
                      'حالات الطوارئ النفسية',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                      // يمكنك إضافة overflow هنا إذا كان النص ديناميكياً ويمكن أن يصبح طويلاً جداً
                      // overflow: TextOverflow.ellipsis,
                      // maxLines: 1,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'إذا كنت تفكر في إيذاء نفسك أو الآخرين، يرجى التواصل فوراً مع:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildEmergencyContact(
              context,
              icon: Icons.phone,
              title: 'خط المساعدة النفسية',
              subtitle: '920033360',
              onTap: () => _makePhoneCall('920033360'),
            ),
            const SizedBox(height: 12),
            _buildEmergencyContact(
              context,
              icon: Icons.local_hospital,
              title: 'الطوارئ',
              subtitle: '997',
              onTap: () => _makePhoneCall('997'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalSupportSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_alt,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'الدعم المهني',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'نوصي بشدة بالتواصل مع المختصين للحصول على الدعم المناسب:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              context,
              icon: Icons.person,
              title: 'طبيب نفسي',
              description: 'للتشخيص والعلاج الطبي',
              onTap: () => _showPsychiatristInfo(context),
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              context,
              icon: Icons.chat,
              title: 'مختص نفسي',
              description: 'للعلاج النفسي والاستشارة',
              onTap: () => _showPsychologistInfo(context),
            ),
            const SizedBox(height: 12),
            _buildSupportOption(
              context,
              icon: Icons.group,
              title: 'مجموعات الدعم',
              description: 'للتواصل مع آخرين يمرون بتجارب مشابهة',
              onTap: () => _showSupportGroupsInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentalHealthTipsSection(BuildContext context) {
    final tips = [
      'تحدث مع شخص تثق به عن مشاعرك',
      'مارس الرياضة أو المشي لمدة 30 دقيقة يومياً',
      'احصل على قسط كافٍ من النوم (7-8 ساعات)',
      'تناول طعاماً صحياً ومتوازناً',
      'مارس تقنيات التنفس العميق والتأمل',
      'تجنب الكافيين والكحول',
      'اقضِ وقتاً في الطبيعة',
      'احتفظ بروتين يومي منتظم',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'نصائح للعناية بالصحة النفسية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8, right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تواصل معنا',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لديك اقتراحات أو تحتاج مساعدة تقنية؟',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: () => _sendEmail(),
              text: 'راسلنا',
              icon: Icons.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContact(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.red[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.call, color: Colors.red[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, 
                 color: Theme.of(context).primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@fadfada.app',
      query: 'subject=استفسار من تطبيق فضفضة',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _showPsychiatristInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طبيب نفسي'),
        content: const Text(
          'الطبيب النفسي هو طبيب متخصص يمكنه تشخيص الاضطرابات النفسية ووصف الأدوية عند الحاجة. يُنصح بزيارته في الحالات التي تتطلب تقييماً طبياً شاملاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showPsychologistInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مختص نفسي'),
        content: const Text(
          'المختص النفسي متخصص في العلاج النفسي والاستشارة. يساعدك على فهم مشاعرك وتطوير مهارات التأقلم والتعامل مع التحديات النفسية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSupportGroupsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مجموعات الدعم'),
        content: const Text(
          'مجموعات الدعم توفر مساحة آمنة للتواصل مع أشخاص يمرون بتجارب مشابهة. يمكن أن تكون مفيدة جداً في الشعور بأنك لست وحدك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
