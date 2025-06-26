import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../widgets/custom_button.dart';
import 'package:path_provider/path_provider.dart'; 
import 'dart:io';
import 'package:share_plus/share_plus.dart'; 

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  double _fontSize = 14.0;
  bool _chatHistoryEnabled = true; 
  bool _analyticsEnabled = false; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      int retry = 0;
      while (AuthService.currentUid == null && retry < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        retry++;
      }

      final uid = AuthService.currentUid;
      if (uid != null) {
        final user = await FirestoreService.getUserProfile(); 
        if (mounted && user != null) {
          setState(() {
            _currentUser = user;
            _notificationsEnabled = user.notificationsEnabled;
            _darkModeEnabled = user.isDarkMode;
            _fontSize = user.fontSize;
            _chatHistoryEnabled = user.getPreference('chatHistory', true); 
            _analyticsEnabled = user.getPreference('analytics', false); 
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل بيانات المستخدم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserSection()
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: -0.2, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  _buildDisplaySettings()
                      .animate(delay: const Duration(milliseconds: 200))
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  _buildPrivacySettings()
                      .animate(delay: const Duration(milliseconds: 400))
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  _buildDataSettings()
                      .animate(delay: const Duration(milliseconds: 600))
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 24),
                  
                  _buildAppInfo()
                      .animate(delay: const Duration(milliseconds: 800))
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 32),
                  
                  _buildSignOutSection()
                      .animate(delay: const Duration(milliseconds: 1000))
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
    );
  }

  Widget _buildUserSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _currentUser?.photoURL != null 
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
              child: _currentUser?.photoURL == null 
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 16),
            
            Text(
              _currentUser?.displayName ?? 'مستخدم',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            Text(
              _currentUser?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            
            Text(
              'عضو منذ: ${_currentUser?.createdAt.day}/${_currentUser?.createdAt.month}/${_currentUser?.createdAt.year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إعدادات العرض',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSwitchTile(
              icon: Icons.dark_mode,
              title: const Text('الوضع المظلم'), 
              subtitle: const Text('تفعيل المظهر المظلم للتطبيق'), 
              value: _darkModeEnabled,
              onChanged: (bool value) {
                setState(() {
                  _darkModeEnabled = value;
                });
                _updateUserPreference('darkMode', value);
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('حجم الخط'),
              subtitle: Text('${_fontSize.toInt()}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _fontSize > 12 ? () {
                      setState(() {
                        _fontSize -= 1;
                      });
                      _updateUserPreference('fontSize', _fontSize);
                    } : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _fontSize < 18 ? () {
                      setState(() {
                        _fontSize += 1;
                      });
                      _updateUserPreference('fontSize', _fontSize);
                    } : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الخصوصية والإشعارات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildSwitchTile(
              icon: Icons.notifications,
              title: const Text('الإشعارات'), 
              subtitle: const Text('تلقي إشعارات من التطبيق'), 
              value: _notificationsEnabled,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });
                await _updateUserPreference('notifications', value);
              },
            ),
            
            const Divider(),
            // خيار حفظ سجل المحادثات (تم إعادته من UserModel)
            _buildSwitchTile(
              icon: Icons.history,
              title: const Text('حفظ سجل المحادثات'),
              subtitle: const Text('يسمح للذكاء الاصطناعي بتذكر محادثاتك السابقة لتخصيص الردود.'),
              value: _chatHistoryEnabled,
              onChanged: (bool value) {
                setState(() {
                  _chatHistoryEnabled = value;
                });
                _updateUserPreference('chatHistory', value);
                if (!value) {
                  _showChatHistoryWarning(); // استدعاء الدالة هنا
                }
              },
            ),
            const Divider(),
            // خيار مشاركة بيانات الاستخدام (Analytics)
            _buildSwitchTile(
              icon: Icons.analytics,
              title: const Text('مشاركة بيانات الاستخدام (Analytics)'),
              subtitle: const Text('المساعدة في تحسين التطبيق عن طريق مشاركة البيانات المجهولة.'),
              value: _analyticsEnabled,
              onChanged: (bool value) async {
                setState(() {
                  _analyticsEnabled = value;
                });
                await _updateUserPreference('analytics', value);
              },
            ),
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('سياسة الخصوصية'),
              subtitle: const Text('اطلع على كيفية حماية بياناتك'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showPrivacyPolicy,
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('شروط الاستخدام'),
              subtitle: const Text('اطلع على شروط استخدام التطبيق'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showTermsOfService,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة البيانات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('تصدير بياناتي'),
              subtitle: const Text('تحميل نسخة من جميع بياناتك'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _exportData,
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('تنظيف البيانات'),
              subtitle: const Text('حذف المحادثات والخواطر القديمة'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _cleanupOldData,
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
              subtitle: const Text('حذف حسابك وجميع بياناتك نهائياً'),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حول التطبيق',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('الإصدار'),
              subtitle: const Text('1.0.0'),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('المساعدة والدعم'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/support'),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.rate_review),
              title: const Text('تقييم التطبيق'),
              subtitle: const Text('شاركنا رأيك في متجر التطبيقات'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _rateApp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutSection() {
    return CustomButton(
      onPressed: _signOut,
      text: 'تسجيل الخروج',
      icon: Icons.logout,
      backgroundColor: Colors.red[600],
    );
  }

  // تم تعديل هذه الدالة لتستقبل Widget بدلاً من String لـ title و subtitle
  Widget _buildSwitchTile({
    required IconData icon,
    required Widget title, 
    required Widget subtitle, 
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: title, 
      subtitle: subtitle, 
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Future<void> _updateUserPreference(String key, dynamic value) async {
    if (_currentUser != null) {
      try {
        final updatedUser = _currentUser!.updatePreference(key, value);
        await FirestoreService.saveUserProfile(updatedUser);
        if (mounted) {
          setState(() {
            _currentUser = updatedUser;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حفظ الإعدادات: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // **تمت إضافة هذه الدالة الناقصة**
  void _showChatHistoryWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنبيه: سجل المحادثات'),
        content: const Text(
            'إذا قمت بإيقاف حفظ سجل المحادثات، فلن يتمكن فضفضة من تذكر محادثاتك السابقة لتخصيص الردود. هل أنت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _chatHistoryEnabled = true; // Revert if user cancels
              });
              _updateUserPreference('chatHistory', true); // إعادة التفضيل
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // الاستمرار في تعطيل سجل المحادثات، المنطق تم التعامل معه بالفعل في onChanged
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سياسة الخصوصية'),
        content: const SingleChildScrollView(
          child: Text(
            '''نحن في تطبيق "فضفضة" نقدر خصوصيتك ونلتزم بحماية بياناتك الشخصية.

البيانات التي نجمعها:
• بيانات تسجيل الدخول عبر Google
• محادثاتك مع الذكاء الصناعي
• خواطرك الشخصية
• تفضيلات التطبيق

كيف نحمي بياناتك:
• جميع البيانات مشفرة ومحفوظة بأمان
• لا نشارك بياناتك مع أطراف ثالثة
• يمكنك حذف بياناتك في أي وقت

للاستفسارات: support@fadfada.app''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شروط الاستخدام'),
        content: const SingleChildScrollView(
          child: Text(
            '''باستخدام تطبيق "فضفضة"، فإنك توافق على الشروط التالية:

1. الغرض من التطبيق:
التطبيق مخصص للدعم النفسي الأولي وليس بديلاً عن العلاج المهني.

2. مسؤولياتك:
• استخدام التطبيق بشكل مسؤول
• عدم مشاركة معلومات ضارة أو غير مناسبة
• طلب المساعدة المهنية عند الحاجة

3. حدود المسؤولية:
التطبيق لا يقدم نصائح طبية ولا يحل محل الاستشارة المهنية.

4. التحديثات:
قد نقوم بتحديث هذه الشروط من وقت لآخر.

للاستفسارات: support@fadfada.app''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _exportData() async {
    // عرض مؤشر التحميل
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 16),
              Text('جارٍ تصدير بياناتك...'),
            ],
          ),
          duration: Duration(days: 365), // Show indefinitely
          backgroundColor: Colors.blueAccent,
        ),
      );
    }

    try {
      if (AuthService.currentUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('الرجاء تسجيل الدخول لتصدير بياناتك.'),
                backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final filePath = await FirestoreService.exportUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (filePath.isNotEmpty) {
          await Share.shareXFiles([XFile(filePath)], text: 'بياناتي من تطبيق فضفضة.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم تصدير البيانات بنجاح ومشاركتها!'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('فشل في تصدير البيانات.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cleanupOldData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنظيف البيانات'),
        content: const Text('سيتم حذف المحادثات والخواطر الأقدم من 90 يوماً. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (AuthService.currentUid == null) { 
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('الرجاء تسجيل الدخول لتنظيف بياناتك.'),
                          backgroundColor: Colors.orange),
                    );
                  }
                  return;
                }
                // عرض مؤشر التحميل
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 16),
                          Text('جارٍ تنظيف البيانات...'),
                        ],
                      ),
                      duration: Duration(days: 365), 
                      backgroundColor: Colors.blueAccent,
                    ),
                  );
                }

                await FirestoreService.cleanupOldData();
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تنظيف البيانات القديمة بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في تنظيف البيانات: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('تنظيف'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'تحذير: هذا الإجراء لا يمكن التراجع عنه. سيتم حذف حسابك وجميع بياناتك نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.deleteAccount();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في حذف الحساب: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _rateApp() {
    if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شكراً لك! سيتم توجيهك لمتجر التطبيقات'),
        ),
      );
    }
  }

  void _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) { 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في تسجيل الخروج: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
