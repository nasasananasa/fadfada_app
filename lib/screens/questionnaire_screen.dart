// lib/screens/questionnaire_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // استيراد حزمة الماركدون
import '../models/clarification_card_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  
  late Future<List<ClarificationCardModel>> _cardsFuture;
  List<ClarificationCardModel> _localCards = [];
  int _cardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardsFuture = FirestoreService.getPendingSummaryCardsOnce();
  }

  // ===================================================================
  // ✅ START: MODIFIED CARD ACTION HANDLER
  // ===================================================================
  Future<void> _handleCardAction({
    required ClarificationCardModel card,
    required String action,
    String? editedText,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Text('جارٍ التنفيذ...'),
          ],
        ),
        duration: Duration(minutes: 1),
      ),
    );

    try {
      // --- START: Save confirmed fact to user_memory ---
      // If the action is 'confirm', we save the fact to the new collection.
      if (action == 'confirm') {
        // Use the edited text if available, otherwise use the original card text.
        // Clean the text to get the core fact.
        final String factContent = editedText ?? card.point.split(':').last.trim().replaceAll('**', '');
        
        // We assume the card object has a 'category' field.
        await FirestoreService.addUserFact(
          content: factContent,
          category: card.category, 
        );
      }
      // --- END: Save confirmed fact to user_memory ---

      // This call likely just updates the status of the card in 'pending_summaries'.
      await AIService.actionOnSummaryCard(
        cardId: card.id,
        action: action,
        editedText: editedText,
      );

      if (mounted) {
        setState(() {
          _localCards.removeWhere((c) => c.id == card.id);
          if (_cardIndex >= _localCards.length && _localCards.isNotEmpty) {
            _cardIndex = _localCards.length - 1;
          }
        });
      }

    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
      }
    }
  }
  // ===================================================================
  // ✅ END: MODIFIED CARD ACTION HANDLER
  // ===================================================================


  // --- دالة التعديل المحدثة ---
  // تم تعديل هذه الدالة لتنظيف النص قبل عرضه للمستخدم
  void _showEditDialog(ClarificationCardModel card) {
    final String cleanText = card.point
        .replaceFirst('اقتراح:', '')
        .replaceAll('**', '')
        .replaceAll("'", '')
        .trim();

    final textController = TextEditingController(text: cleanText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل وتأكيد المعلومة'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('حفظ'),
            onPressed: () {
              final newText = textController.text.trim();
              Navigator.of(context).pop();
              if (newText.isNotEmpty) {
                // When saving, the action is 'confirm'
                _handleCardAction(card: card, action: 'confirm', editedText: newText);
              }
            },
          ),
        ],
      ),
    );
  }
  
  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if(mounted) {
      setState(() {
        _cardIndex = currentIndex ?? 0;
      });
    }
    return true;
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // --- شاشة النهاية المحدثة ---
  Widget _buildFinishedScreen() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
            SizedBox(height: 24),
            Text(
              'بكل مرة منحكي بفهمك اكتر.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'بامكانك بأي وقت تعدل او تحذف ذاكرتي عنك من ملفك الشخصي قسم معلوماتي.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الاستنتاجات'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<ClarificationCardModel>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          
          if (_localCards.isEmpty && snapshot.hasData && snapshot.data!.isNotEmpty) {
              _localCards = snapshot.data!;
          }
          
          if (_localCards.isEmpty) {
            return _buildFinishedScreen();
          }
          
          return Column(
            children: [
              Expanded(
                child: CardSwiper(
                  controller: _swiperController,
                  cardsCount: _localCards.length,
                  onSwipe: _onSwipe,
                  numberOfCardsDisplayed: (_localCards.length > 1) ? 2 : 1,
                  // --- تصميم البطاقة المحدث ---
                  // تم تعديل هذا الجزء لفصل العنوان عن المحتوى
                  cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                    if (index >= _localCards.length) {
                      return Container();
                    }
                    final card = _localCards[index];

                    String title = 'استنتاج';
                    String body = card.point;

                    if (card.point.contains(':')) {
                      title = card.point.split(':')[0];
                      body = card.point.split(':')[1];
                    }

                    return Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyan.shade300,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Theme(
                              data: ThemeData(textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white)),
                              child: MarkdownBody(
                                data: body,
                                softLineBreak: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                                  strong: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                child: Column(
                  children: [
                    const Text("هل هذه المعلومة صحيحة؟", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filled(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              if (_cardIndex < _localCards.length) {
                                _handleCardAction(card: _localCards[_cardIndex], action: 'delete');
                              }
                            },
                            iconSize: 40,
                            style: IconButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade700)
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            if (_cardIndex < _localCards.length) {
                              _showEditDialog(_localCards[_cardIndex]);
                            }
                          },
                          iconSize: 30,
                        ),
                        IconButton.filled(
                            icon: const Icon(Icons.check_rounded),
                            onPressed: () {
                              if (_cardIndex < _localCards.length) {
                                // When pressing check, the action is 'confirm'
                                _handleCardAction(card: _localCards[_cardIndex], action: 'confirm');
                              }
                            },
                            iconSize: 40,
                            style: IconButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade700)
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}