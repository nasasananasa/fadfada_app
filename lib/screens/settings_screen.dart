// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../widgets/custom_button.dart';
import '../screens/support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _chatHistoryEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await FirestoreService.getUserProfile();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _chatHistoryEnabled = user?.getPreference('chatHistory', true) ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات المستخدم: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_currentUser != null) _buildUserSection(),
                  const SizedBox(height: 24),
                  _buildPrivacySettings(),
                  const SizedBox(height: 24),
                  _buildHelpSection(),
                  const SizedBox(height: 24),
                  _buildDataSettings(),
                  const SizedBox(height: 24),
                  _buildSignOutSection(),
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _currentUser?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخصوصية', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            SwitchListTile(
              title: const Text('حفظ سجل المحادثات'),
              subtitle:
                  const Text('يسمح للذكاء الاصطناعي بتذكر محادثاتك السابقة.'),
              value: _chatHistoryEnabled,
              onChanged: (bool value) {
                setState(() => _chatHistoryEnabled = value);
                _updateUserPreference('chatHistory', value);
              },
              secondary: const Icon(Icons.history),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHelpSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المساعدة', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('الدعم الفني'),
              subtitle: const Text('تواصل معنا أو أبلغ عن مشكلة'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SupportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة البيانات', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title:
                  const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
              onTap: _handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutSection() {
    return CustomButton(
      onPressed: _handleSignOut,
      text: 'تسجيل الخروج',
      icon: Icons.logout,
      backgroundColor: Colors.red[600],
    );
  }

  Future<void> _updateUserPreference(String key, dynamic value) async {
    if (_currentUser == null) return;
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
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // ✅ START: This function has been completely refactored for re-authentication
  Future<void> _handleDeleteAccount() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف الحساب'),
        content: const Text(
          'تحذير: هذا الإجراء لا يمكن التراجع عنه. سيتم حذف حسابك وجميع بياناتك نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text('جارٍ حذف الحساب...'),
          ],
        ),
        duration: Duration(days: 1), // Long duration for loading
      ),
    );

    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();

      if (e.code == 'requires-recent-login') {
        final reauthenticated = await _showReauthenticationDialog();
        if (reauthenticated) {
          // After successful re-authentication, we immediately try again.
          await _reauthenticateAndDelete();
        }
      } else {
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('خطأ في المصادقة: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2), // Slightly longer for errors
        ));
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('حدث خطأ غير متوقع: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2), // Slightly longer for errors
      ));
    }
  }

  Future<bool> _showReauthenticationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (reauthDialogContext) => AlertDialog(
        title: const Text('إجراء أمني مطلوب'),
        content: const Text(
          'هذه عملية حساسة. الرجاء تأكيد هويتك عبر تسجيل الدخول مرة أخرى لإتمام الحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(reauthDialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(reauthDialogContext).pop(true);
            },
            child: const Text('تأكيد ومتابعة'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _reauthenticateAndDelete() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text('يرجى تأكيد هويتك...'),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    try {
      final userCredential = await AuthService.signInWithGoogle();

      if (userCredential != null) {
        // Now that the user is re-authenticated, delete the account immediately.
        await AuthService.deleteAccount();
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('تم حذف الحساب بنجاح.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        // User cancelled the Google Sign-In
        scaffoldMessenger.hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('فشلت عملية إعادة المصادقة: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }
  // ✅ END: Refactoring complete

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              final navigator = Navigator.of(context);
              Navigator.pop(dialogContext);
              try {
                await AuthService.signOut();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في تسجيل الخروج: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 1),
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