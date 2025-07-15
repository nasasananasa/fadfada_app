import 'package:fadfada_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// --- هام جداً ---
// قم باستبدال المسارات التالية بالمسارات الصحيحة لشاشاتك
import '../screens/home_screen.dart'; // <--- استبدل هذا بمسار شاشتك الرئيسية
import '../screens/login_screen.dart'; // <--- استبدل هذا بمسار شاشة تسجيل الدخول

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم StreamBuilder للاستماع المستمر لتغيرات حالة المصادقة
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // في حالة انتظار وصول البيانات الأولى
        if (snapshot.hasError) {
          // يمكنك تسجيل الخطأ هنا لتحليله لاحقاً
          debugPrint('AuthWrapper Stream Error: ${snapshot.error}');
          return const Scaffold(
            body: Center(
              child: Text('حدث خطأ ما. الرجاء المحاولة مرة أخرى لاحقاً.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // إذا كانت البيانات تحتوي على مستخدم (مسجل دخوله)
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); // اذهب إلى الشاشة الرئيسية
        }

        // إذا كانت البيانات فارغة (تم تسجيل الخروج أو حذف الحساب)
        return const LoginScreen(); // اذهب إلى شاشة تسجيل الدخول
      },
    );
  }
}
