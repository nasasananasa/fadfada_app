import 'package:flutter/material.dart';
import '../screens/mood_selector_screen.dart';
import '../screens/chat_screen.dart';
import '../models/mood.dart';
import '../services/firestore_service.dart'; // **تم التأكد من الاستيراد**

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<Map<String, dynamic>> _previousSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPreviousSessions();
  }

  Future<void> _fetchPreviousSessions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final sessions = await FirestoreService.getUserChatSessionsOnce();

    if (!mounted) return;

    setState(() {
      _previousSessions = sessions;
      _isLoading = false;
    });
  }

  void _startNewChatFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MoodSelectorScreen(
          onMoodSelected: (Mood mood) async {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  selectedMood: mood,
                  onSessionEnd: _handleSessionEnd,
                ),
              ),
            );
          },
        ),
      ),
    );
    _fetchPreviousSessions();
  }

  void _openSession(Map<String, dynamic> session) async {
    final moodId = session['moodId'] ?? 'unknown';
    final mood = Mood.getById(moodId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          selectedMood: mood,
          sessionId: session['id'],
          onSessionEnd: _handleSessionEnd,
        ),
      ),
    );
    _fetchPreviousSessions();
  }

  void _handleSessionEnd() {
    print('✅ تم استدعاء _handleSessionEnd - تحديث الجلسات');
    _fetchPreviousSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشات السابقة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previousSessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'لا توجد دردشات سابقة',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ابدأ محادثة جديدة للتعبير عن مشاعرك',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[500],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _startNewChatFlow,
                        icon: const Icon(Icons.add),
                        label: const Text('ابدأ محادثة جديدة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _previousSessions.length,
                  itemBuilder: (context, index) {
                    final session = _previousSessions[index];
                    final timestamp = session['createdAt']?.toDate();
                    final moodId = session['moodId'] ?? 'unknown';
                    final mood = Mood.getById(moodId);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Icon(mood.icon, color: mood.color, size: 30),
                        title: Text(
                          'جلسة دردشة مع ${mood.arabicName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: timestamp != null
                            ? Text(
                                'بتاريخ: ${timestamp.toLocal().day}/${timestamp.toLocal().month}/${timestamp.toLocal().year} ${timestamp.toLocal().hour}:${timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              )
                            : const Text('تاريخ غير متوفر'),
                        onTap: () => _openSession(session),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('حذف الجلسة'),
                                content: const Text(
                                    'هل أنت متأكد من أنك تريد حذف هذه الجلسة وجميع رسائلها؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await FirestoreService.deleteChatSession(session['id']);
                              _fetchPreviousSessions();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('تم حذف الجلسة بنجاح'),
                                      backgroundColor: Colors.green),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChatFlow,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
