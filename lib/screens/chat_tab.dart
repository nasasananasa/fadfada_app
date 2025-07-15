// lib/screens/chat_tab.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fadfada_app/screens/chat_screen.dart';
import 'package:fadfada_app/services/auth_service.dart';
import 'package:fadfada_app/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _chatSessionSubscription;

  bool _isLoading = true;
  String? _error;
  List<QueryDocumentSnapshot> _chatSessions = [];

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((user) {
      if (user == null) {
        _chatSessionSubscription?.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _chatSessions = [];
            _error = 'الرجاء تسجيل الدخول لعرض الدردشات.';
          });
        }
      } else {
        _listenToChatSessions();
      }
    });
  }

  void _listenToChatSessions() {
    if (_chatSessionSubscription == null) {
      setState(() {
        _isLoading = true;
      });
    }

    _chatSessionSubscription?.cancel();

    _chatSessionSubscription = FirebaseFirestore.instance
        .collection('chat_sessions')
        .where('userId', isEqualTo: AuthService.currentUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _chatSessions = snapshot.docs;
            _isLoading = false;
            _error = null;
          });
        }
      },
      onError: (error) {
        debugPrint("Error listening to chat sessions: $error");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'حدث خطأ أثناء تحميل الدردشات.';
          });
        }
      },
    );
  }

  // ✅ START: NEW REFRESH HANDLER FUNCTION
  Future<void> _handleRefresh() async {
    _listenToChatSessions();
    await Future.delayed(const Duration(seconds: 1));
  }
  // ✅ END: NEW REFRESH HANDLER FUNCTION

  @override
  void dispose() {
    _chatSessionSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showEditTitleDialog(QueryDocumentSnapshot session, String currentTitle) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final titleController = TextEditingController(text: currentTitle);
    
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل عنوان الدردشة'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اكتب العنوان الجديد...'),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                navigator.pop(titleController.text.trim());
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      try {
        await FirestoreService.updateChatSessionTitle(session.id, newTitle);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('تم تحديث العنوان بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        debugPrint("Error updating title: $e");
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء حفظ العنوان.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
 
 @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_chatSessions.isEmpty) {
      body = RefreshIndicator( // ✅ Wrap with RefreshIndicator
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
             height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('لا توجد دردشات سابقة.', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator( // ✅ Wrap with RefreshIndicator
        onRefresh: _handleRefresh,
        child: ListView.builder(
          itemCount: _chatSessions.length,
          itemBuilder: (context, index) {
            final session = _chatSessions[index];
            final data = session.data() as Map<String, dynamic>;

            final smartTitle = data['title'] as String?;
            final timestamp = data['lastMessageAt'] as Timestamp?;
            
            final dateSubtitle = timestamp != null
                ? DateFormat('d MMMM, hh:mm a', 'ar').format(timestamp.toDate())
                : '';

            return Dismissible(
              key: Key('chat_session_${session.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red[700],
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.delete_forever, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: const Text(
                        'هل أنت متأكد من رغبتك في حذف هذه الدردشة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) async {
                final sessionId = _chatSessions[index].id;
                final itemTitle = smartTitle ?? dateSubtitle;
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                setState(() {
                  _chatSessions.removeAt(index);
                });
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('تم حذف الدردشة: $itemTitle'),
                    duration: const Duration(seconds: 1),
                  ),
                );
                try {
                  await FirestoreService.deleteChatSession(sessionId);
                  debugPrint(
                      "Successfully deleted session $sessionId from Firestore.");
                } catch (e) {
                  debugPrint(
                      "Failed to delete chat session from Firestore: $e");
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content:
                            Text('فشل في حذف الدردشة من قاعدة البيانات.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: Theme.of(context).primaryColor, size: 30),
                  title: Text(
                    smartTitle ?? 'دردشة...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(dateSubtitle),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      _showEditTitleDialog(session, smartTitle ?? '');
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        sessionId: session.id,
                      ),
                    ));
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدردشات'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_chat',
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ));
        },
        tooltip: 'دردشة جديدة',
        child: const Icon(Icons.add),
      ),
    );
  }
}