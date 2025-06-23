import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import '../models/mood.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/journal_entry_card.dart';
import 'journal_edit_screen.dart';
import 'dart:async';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _subscription?.cancel(); // إلغاء الاشتراك السابق
    setState(() => _isLoading = true);

    _subscription = FirestoreService.getUserJournalEntries().listen((entries) {
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _filteredEntries = entries;
        _isLoading = false;
      });
      _applySearch();
    }, onError: (e) {
      if (!mounted) return;
      print('❌ خطأ أثناء تحميل اليوميات: $e');
      setState(() => _isLoading = false);
    });
  }

  void _applySearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredEntries = _entries;
      } else {
        _filteredEntries = _entries.where((entry) {
          final query = _searchQuery.toLowerCase();
          return entry.title.toLowerCase().contains(query) ||
                 entry.content.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('يومياتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewEntry,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'البحث في اليوميات...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _applySearch();
                    },
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _applySearch();
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmptyState()
                    : _buildEntriesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewEntry,
        icon: const Icon(Icons.edit),
        label: const Text('خاطرة جديدة'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: Colors.grey[400],
          )
              .animate()
              .scale(duration: const Duration(milliseconds: 600))
              .fadeIn(),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد خواطر بعد',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          )
              .animate(delay: const Duration(milliseconds: 200))
              .fadeIn()
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'جرب كلمات بحث أخرى'
                : 'ابدأ بكتابة أول خاطرة لك',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: const Duration(milliseconds: 400))
              .fadeIn()
              .slideY(begin: 0.2, end: 0),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 32),
            CustomButton(
              onPressed: _createNewEntry,
              text: 'اكتب خاطرة',
              icon: Icons.edit,
              width: 200,
            )
                .animate(delay: const Duration(milliseconds: 600))
                .fadeIn()
                .slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        return JournalEntryCard(
          entry: entry,
          onTap: () => _editEntry(entry),
          onDelete: () => _deleteEntry(entry),
        )
            .animate(delay: Duration(milliseconds: 100 * index))
            .fadeIn(duration: const Duration(milliseconds: 600))
            .slideX(begin: 0.2, end: 0);
      },
    );
  }

  void _showSearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _searchQuery = 'searching';
      } else {
        _searchQuery = '';
        _searchController.clear();
        _applySearch();
      }
    });
  }

  void _createNewEntry() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const JournalEditScreen(),
      ),
    );
    if (result == true) {
      _loadEntries();
    }
  }

  void _editEntry(JournalEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JournalEditScreen(entry: entry),
      ),
    );
  }

  void _deleteEntry(JournalEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الخاطرة'),
        content: const Text('هل أنت متأكد من أنك تريد حذف هذه الخاطرة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService.deleteJournalEntry(entry.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الخاطرة بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ في حذف الخاطرة: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
