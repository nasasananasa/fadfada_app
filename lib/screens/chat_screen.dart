import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/mood.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Mood selectedMood;
  final String? sessionId;

  const ChatScreen({
    super.key,
    required this.selectedMood,
    this.sessionId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _isLoading = true;
  String? _currentSessionId;

  List<Map<String, dynamic>> _previousSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _fetchPreviousSessions();
  }

  Future<void> _initializeChat() async {
    try {
      if (widget.sessionId != null) {
        _currentSessionId = widget.sessionId;
        _loadExistingChat();
      } else {
        _currentSessionId = await FirestoreService.createChatSession(widget.selectedMood.id);
        _addWelcomeMessage();
      }
    } catch (e) {
      print('Error initializing chat: \$e');
      _addWelcomeMessage();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPreviousSessions() async {
  print('⚠️ تم استدعاء _fetchPreviousSessions');
  final sessions = await FirestoreService.getUserChatSessionsOnce();


  print('🔥 عدد الجلسات المحمّلة: ${sessions.length}');
  for (var session in sessions) {
    print('🟢 جلسة: ${session['id']} - ${session['timestamp']}');
  }

  setState(() {
    _previousSessions = sessions;
  });
}


  void _loadExistingChat() {
    if (_currentSessionId != null) {
      FirestoreService.getChatMessages(_currentSessionId!).listen((messages) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
        _scrollToBottom();
      });
    }
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      id: const Uuid().v4(),
      content: _getWelcomeMessage(),
      timestamp: DateTime.now(),
      isFromUser: false,
      sessionId: _currentSessionId,
    );

    setState(() {
      _messages.add(welcomeMessage);
    });

    if (_currentSessionId != null) {
      FirestoreService.addChatMessage(welcomeMessage);
    }
  }

  String _getWelcomeMessage() {
    switch (widget.selectedMood.id) {
      case 'happy':
        return 'أهلاً بك! يسعدني أن أرى أنك تشعر بالسعادة اليوم. شاركني ما الذي يجعلك سعيداً!';
      case 'anxious':
        return 'مرحباً، أفهم أنك تشعر بالقلق الآن. أنا هنا لأستمع إليك وأساعدك. خذ نفساً عميقاً وحدثني عما يقلقك.';
      case 'sad':
        return 'أهلاً بك. أرى أنك تمر بوقت صعب، وأريدك أن تعلم أنني هنا لأستمع إليك. أحياناً يساعد الحديث عن مشاعرنا.';
      case 'stressed':
        return 'مرحباً، أفهم أنك تشعر بالضغط الآن. دعنا نتحدث عما يضغط عليك ونجد طرقاً للتعامل معه معاً.';
      case 'confused':
        return 'أهلاً بك. أرى أنك تشعر بالتشويش، وهذا أمر طبيعي أحياناً. دعنا نتحدث ونرتب الأفكار معاً.';
      case 'tired':
        return 'مرحباً، أرى أنك تشعر بالتعب. من المهم أن نهتم بأنفسنا. حدثني عما استنزف طاقتك.';
      case 'angry':
        return 'أهلاً بك. أفهم أنك تشعر بالغضب الآن. الغضب مشاعر طبيعية، دعنا نتحدث عما يزعجك.';
      case 'peaceful':
        return 'مرحباً! ما أجمل أن تشعر بالسلام الداخلي. شاركني كيف وصلت لهذا الشعور الرائع.';
      default:
        return 'أهلاً بك، صديقي! أنا هنا لأستمع إليك ولأساعدك. حدثني عما تشعر به.';
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      content: messageText,
      timestamp: DateTime.now(),
      isFromUser: true,
      sessionId: _currentSessionId,
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    if (_currentSessionId != null) {
      FirestoreService.addChatMessage(userMessage);
    }

    try {
      final aiResponse = await AIService.sendMessage(
        messageText,
        widget.selectedMood,
        previousMessages: _messages.where((m) => !m.isFromUser).take(5).toList(),
      );

      final aiMessage = ChatMessage(
        id: const Uuid().v4(),
        content: aiResponse,
        timestamp: DateTime.now(),
        isFromUser: false,
        sessionId: _currentSessionId,
      );

      setState(() {
        _messages.add(aiMessage);
        _isTyping = false;
      });

      if (_currentSessionId != null) {
        FirestoreService.addChatMessage(aiMessage);
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ في إرسال الرسالة. يرجى المحاولة مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(selectedMood: widget.selectedMood),
      ),
    );
  }

  void _showSuggestions() {
    final suggestions = AIService.getConversationStarters(widget.selectedMood);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اقتراحات للحديث',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...suggestions.map((suggestion) => ListTile(
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    color: widget.selectedMood.color,
                  ),
                  title: Text(suggestion),
                  onTap: () {
                    Navigator.pop(context);
                    _messageController.text = suggestion;
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح المحادثة'),
        content: const Text('هل أنت متأكد من أنك تريد مسح هذه المحادثة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
              });
              if (_currentSessionId != null) {
                FirestoreService.deleteChatSession(_currentSessionId!);
              }
              Navigator.pop(context);
            },
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشة'),
      ),
      body: Column(
        children: [
          if (_previousSessions.isNotEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: ListView.builder(
                itemCount: _previousSessions.length,
                itemBuilder: (context, index) {
                  final session = _previousSessions[index];
                  final timestamp = session['timestamp']?.toDate();
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text('دردشة ${index + 1}'),
                    subtitle: timestamp != null ? Text('${timestamp.toLocal()}') : null,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            selectedMood: widget.selectedMood,
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
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return const TypingIndicator()
                            .animate()
                            .fadeIn(duration: const Duration(milliseconds: 300));
                      }

                      final message = _messages[index];
                      return ChatBubble(message: message)
                          .animate(delay: Duration(milliseconds: 100 * index))
                          .fadeIn(duration: const Duration(milliseconds: 400))
                          .slideX(
                            begin: message.isFromUser ? 0.3 : -0.3,
                            end: 0,
                          );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 42),
              onPressed: _startNewChat,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: widget.selectedMood.color,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
