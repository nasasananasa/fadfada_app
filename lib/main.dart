// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ تم استيراد الحزمة المطلوبة
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'themes/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/journal_edit_screen.dart';
import 'screens/support_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/assessment_form_screen.dart';
import 'screens/onboarding_screen.dart'; // ✅ تم استيراد الشاشة الجديدة
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'services/active_session_service.dart';
// ملاحظة: لا حاجة لاستيراد firebase_options.dart إذا كان موجودًا في ملف آخر

Future<void> main() async {
  // يضمن تهيئة كل شيء قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp();




  await initializeDateFormatting('ar', null);

  // يقوم بتهيئة حزمة التواريخ للغة العربية
  await initializeDateFormatting('ar', null); 

  // ✅ التحقق مما إذا كان المستخدم قد رأى الشاشات الترحيبية من قبل
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  // ✅ تشغيل التطبيق مع تمرير متغير الشاشات الترحيبية
  runApp(FadfadaApp(hasSeenOnboarding: hasSeenOnboarding)); 
}


class FadfadaApp extends StatefulWidget {
  // ✅ إضافة المتغير لاستقبال الحالة
  final bool hasSeenOnboarding;
  
  const FadfadaApp({super.key, required this.hasSeenOnboarding});

  @override
  State<FadfadaApp> createState() => _FadfadaAppState();
}

class _FadfadaAppState extends State<FadfadaApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _triggerAnalysisOnPause(String sessionId) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      debugPrint("--- [main.dart] Triggering V2 Analysis on pause for session: $sessionId ---");
      await AIService.analyzeConversationV2(sessionId);
    } catch (e) {
      debugPrint("Error triggering analysis on pause: $e");
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      debugPrint("App is paused. Checking for active session to analyze.");
      
      final sessionId = ActiveSessionService.currentSessionId;
      if (sessionId != null) {
        _triggerAnalysisOnPause(sessionId);
      } else {
        debugPrint("No active session found to analyze.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فضفضة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar', 'SA'),
      // ✅ تعديل الشاشة الرئيسية بناءً على متغير hasSeenOnboarding
      home: widget.hasSeenOnboarding ? const AuthWrapper() : const OnboardingScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/journal': (context) => const JournalScreen(),
        '/journal-edit': (context) => const JournalEditScreen(),
        '/support': (context) => const SupportScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/assessment-form': (context) => const AssessmentFormScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        );
      },
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

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