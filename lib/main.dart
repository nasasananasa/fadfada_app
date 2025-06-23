import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'themes/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mood_selector_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/journal_edit_screen.dart';
import 'screens/support_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

await dotenv.load(fileName: "assets/.env");

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('خطأ في تهيئة Firebase: $e');
  }

  runApp(const FadfadaApp());
}


class FadfadaApp extends StatelessWidget {
  const FadfadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فضفضة',
      debugShowCheckedModeBanner: false,
      
      // الثيم
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      
      // إعداد الـ locale للغة العربية
      locale: const Locale('ar', 'SA'),
      
      // الصفحة الرئيسية
      home: const SplashScreen(),
      
      // المسارات
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/mood-selector': (context) => const MoodSelectorScreen(),
        '/journal': (context) => const JournalScreen(),
        '/journal-edit': (context) => const JournalEditScreen(),
        '/support': (context) => const SupportScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      
      // معالج المسارات غير المعروفة
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        );
      },
      
      // إعدادات أخرى
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, // اتجاه النص من اليمين إلى اليسار
          child: child!,
        );
      },
    );
  }
}

// Widget للتحقق من حالة المصادقة
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}