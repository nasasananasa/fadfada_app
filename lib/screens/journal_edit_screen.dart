// lib/screens/journal_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import '../models/mood.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../services/ai_service.dart';

class JournalEditScreen extends StatefulWidget {
  final JournalEntry? entry;

  const JournalEditScreen({super.key, this.entry});

  @override
  State<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends State<JournalEditScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  List<String> _tags = [];
  Mood? _selectedMood;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _setupChangeListeners();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _contentController.removeListener(_onFieldChanged);
    _tagController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _initializeFields() {
    if (widget.entry != null) {
      _titleController.text = widget.entry!.title;
      _contentController.text = widget.entry!.content;
      _tags = List.from(widget.entry!.tags);
      _selectedMood = widget.entry!.moodId != null
          ? Mood.getById(widget.entry!.moodId!)
          : null;
    }
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _handlePop() async {
    if (!_hasChanges) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذير'),
        content: const Text('لديك تغييرات غير محفوظة. هل تريد الخروج بدون حفظ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('البقاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (shouldPop == true && mounted) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return PopScope(
      canPop: false,
      // ✅ FIX: Used the newer onPopInvokedWithResult instead of the deprecated onPopInvoked
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الخاطرة' : 'خاطرة جديدة'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _saveEntry,
                child: const Text('حفظ'),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الخاطرة (اختياري)',
                  hintText: 'مثال: يوم جميل في الحديقة',
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _contentFocusNode.requestFocus(),
              ),
              const SizedBox(height: 24),
              Text(
                'كيف تشعر الآن؟',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildMoodSelector(),
              const SizedBox(height: 24),
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: null,
                minLines: 8,
                decoration: const InputDecoration(
                  labelText: 'اكتب خاطرتك هنا',
                  hintText: 'عبر عن مشاعرك وأفكارك بحرية...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'العلامات (اختياري)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'أضف كلمات مفتاحية لتسهيل البحث في خواطرك لاحقاً',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 12),
              _buildTagsSection(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: _isLoading ? null : _saveEntry,
                      text: isEditing ? 'حفظ التعديلات' : 'حفظ الخاطرة',
                      icon: Icons.save,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    onPressed: _isLoading ? null : () => _handlePop(),
                    text: 'إلغاء',
                    backgroundColor: Colors.grey[600],
                    width: 100,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isEditing) _buildEntryInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = Mood.getAllMoods();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = _selectedMood?.id == mood.id;

          return Container(
            margin: const EdgeInsets.only(left: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMood = isSelected ? null : mood;
                  _hasChanges = true;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? mood.color
                          : mood.color.withAlpha((255 * 0.2).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: mood.color, width: 2)
                          : null,
                    ),
                    child: Icon(
                      mood.icon,
                      color: isSelected ? Colors.white : mood.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mood.arabicName,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? mood.color : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: 'أضف علامة واضغط Enter',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addTag,
            ),
          ),
          onSubmitted: (_) => _addTag(),
        ),
        const SizedBox(height: 12),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: Theme.of(context).primaryColor.withAlpha((255 * 0.1).round()),
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                    deleteIconColor: Theme.of(context).primaryColor,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildEntryInfo() {
    if (widget.entry == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات الخاطرة',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'تاريخ الإنشاء: ${widget.entry!.formattedDate}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.entry!.updatedAt != null)
            Text(
              'آخر تعديل: ${widget.entry!.updatedAt!.day}/${widget.entry!.updatedAt!.month}/${widget.entry!.updatedAt!.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            'عدد الأحرف: ${_contentController.text.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _hasChanges = true;
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة محتوى الخاطرة'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final JournalEntry entry = JournalEntry(
        id: widget.entry?.id ?? const Uuid().v4(),
        userId: userId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: widget.entry?.createdAt ?? DateTime.now(),
        updatedAt: widget.entry != null ? DateTime.now() : null,
        moodId: _selectedMood?.id,
        tags: _tags,
      );

      if (widget.entry == null) {
        await FirestoreService.createJournalEntry(entry);
      } else {
        await FirestoreService.updateJournalEntry(entry);
      }

      if (entry.title.isEmpty) {
        final generatedTitle = await AIService.generateJournalTitleForJournalEntry(
          journalEntryContent: entry.content,
          journalEntryId: entry.id,
        );

        if (generatedTitle != null && generatedTitle.isNotEmpty) {
          final updatedEntry = entry.copyWith(title: generatedTitle);
          await FirestoreService.updateJournalEntry(updatedEntry);
          if (mounted) {
            setState(() {
              _titleController.text = generatedTitle;
            });
          }
          debugPrint('تم تحديث الخاطرة بالعنوان المُولد: $generatedTitle');
        } else {
          debugPrint('لم يتم توليد عنوان للخاطرة.');
        }
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(widget.entry == null
                ? 'تم حفظ الخاطرة بنجاح'
                : 'تم تحديث الخاطرة بنجاح'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في حفظ الخاطرة: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}