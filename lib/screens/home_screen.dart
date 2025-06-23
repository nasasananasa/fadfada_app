import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/chat_tab.dart';
import '../screens/journal_screen.dart';
import '../screens/support_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserModel? _currentUser;

  final List<Widget> _screens = [
    const DashboardTab(),
    const ChatTab(),
    const JournalScreen(),
    const SupportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = AuthService.currentUid;
    if (uid != null) {
      final user = await AuthService.getUserData(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
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
              icon: Icon(Icons.support_agent_outlined),
              activeIcon: Icon(Icons.support_agent),
              label: 'دعم',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  UserModel? _currentUser;
  late String _selectedGreetingLine;
  String _dailyTip = '...';

  final List<String> _greetingLines = [
    'كيف تشعر اليوم؟ أنا هنا للاستماع إليك.',
    'مرحبًا، هل ترغب في التحدث؟',
    'أنا هنا دائمًا إن احتجت لفضفضة.',
    'لا تحمل كل شيء وحدك… دعني أستمع.',
    'أخبرني بما في داخلك، أنا حاضر.',
    'كل شيء يبدأ بكلمة… لنتحدث.',
    'دعني أرافقك في هذه اللحظة.',
    'اكتب لي، حتى لو لم تكن متأكدًا ممّا تشعر.',
    'لنبدأ بنقطة صغيرة… أنا معك.',
    'لا بأس إن لم تكن بخير… دعنا نبدأ.'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _selectedGreetingLine = (_greetingLines.toList()..shuffle()).first;
    _loadDailyTip();
  }

  Future<void> _loadUserData() async {
    final uid = AuthService.currentUid;
    if (uid != null) {
      final user = await AuthService.getUserData(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  Future<void> _loadDailyTip() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    try {
      final journalSnapshot = await FirebaseFirestore.instance
          .collection('journal_entries')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final sessionSnapshot = await FirebaseFirestore.instance
          .collection('chat_sessions')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final latestJournal = journalSnapshot.docs.isNotEmpty
          ? journalSnapshot.docs.first.data()['content'] ?? ''
          : '';

      final latestSummary = sessionSnapshot.docs.isNotEmpty
          ? sessionSnapshot.docs.first.data()['summary'] ?? ''
          : '';

      final combinedText = '$latestJournal\n$latestSummary'.trim();

      if (combinedText.isEmpty) {
        _dailyTip = _fallbackTip();
      } else {
        print('📢 النص الموحد المرسل إلى GPT:\n$combinedText');
        final apiKey = dotenv.env['OPENAI_API_KEY'];
        final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': [
              {
                'role': 'system',
                'content': 'أنت مساعد نفسي محترف. استخرج نصيحة نفسية قصيرة ومفيدة من هذا النص، باللغة العربية، بطريقة ودية وداعمة.'
              },
              {
                'role': 'user',
                'content': combinedText,
              }
            ],
            'temperature': 0.7,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('🔥 رد GPT الكامل:');
          print(response.body);
          print('✅ النصيحة المولدة من GPT: ${data['choices'][0]['message']['content']}');

          _dailyTip = data['choices'][0]['message']['content'].toString().trim();
        } else {
          _dailyTip = _fallbackTip();
        }
      }
    } catch (e) {
      print('❌ حدث خطأ أثناء الاتصال بـ GPT: $e');
      _dailyTip = _fallbackTip();
    }

    if (mounted) {
      setState(() {});
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildDailyTips(),
            const SizedBox(height: 24),
            _buildStatistics(),
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
              Theme.of(context).primaryColor.withOpacity(0.8),
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentUser?.displayName ?? 'صديقي العزيز',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedGreetingLine,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
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
                title: 'بدء محادثة',
                subtitle: 'تحدث مع صديقك الافتراضي',
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatTab(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit,
                title: 'كتابة خاطرة',
                subtitle: 'سجل أفكارك ومشاعرك',
                color: Colors.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const JournalScreen(),
                  ),
                ),
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
                  color: color.withOpacity(0.1),
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
                  'نصيحة اليوم',
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

  Widget _buildStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إحصائياتك',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'محادثات',
                    value: '12',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.book_outlined,
                    label: 'خواطر',
                    value: '8',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.favorite_outline,
                    label: 'أيام نشطة',
                    value: '15',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 18) {
      return 'مساء الخير';
    } else {
      return 'مساء الخير';
    }
  }
}
