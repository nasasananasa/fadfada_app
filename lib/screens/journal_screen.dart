// lib/screens/journal_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fadfada_app/models/journal_entry.dart';
import 'package:fadfada_app/screens/journal_edit_screen.dart';
import 'package:fadfada_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fadfada_app/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _journalSubscription;

  bool _isLoading = true;
  String? _error;
  List<QueryDocumentSnapshot> _journalDocs = [];

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.authStateChanges.listen((user) {
      if (user == null) {
        _journalSubscription?.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _journalDocs = [];
            _error = 'الرجاء تسجيل الدخول لعرض اليوميات.';
          });
        }
      } else {
        _listenToJournals();
      }
    });
  }

  void _listenToJournals() {
    // Set loading to true only when starting fresh
    if (_journalSubscription == null) {
      setState(() {
        _isLoading = true;
      });
    }

    _journalSubscription?.cancel();

    _journalSubscription = FirebaseFirestore.instance
        .collection('journal_entries')
        .where('userId', isEqualTo: AuthService.currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _journalDocs = snapshot.docs;
            _isLoading = false;
            _error = null;
          });
        }
      },
      onError: (error) {
        debugPrint("Error listening to journals: $error");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'حدث خطأ أثناء تحميل اليوميات.';
          });
        }
      },
    );
  }

  // ✅ START: NEW REFRESH HANDLER FUNCTION
  Future<void> _handleRefresh() async {
    // This function is called when the user pulls down to refresh.
    // We re-trigger the function that listens to the stream.
    // The stream will then fetch the latest data.
    _listenToJournals();
    // We can add a small delay to ensure the refresh indicator is visible
    // for a better user experience, even on fast networks.
    await Future.delayed(const Duration(seconds: 1));
  }
  // ✅ END: NEW REFRESH HANDLER FUNCTION

  @override
  void dispose() {
    _journalSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'لا توجد يوميات بعد',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'انقر على زر + لبدء كتابة أول خاطرة لك',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _journalDocs.length,
      itemBuilder: (context, index) {
        final journal = JournalEntry.fromFirestore(_journalDocs[index]);

        return Dismissible(
          key: Key('journal_entry_${journal.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            final navigator = Navigator.of(context);
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("تأكيد الحذف"),
                  content: const Text("هل أنت متأكد أنك تريد حذف هذه الخاطرة؟"),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => navigator.pop(false),
                      child: const Text("إلغاء"),
                    ),
                    TextButton(
                      onPressed: () => navigator.pop(true),
                      child: const Text("حذف"),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            try {
              await FirestoreService.deleteJournalEntry(journal.id);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text("تم حذف الخاطرة بنجاح"),
                  duration: Duration(seconds: 1),
                ),
              );
            } catch (e) {
              debugPrint("Error deleting journal entry: $e");
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text("فشل حذف الخاطرة: $e"),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: ListTile(
              title: Text(
                journal.title.isNotEmpty
                    ? journal.title
                    : journal.content.length > 50
                        ? '${journal.content.substring(0, 50)}...'
                        : journal.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.5),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  DateFormat('EEEE, d MMMM y', 'ar').format(journal.createdAt),
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(178)),
                ),
              ),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => JournalEditScreen(entry: journal),
                ));
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_journalDocs.isEmpty) {
      // ✅ Wrap empty state with RefreshIndicator as well
      body = RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(),
          ),
        ),
      );
    } else {
      // ✅ Wrap the list with RefreshIndicator
      body = RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildJournalsList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('يومياتي'),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_journal',
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const JournalEditScreen(),
          ));
        },
        tooltip: 'خاطرة جديدة',
        child: const Icon(Icons.add),
      ),
    );
  }
}