import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // تأكد من استيراد Uuid
import '../models/journal_entry.dart';
import '../models/mood.dart'; // تأكد من استيراد Mood
import '../services/firestore_service.dart'; // تأكد من استيراد FirestoreService
import '../services/auth_service.dart'; // تأكد من استيراد AuthService
import '../widgets/custom_button.dart'; // تأكد من استيراد CustomButton

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

  void _initializeFields() {
    if (widget.entry != null) {
      _titleController.text = widget.entry!.title;
      _contentController.text = widget.entry!.content;
      _tags = List.from(widget.entry!.tags ?? []); // Added null-check for tags
      _selectedMood = widget.entry!.moodId != null
          ? Mood.getMoodById(widget.entry!.moodId!)
          : null;
    }
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
    _tagController.addListener(_onFieldChanged); // Listen to tag changes as well
    // يمكنك إضافة Listener لتغيير المزاج أيضاً
    // إذا كنت تستخدم DropdownButton أو أي عنصر اختيار مزاج آخر يغير الـ _selectedMood
    // فعليك استدعاء _onFieldChanged عند حدوث هذا التغيير.
  }

  void _onFieldChanged() {
    // هذا المنطق بسيط، يجعل _hasChanges صحيحاً بمجرد أي تغيير.
    // للمراجعة الأكثر دقة: يمكنك مقارنة القيم الحالية بالقيم الأصلية لـ widget.entry
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return PopScope( // استخدام PopScope لأنه أحدث من WillPopScope
      canPop: false, // نتحكم بالخروج يدوياً بناءً على _onWillPop
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          // إذا كان زر العودة الافتراضي قد قام بالعملية، فلا تفعل شيئاً.
          // هذا يضمن أن _onWillPop هو الذي يتحكم في السلوك.
          return;
        }
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          if (mounted) Navigator.of(context).pop(true); // نعود للشاشة السابقة
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الخاطرة' : 'خاطرة جديدة'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _saveEntry,
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
                  // عند النقر على "إلغاء"، نعود للشاشة السابقة بدون حفظ
                  CustomButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context, false), 
                    text: 'إلغاء',
                    backgroundColor: Colors.grey[600],
                    width: 100, // يمكن ضبط العرض حسب الحاجة
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
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMood = isSelected ? null : mood;
                  _hasChanges = true; // يتم تحديث الحالة عند تغيير المزاج
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
                          : mood.color.withOpacity(0.2),
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
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
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
    // التأكد من أن widget.entry ليس null قبل الوصول إلى خصائصه
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة محتوى الخاطرة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.currentUid;
      if (userId == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final entry = JournalEntry(
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.entry == null
                ? 'تم حفظ الخاطرة بنجاح'
                : 'تم تحديث الخاطرة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في حفظ الخاطرة: $e'),
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
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true; 

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذير'),
        content:
            const Text('لديك تغييرات غير محفوظة. هل تريد الخروج بدون حفظ؟'),
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

    return result ?? false; 
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }
}
