// lib/screens/home_screen.dart

import 'package:fadfada_app/screens/chat_screen.dart';
import 'package:fadfada_app/screens/chat_tab.dart';
import 'package:fadfada_app/screens/journal_screen.dart';
import 'package:fadfada_app/screens/profile_screen.dart';
import 'package:fadfada_app/screens/questionnaire_screen.dart';
import 'package:fadfada_app/screens/settings_screen.dart';
import 'package:fadfada_app/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/ai_service.dart'; // ✅ Import AI Service

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await FirestoreService.getUserProfile();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardTab(currentUser: _currentUser),
      const ChatTab(),
      const JournalScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined),
              activeIcon: Icon(Icons.psychology),
              label: 'دردشة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'يومياتي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'ملفي',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  final UserModel? currentUser;
  const DashboardTab({super.key, this.currentUser});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _dailyTip = '...';

  @override
  void initState() {
    super.initState();
    _loadDailyTip();
  }

  // هذه الدالة ستقوم الآن بجلب محتوى جديد في كل مرة يتم استدعاؤها
  Future<void> _loadDailyTip() async {
    // لا حاجة لوضع setState هنا في البداية لجعل التحديث أكثر سلاسة
    try {
      final tip = await AIService.generateDailyTip();
      if (mounted) {
        setState(() {
          _dailyTip = tip;
        });
      }
    } catch (e) {
      debugPrint("Failed to get AI daily tip, using fallback. Error: $e");
      if (mounted) {
        setState(() {
          _dailyTip = _fallbackTip();
        });
      }
    }
  }

  String _fallbackTip() {
    final fallbackTips = [
      'خذ نفساً عميقاً... أنت أقوى مما تعتقد',
      'كل يوم هو فرصة جديدة للبداية',
      'تذكر: من الطبيعي أن تشعر بمشاعر مختلفة',
      'الاهتمام بنفسك ليس أنانية، بل ضرورة',
    ];
    final day = DateTime.now().day;
    return fallbackTips[day % fallbackTips.length];
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = widget.currentUser?.displayName ?? 'صديقي';
    if (hour < 12) {
      return 'صباح الخير يا $name، كيف تشعر اليوم؟';
    } else if (hour < 18) {
      return 'مساء الخير يا $name. ما الذي يدور في بالك؟';
    } else {
      return 'أهلاً بعودتك يا $name. أنا هنا لأستمع.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فضفضة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // ======================= بداية التعديل =======================
      body: RefreshIndicator(
        onRefresh: _loadDailyTip, // عند السحب، يتم استدعاء هذه الدالة
        child: SingleChildScrollView(
          // هذه الخاصية تضمن أن السحب يعمل حتى لو كان المحتوى لا يملأ الشاشة
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildQuestionnaireCard(),
              const SizedBox(height: 24),
              _buildDailyTips(),
            ],
          ),
        ),
      ),
      // ======================= نهاية التعديل =======================
    );
  }

  Widget _buildQuestionnaireCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rtl_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'يا ترى فهمتك صح؟',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'لاحظت بعض الأمور، هل يمكننا مراجعتها معاً؟',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const QuestionnaireScreen()),
                  );
                },
                child: const Text('لنراجع معاً'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withAlpha(200),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ماذا تريد أن تفعل؟',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.psychology,
                title: 'حابب تحكي؟',
                subtitle: 'أنا هنا لأسمعك.',
                color: Colors.blue,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChatScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit,
                title: 'يومياتي',
                subtitle: 'مساحتك الخاصة لترتيب أفكارك.',
                color: Colors.green,
                onTap: () {
                   Navigator.of(context).push(
                     MaterialPageRoute(
                       builder: (context) => const JournalScreen(),
                     ),
                   );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'إلهام اليوم', // تم تغيير العنوان ليعكس المحتوى المتنوع
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _dailyTip,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}