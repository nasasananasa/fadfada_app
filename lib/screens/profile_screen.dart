// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'user_info_screen.dart';
import 'questionnaire_screen.dart';
import 'personality_settings_screen.dart'; // ✅  تم استيراد الشاشة الجديدة

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        children: [
          _buildProfileOption(
            context: context,
            icon: Icons.person_search_outlined,
            title: 'معلوماتي',
            subtitle: 'عرض وتعديل بياناتك الشخصية',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserInfoScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildProfileOption(
            context: context,
            icon: Icons.checklist_rtl_outlined,
            title: 'يا ترى فهمتك صح؟',
            subtitle: 'لاحظت بعض الأمور، هل يمكننا مراجعتها معاً؟',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          // ===================================================================
          // ✅ START: NEW OPTION FOR PERSONALITY SETTINGS
          // ===================================================================
          _buildProfileOption(
            context: context,
            icon: Icons.tune_outlined,
            title: 'تخصيص شخصية فضفضة',
            subtitle: 'تحكم بنبرة الحديث، طول الردود، والمزيد',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalitySettingsScreen()),
              );
            },
          ),
          // ===================================================================
          // ✅ END: NEW OPTION
          // ===================================================================
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 30, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}