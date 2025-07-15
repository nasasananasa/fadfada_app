// lib/screens/onboarding_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/onboarding_data.dart';
import '../models/onboarding_question.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'dart:async';

class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, dynamic> _userAnswers = {};

  int _currentQuestionIndex = 0;
  bool _isTyping = false;
  bool _isCompleted = false;
  OnboardingQuestion? get _currentQuestion =>
      _isCompleted ? null : onboardingQuestions[_currentQuestionIndex];

  @override
  void initState() {
    super.initState();
    _askQuestion();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onConversationComplete() async {
    setState(() => _isTyping = true);
    _addBotMessage("لحظات من فضلك، أقوم الآن بحفظ بياناتك...");

    try {
      final UserModel? currentUser = await FirestoreService.getUserProfile();
      if (currentUser == null) throw Exception("User profile not found.");

      final Map<String, dynamic> updatedData = {};

      _userAnswers.forEach((key, value) {
        if (key == 'hobbies' || key == 'lifeChallenges' || key == 'dreams') {
          
          List<String> parseComplexList(List<dynamic> list) {
            return list.map((item) {
              if (item is Map && item.containsKey('description')) {
                return item['description'].toString();
              }
              if (item is String) {
                return item;
              }
              return '';
            }).where((s) => s.isNotEmpty).toList();
          }
          
          final List<dynamic> rawExistingList = (key == 'hobbies'
              ? currentUser.hobbies
              : key == 'lifeChallenges'
                  ? currentUser.lifeChallenges
                  : currentUser.dreams);

          final List<String> existingItems = parseComplexList(rawExistingList);

          final List<String> newItems = (value as String)
              .split(RegExp(r'[,،]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          
          final Set<String> combinedSet = {...existingItems, ...newItems};
          updatedData[key] = combinedSet.toList();

        } else if (key == 'seesTherapist') {
          updatedData[key] = (value == 'نعم');
        } else {
          updatedData[key] = value;
        }
      });
      
      final UserModel updatedUser = currentUser.copyWith(
        displayName: updatedData['displayName'],
        age: int.tryParse(updatedData['age'] ?? ''),
        job: updatedData['job'],
        currentResidence: updatedData['currentResidence'],
        maritalStatus: updatedData['maritalStatus'],
        seesTherapist: updatedData['seesTherapist'],
        hobbies: updatedData['hobbies'],
        lifeChallenges: updatedData['lifeChallenges'],
        dreams: updatedData['dreams'],
        isFirstTime: false,
      );

      await FirestoreService.saveUserProfile(updatedUser);

      if (mounted) {
        _addBotMessage("تم حفظ ملفك الشخصي بنجاح! يمكنك الآن العودة إلى القائمة الرئيسية أو إغلاق هذه الشاشة.");
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Error in _onConversationComplete: $e");
        _addBotMessage("عذرًا، حدث خطأ أثناء حفظ بياناتك: $e");
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _askQuestion() {
    if (_currentQuestionIndex >= onboardingQuestions.length) {
      if (!_isCompleted) {
        setState(() => _isCompleted = true);
        _onConversationComplete();
      }
      return;
    }

    final question = onboardingQuestions[_currentQuestionIndex];
    if (question.leadingBotMessage != null && question.leadingBotMessage!.isNotEmpty) {
      _addBotMessage(question.leadingBotMessage!);
    }

    setState(() => _isTyping = true);
    Timer(const Duration(milliseconds: 1200), () {
      if(mounted) {
        _addBotMessage(question.questionText);
        setState(() => _isTyping = false);
      }
    });
  }

  Future<void> _handleAnswer(String answer) async {
    final userId = AuthService.currentUid;
    if (userId == null) return;
    
    final userMessage = ChatMessage(id: const Uuid().v4(), content: answer, timestamp: DateTime.now(), isFromUser: true, userId: userId);
    setState(() {
      _messages.add(userMessage);
      _scrollToBottom();
    });
    _messageController.clear();

    if(_currentQuestion != null) {
      _userAnswers[_currentQuestion!.userModelKey] = answer;
    }
    setState(() => _currentQuestionIndex++);
    
    _askQuestion();
  }

  void _addBotMessage(String text) {
    final userId = AuthService.currentUid;
    if (userId == null) return;
    final botMessage = ChatMessage(id: const Uuid().v4(), content: text, timestamp: DateTime.now(), isFromUser: false, userId: userId);
    if (mounted) {
      setState(() => _messages.add(botMessage));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Widget _buildInputArea() {
    if (_isCompleted) {
      return const SizedBox.shrink();
    }
    
    if (_isTyping) {
       // ✅ FIX: Added the `const` keyword for performance optimization.
       return const Padding(
         padding: EdgeInsets.symmetric(vertical: 24.0),
         child: TypingIndicator(),
       );
    }

    if (_currentQuestion?.answerType == AnswerType.choice) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8.0,
          runSpacing: 8.0,
          children: _currentQuestion!.choices!.map((choice) {
            return ActionChip(
              label: Text(choice),
              onPressed: () => _handleAnswer(choice),
              labelStyle: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
            );
          }).toList(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'اكتب إجابتك هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onSubmitted: (value) {
                if(value.trim().isNotEmpty) _handleAnswer(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              if(_messageController.text.trim().isNotEmpty) {
                _handleAnswer(_messageController.text);
              }
            },
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دردشة تعارف')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }
}