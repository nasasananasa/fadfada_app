// lib/screens/chat_screen.dart

import 'dart:async';
import 'package:fadfada_app/models/chat_message.dart';
import 'package:fadfada_app/models/user_model.dart';
import 'package:fadfada_app/services/active_session_service.dart';
import 'package:fadfada_app/services/ai_service.dart';
import 'package:fadfada_app/services/auth_service.dart';
import 'package:fadfada_app/services/firestore_service.dart';
import 'package:fadfada_app/widgets/chat_bubble.dart';
import 'package:fadfada_app/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final VoidCallback? onSessionEnd;

  const ChatScreen({
    super.key,
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
  StreamSubscription? _messagesSubscription;

  bool _isTyping = false;
  bool _isLoading = true;
  String? _currentSessionId;
  UserModel? _currentUser;
  bool _hasNewMessages = false;
  String? _chatTitle;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _triggerAnalysisOnExit();
    ActiveSessionService.currentSessionId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      final userId = AuthService.currentUid;
      if (userId != null) {
        _currentUser = await FirestoreService.getUserProfile();
      }

      if (widget.sessionId != null) {
        _currentSessionId = widget.sessionId;
        ActiveSessionService.currentSessionId = _currentSessionId;
        _listenToMessages();
        await _fetchChatSessionTitle();
      } else {
        _addWelcomeMessage(isLocalOnly: true);
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      _addWelcomeMessage(isLocalOnly: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _fetchChatSessionTitle() async {
    if (_currentSessionId == null) return;
    try {
      final sessionDoc = await FirestoreService.getChatSession(_currentSessionId!);
      if (mounted) {
        setState(() {
          _chatTitle = sessionDoc?['title'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat session title: $e');
      if (mounted) {
        setState(() {
          _chatTitle = 'خطأ في التحميل';
        });
      }
    }
  }

  void _listenToMessages() {
    if (_currentSessionId == null) return;
    
    _messagesSubscription =
        FirestoreService.getChatMessages(_currentSessionId!).listen((messages) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
      _scrollToBottom();
    }, onError: (e) {
      debugPrint('Error loading chat messages: $e');
      if(mounted) {
        // ✅ FIX 1
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحديث الجلسات: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _addWelcomeMessage({bool isLocalOnly = false}) {
    final userId = AuthService.currentUid;
    if (userId == null) return;

    final welcomeMessage = ChatMessage(
      id: const Uuid().v4(),
      content: _getWelcomeMessage(),
      timestamp: DateTime.now(),
      isFromUser: false,
      sessionId: _currentSessionId,
      userId: userId,
    );
    
    if (isLocalOnly) {
       if (mounted) {
        setState(() {
          _messages.add(welcomeMessage);
        });
      }
    } else {
      FirestoreService.addChatMessage(welcomeMessage);
    }
  }

  String _getWelcomeMessage() {
    final String userName = _currentUser?.displayName ?? 'صديقي';
    return 'أهلاً بك يا $userName! أنا هنا لأستمع إليك. حدثني عما تشعر به.';
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final userId = AuthService.currentUid;
    if (userId == null) {
        // ✅ FIX 2
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('خطأ: المستخدم غير مسجل.'),
          duration: Duration(seconds: 1),
        ));
        return;
    }
    
    setState(() {
      _isTyping = true;
      _hasNewMessages = true; 
    });
    _messageController.clear();

    try {
      if (_currentSessionId == null) {
        final newSessionId = await FirestoreService.createChatSession();
        if (newSessionId == null) {
          throw Exception("Failed to create a new chat session.");
        }
        _currentSessionId = newSessionId;
        ActiveSessionService.currentSessionId = _currentSessionId;
        _listenToMessages();

        final welcomeMessage = _messages.firstWhere((msg) => !msg.isFromUser);
        await FirestoreService.addChatMessage(welcomeMessage.copyWith(sessionId: _currentSessionId));
      }

      final userMessage = ChatMessage(
        id: const Uuid().v4(),
        content: messageText,
        timestamp: DateTime.now(),
        isFromUser: true,
        sessionId: _currentSessionId!,
        userId: userId,
      );
      await FirestoreService.addChatMessage(userMessage);

      final aiResponse = await AIService.sendMessage(
        messageText,
        previousMessages: _messages.reversed.take(10).toList().reversed.toList(),
        currentUser: _currentUser,
        isFirstMessage: !_messages.any((m) => m.isFromUser),
      );

      final aiMessage = ChatMessage(
        id: const Uuid().v4(),
        content: aiResponse,
        timestamp: DateTime.now(),
        isFromUser: false,
        sessionId: _currentSessionId!,
        userId: userId,
      );
      await FirestoreService.addChatMessage(aiMessage);

      _currentUser = await FirestoreService.getUserProfile();

    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        // ✅ FIX 3
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ أثناء الإرسال: $e'),
          duration: const Duration(seconds: 1),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
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

void _triggerAnalysisOnExit() async {
  if (_hasNewMessages && _messages.any((m) => m.isFromUser) && _currentSessionId != null) {
    debugPrint("--- [chat_screen.dart] Triggering background tasks on exit for session: $_currentSessionId ---");
    
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      await Future.wait([
        AIService.analyzeConversationV2(_currentSessionId!),
        AIService.generateChatTitle(_currentSessionId!),
      ]);
      if (mounted) {
        await _fetchChatSessionTitle();
      }
      debugPrint("Background tasks (analysis and title generation) triggered successfully.");
    } catch (e) {
      debugPrint("An error occurred while triggering background tasks: $e");
    }

  } else {
    debugPrint("Analysis and title generation skipped for session: $_currentSessionId (no new messages).");
  }
}

  Future<void> _editChatTitle() async {
    if (_currentSessionId == null) {
      // ✅ FIX 4
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تعديل عنوان جلسة لم تبدأ بعد.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final TextEditingController titleEditController = TextEditingController(text: _chatTitle ?? '');
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final String? newTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تعديل عنوان الدردشة'),
          content: TextField(
            controller: titleEditController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اكتب العنوان الجديد...'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => navigator.pop(titleEditController.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != _chatTitle) {
      try {
        await FirestoreService.updateChatSessionTitle(_currentSessionId!, newTitle);
        if (mounted) {
          setState(() {
            _chatTitle = newTitle;
          });
        }
        // ✅ FIX 5
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('تم تحديث العنوان بنجاح!'),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        debugPrint('Error updating chat title: $e');
        // ✅ FIX 6
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('فشل تحديث العنوان: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        
        if (widget.onSessionEnd != null) {
          widget.onSessionEnd!();
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_chatTitle ?? 'دردشة جديدة'),
          actions: [
            if (_currentSessionId != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editChatTitle,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ChatBubble(message: message);
                      },
                    ),
            ),
            if (_isTyping) const TypingIndicator(),
            Container(
              padding: const EdgeInsets.all(16),
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
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}