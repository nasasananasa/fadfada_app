import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/mood.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // تأكد من وجود هذا الاستيراد إذا كنت تستخدم AuthService
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Mood selectedMood;
  final String? sessionId;
  final VoidCallback? onSessionEnd; // Callback to notify parent (ChatTab)

  const ChatScreen({
    super.key,
    required this.selectedMood,
    this.sessionId,
    this.onSessionEnd,
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

  // لا يوجد هنا _previousSessions أو أي منطق لعرض قائمة الجلسات السابقة
  // هذه الشاشة مخصصة لعرض جلسة دردشة واحدة فقط.

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      if (widget.sessionId != null) {
        // إذا كان هناك sessionId موجود، قم بتحميل الرسائل لهذه الجلسة
        _currentSessionId = widget.sessionId;
        await _loadExistingChat();
      } else {
        // إذا كانت جلسة جديدة (sessionId هو null)، قم بإنشاء جلسة جديدة.
        // نتأكد من أننا حصلنا على sessionId صالح قبل المتابعة.
        final newSessionId = await FirestoreService.createChatSession(widget.selectedMood.id);
        if (newSessionId != null) {
          _currentSessionId = newSessionId;
          _addWelcomeMessage();
        } else {
          print('Failed to create new chat session. Using a fallback for messages locally.');
          _currentSessionId = null;
          _addWelcomeMessage();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل في بدء جلسة دردشة جديدة. قد لا يتم حفظ الرسائل.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error initializing chat: $e');
      _currentSessionId = null;
      _addWelcomeMessage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تهيئة الدردشة: $e. قد لا يتم حفظ الرسائل.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _loadExistingChat() async {
    if (_currentSessionId != null) {
      FirestoreService.getChatMessages(_currentSessionId!).listen((messages) {
        if (!mounted) return;

        setState(() {
          _messages.clear();
          _messages.addAll(messages);
        });
        _scrollToBottom();
      }, onError: (e) {
        print('Error loading existing chat messages: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل الرسائل: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

    if (_currentSessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إرسال الرسالة: لا توجد جلسة دردشة نشطة لحفظ الرسائل.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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

    await FirestoreService.addChatMessage(userMessage);

    try {
      final aiResponse = await AIService.sendMessage(
        messageText,
        widget.selectedMood,
        previousMessages: _messages.reversed.take(10).toList().reversed.toList(),
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

      await FirestoreService.addChatMessage(aiMessage);
      await FirestoreService.updateChatSessionLastMessageAt(_currentSessionId!, DateTime.now());

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في إرسال الرسالة أو تلقي رد الذكاء الاصطناعي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    Navigator.of(context).pop();
    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
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

  void _handleSessionEndAndPop() {
    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
    Navigator.of(context).pop();
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
            onPressed: () async {
              Navigator.pop(context);

              if (_currentSessionId != null) {
                await FirestoreService.deleteChatSession(_currentSessionId!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم مسح المحادثة بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                 if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لا توجد جلسة لحذفها.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
              _handleSessionEndAndPop();
            },
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleSessionEndAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('الدردشة مع ${widget.selectedMood.arabicName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'بدء محادثة جديدة',
              onPressed: _startNewChat,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'مسح المحادثة',
              onPressed: _clearChat,
            ),
            IconButton(
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: 'اقتراحات للحديث',
              onPressed: _showSuggestions,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty && !_isTyping
                      ? Center(
                          child: Text(
                            'ابدأ محادثتك الأولى مع ${widget.selectedMood.arabicName}!',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        )
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