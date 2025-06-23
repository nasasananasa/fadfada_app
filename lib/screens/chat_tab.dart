import 'package:flutter/material.dart';
import '../screens/mood_selector_screen.dart';
import '../screens/chat_screen.dart';
import '../models/mood.dart';
import '../services/firestore_service.dart';

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
    final sessions = await FirestoreService.getUserChatSessionsOnce();
    setState(() {
      _previousSessions = sessions;
      _isLoading = false;
    });
  }

  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MoodSelectorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشات السابقة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previousSessions.isEmpty
              ? const Center(child: Text('لا توجد دردشات سابقة'))
              : ListView.builder(
                  itemCount: _previousSessions.length,
                  itemBuilder: (context, index) {
                    final session = _previousSessions[index];
                    final timestamp = session['timestamp']?.toDate();
                    final moodId = session['moodId'] ?? 'unknown';
                    final mood = Mood.getById(moodId);

                    return ListTile(
                      leading: Icon(mood.icon, color: mood.color),
                      title: Text('دردشة ${index + 1}'),
                      subtitle: timestamp != null ? Text('${timestamp.toLocal()}') : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              selectedMood: mood,
                              sessionId: session['id'],
                            ),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirestoreService.deleteChatSession(session['id']);
                          _fetchPreviousSessions();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
