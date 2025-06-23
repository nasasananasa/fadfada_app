import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/mood.dart';
import '../screens/chat_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart';

class MoodSelectorScreen extends StatefulWidget {
  const MoodSelectorScreen({super.key});

  @override
  State<MoodSelectorScreen> createState() => _MoodSelectorScreenState();
}

class _MoodSelectorScreenState extends State<MoodSelectorScreen> {
  Mood? _selectedMood;
  final List<Mood> _moods = Mood.getAllMoods();
  List<Map<String, dynamic>> _previousSessions = [];
  bool _showMoodList = false;

  @override
  void initState() {
    super.initState();
    _fetchPreviousSessions();
  }

  Future<void> _fetchPreviousSessions() async {
    final sessions = await FirestoreService.getUserChatSessionsOnce();
    setState(() {
      _previousSessions = sessions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشة'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (!_showMoodList && _previousSessions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _previousSessions.length,
                itemBuilder: (context, index) {
                  final session = _previousSessions[index];
                  final timestamp = session['timestamp']?.toDate();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text('دردشة ${index + 1}'),
                      subtitle: timestamp != null ? Text('${timestamp.toLocal()}') : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              selectedMood: Mood.defaultMood(),
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
                    ),
                  );
                },
              ),
            ),

          if (_showMoodList) Expanded(child: _buildMoodList()),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: IconButton(
              icon: Icon(
                _showMoodList ? Icons.close : Icons.add_circle_outline,
                size: 42,
              ),
              onPressed: () {
                setState(() {
                  _showMoodList = !_showMoodList;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.psychology_alt,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                'اختر الحالة التي تصف مشاعرك الآن',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'سيساعدني هذا على فهمك بشكل أفضل وتقديم الدعم المناسب',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _moods.length,
            itemBuilder: (context, index) {
              final mood = _moods[index];
              final isSelected = _selectedMood?.id == mood.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: isSelected ? 4 : 1,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMood = mood;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected ? Border.all(color: mood.color, width: 2) : null,
                        color: isSelected ? mood.color.withOpacity(0.1) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: mood.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              mood.icon,
                              color: mood.color,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mood.arabicName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? mood.color : null,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mood.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: mood.color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            onPressed: _selectedMood != null ? _startChat : null,
            text: 'بدء المحادثة',
            icon: Icons.chat_bubble,
            backgroundColor: _selectedMood?.color ?? Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  void _startChat() {
    if (_selectedMood != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(selectedMood: _selectedMood!),
        ),
      );
    }
  }
}
