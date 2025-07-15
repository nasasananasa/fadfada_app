// lib/screens/user_info_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../models/important_relationship.dart';
import '../services/firestore_service.dart';
import '../widgets/custom_button.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  UserModel? _currentUser;
  bool _isLoading = true;

  late final TextEditingController _displayNameController;
  late final TextEditingController _occupationController;
  late final TextEditingController _currentResidenceController;
  late final TextEditingController _ageController;
  late final TextEditingController _birthPlaceController;
  late final TextEditingController _medicationNameController;

  String? _gender;
  String? _maritalStatus;
  bool _seesTherapist = false;
  bool _takesMedication = false;

  List<String> _lifeChallenges = [];
  List<String> _hobbies = [];
  List<String> _ambitions = [];
  List<String> _sleepingDreams = [];
  Map<String, ImportantRelationship> _importantRelationships = {};

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _occupationController = TextEditingController();
    _currentResidenceController = TextEditingController();
    _ageController = TextEditingController();
    _birthPlaceController = TextEditingController();
    _medicationNameController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _occupationController.dispose();
    _currentResidenceController.dispose();
    _ageController.dispose();
    _birthPlaceController.dispose();
    _medicationNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = await FirestoreService.getUserProfile();
      if (mounted && user != null) {
        
        setState(() {
          _currentUser = user;
          _displayNameController.text = user.displayName ?? '';
          _occupationController.text = user.job ?? '';
          _currentResidenceController.text = user.currentResidence ?? '';
          _ageController.text = user.age?.toString() ?? '';
          _birthPlaceController.text = user.birthPlace ?? '';
          _medicationNameController.text = user.medicationName ?? '';
          
          _gender = user.gender;
          _maritalStatus = user.maritalStatus;

          _seesTherapist = user.seesTherapist ?? false;
          _takesMedication = user.takesMedication ?? false;

          List<String> parseStringList(List<dynamic> list) {
             return list.map((item) {
              if (item is Map && item.containsKey('description')) {
                return item['description'].toString();
              }
              return item.toString();
            }).toList();
          }
          
          _lifeChallenges = parseStringList(user.lifeChallenges);
          _hobbies = parseStringList(user.hobbies);
          _ambitions = parseStringList(user.dreams);
          _sleepingDreams = parseStringList(user.sleepingDreams);

          final Map<String, ImportantRelationship> newRelationships = {};
          for (var item in user.importantRelationships) {
            if (item is Map) {
              final String? name = item['name'];
              final List<String> tags = (item['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              if (name != null && name.isNotEmpty) {
                newRelationships[name] = ImportantRelationship(relations: tags);
              }
            }
          }
          _importantRelationships = newRelationships;

        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Error loading user data in UserInfoScreen: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الملف الشخصي: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> relationshipsToSave = _importantRelationships.entries.map((entry) {
      return {
        'name': entry.key,
        'tags': entry.value.relations,
      };
    }).toList();

    final updatedUser = _currentUser!.copyWith(
      displayName: _displayNameController.text,
      job: _occupationController.text,
      currentResidence: _currentResidenceController.text,
      age: int.tryParse(_ageController.text),
      birthPlace: _birthPlaceController.text,
      gender: _gender,
      maritalStatus: _maritalStatus,
      seesTherapist: _seesTherapist,
      takesMedication: _takesMedication,
      medicationName: _takesMedication ? _medicationNameController.text : null,
      lifeChallenges: _lifeChallenges,
      hobbies: _hobbies,
      dreams: _ambitions,
      sleepingDreams: _sleepingDreams,
      importantRelationships: relationshipsToSave,
    );

    try {
      await FirestoreService.saveUserProfile(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الملف الشخصي بنجاح!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          _currentUser = updatedUser;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الملف الشخصي: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showEditListDialog({
    required String title,
    required List<String> list,
    int? index,
  }) {
    final bool isEditing = index != null;
    final textController = TextEditingController(
      text: isEditing ? list[index] : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل $title' : 'إضافة $title'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'اكتب النص هنا...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final newText = textController.text.trim();
              if (newText.isNotEmpty) {
                setState(() {
                  if (isEditing) {
                    list[index] = newText;
                  } else {
                    list.add(newText);
                  }
                });
              }
              Navigator.of(context).pop();
            },
            child: Text(isEditing ? 'حفظ التعديل' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditRelationshipDialog({String? existingName, ImportantRelationship? existingRelationship}) {
    final bool isEditing = existingName != null && existingRelationship != null;
    final nameController = TextEditingController(text: isEditing ? existingName : '');
    final relationsController = TextEditingController();
    
    final List<String> tempRelations = isEditing ? List<String>.from(existingRelationship.relations) : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل علاقة' : 'إضافة علاقة جديدة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم الشخص', border: OutlineInputBorder()),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    const Text('صفات العلاقة (مثال: صديق، داعم)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: tempRelations.map((relation) {
                        return Chip(
                          label: Text(relation),
                          onDeleted: () {
                            setDialogState(() {
                              tempRelations.remove(relation);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: relationsController,
                            decoration: const InputDecoration(hintText: 'أضف صفة...'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final newRelation = relationsController.text.trim();
                            if (newRelation.isNotEmpty && !tempRelations.contains(newRelation)) {
                              setDialogState(() {
                                tempRelations.add(newRelation);
                                relationsController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
                TextButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) return;
                    
                    setState(() {
                      final newRelationship = ImportantRelationship(relations: tempRelations);
                      if (isEditing) {
                        _importantRelationships.remove(existingName);
                      }
                      _importantRelationships[newName] = newRelationship;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(isEditing ? 'حفظ التعديل' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلوماتي'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? _buildErrorState()
              : _buildProfileForm(),
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionCard(
              title: 'المعلومات الأساسية',
              children: [
                _buildTextFormField(controller: _displayNameController, labelText: 'الاسم المعروض', icon: Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextFormField(controller: _occupationController, labelText: 'المهنة أو الدراسة', icon: Icons.work_outline),
                const SizedBox(height: 16),
                _buildTextFormField(controller: _currentResidenceController, labelText: 'مكان الإقامة الحالي', icon: Icons.location_on_outlined),
              ],
            ),
            const SizedBox(height: 24),

            _buildEditableInfoSection(),
            _buildEditableHealthInfoSection(),
            
            _buildEditableListSection(
              title: 'أبرز التحديات',
              items: _lifeChallenges,
              icon: Icons.report_problem_outlined,
              color: Colors.orange,
              onAdd: () => _showEditListDialog(title: 'تحدي', list: _lifeChallenges),
              onDelete: (index) => setState(() => _lifeChallenges.removeAt(index)),
              onEdit: (index) => _showEditListDialog(title: 'تحدي', list: _lifeChallenges, index: index),
            ),
            _buildEditableListSection(
              title: 'الهوايات والاهتمامات',
              items: _hobbies,
              icon: Icons.palette_outlined,
              color: Colors.teal,
              onAdd: () => _showEditListDialog(title: 'هواية', list: _hobbies),
              onDelete: (index) => setState(() => _hobbies.removeAt(index)),
              onEdit: (index) => _showEditListDialog(title: 'هواية', list: _hobbies, index: index),
            ),
            _buildEditableListSection(
              title: 'الطموحات والأحلام',
              items: _ambitions,
              icon: Icons.flag_outlined,
              color: Colors.purple,
              onAdd: () => _showEditListDialog(title: 'طموح', list: _ambitions),
              onDelete: (index) => setState(() => _ambitions.removeAt(index)),
              onEdit: (index) => _showEditListDialog(title: 'طموح', list: _ambitions, index: index),
            ),
            _buildEditableListSection(
              title: 'أحلام النوم',
              items: _sleepingDreams,
              icon: Icons.nightlight_round,
              color: Colors.indigo,
              onAdd: () => _showEditListDialog(title: 'حلم', list: _sleepingDreams),
              onDelete: (index) => setState(() => _sleepingDreams.removeAt(index)),
              onEdit: (index) => _showEditListDialog(title: 'حلم', list: _sleepingDreams, index: index),
            ),

            _buildRelationshipsSection(),

            const SizedBox(height: 24),
            CustomButton(
              onPressed: _saveProfile,
              text: 'حفظ التغييرات',
              icon: Icons.save,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEditableInfoSection() {
    return _buildSectionCard(
      title: 'نظرة عامة',
      children: [
        _buildTextFormField(
          controller: _ageController, 
          labelText: 'العمر', 
          icon: Icons.cake_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly]
        ),
        const SizedBox(height: 16),
        _buildTextFormField(controller: _birthPlaceController, labelText: 'مكان الولادة', icon: Icons.public_outlined),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          value: _gender,
          labelText: 'الجنس',
          icon: Icons.wc_outlined,
          items: ['ذكر', 'أنثى', 'أفضل عدم القول'],
          onChanged: (value) {
            setState(() {
              _gender = value;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          value: _maritalStatus,
          labelText: 'الحالة الاجتماعية',
          icon: Icons.favorite_border,
          items: ['أعزب', 'متزوج', 'مطلق', 'أرمل', 'غير محدد'],
          onChanged: (value) {
            setState(() {
              _maritalStatus = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildEditableHealthInfoSection() {
    return _buildSectionCard(
      title: 'المعلومات الصحية',
      children: [
        _buildSwitchListTile(
          title: 'أتابع مع معالج نفسي',
          value: _seesTherapist,
          onChanged: (value) {
            setState(() {
              _seesTherapist = value;
            });
          },
          icon: Icons.psychology_outlined,
        ),
        _buildSwitchListTile(
          title: 'أتناول أدوية نفسية حاليًا',
          value: _takesMedication,
          onChanged: (value) {
            setState(() {
              _takesMedication = value;
            });
          },
          icon: Icons.medication_outlined,
        ),
        if (_takesMedication)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: _buildTextFormField(
              controller: _medicationNameController, 
              labelText: 'اسم الدواء (اختياري)', 
              icon: Icons.medication
            ),
          ),
      ],
    );
  }

  Widget _buildTextFormField({ 
    required TextEditingController controller, 
    required String labelText, 
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String? value,
    required String labelText,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isValueValid = value != null && items.contains(value);

    return DropdownButtonFormField<String>(
      value: isValueValid ? value : null,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _buildSwitchListTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
  
  Widget _buildEditableListSection({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
    required VoidCallback onAdd,
    required ValueChanged<int> onDelete,
    required ValueChanged<int> onEdit,
  }) {
    return _buildSectionCard(
      title: title,
      children: [
        if (items.isEmpty) 
          const Center(child: Text('لا توجد عناصر بعد.', style: TextStyle(color: Colors.grey))),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: List.generate(items.length, (index) {
            return InputChip(
              label: Text(items[index]),
              avatar: Icon(icon, color: color, size: 20),
              backgroundColor: color.withAlpha(25), 
              side: BorderSide(color: color.withAlpha(50)),
              onPressed: () => onEdit(index),
              onDeleted: () => onDelete(index),
              deleteIconColor: color,
            );
          }),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إضافة عنصر جديد'),
            onPressed: onAdd,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipsSection() {
    return _buildSectionCard(
      title: 'العلاقات الهامة',
      children: [
        if (_importantRelationships.isEmpty)
          const Center(child: Text('لا توجد علاقات بعد.', style: TextStyle(color: Colors.grey))),
        ..._importantRelationships.entries.map((entry) {
          final String name = entry.key;
          final ImportantRelationship relationship = entry.value;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300)
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: relationship.relations.isNotEmpty
                  ? Text(relationship.relations.join('، '))
                  : const Text('لا توجد صفات', style: TextStyle(fontStyle: FontStyle.italic)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Theme.of(context).primaryColor),
                    onPressed: () => _showEditRelationshipDialog(
                      existingName: name, 
                      existingRelationship: relationship
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                    onPressed: () async {
                      // ✅ FIX: Define context-dependent variables before the async gap.
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: Text('هل أنت متأكد من رغبتك في حذف "$name"؟'),
                          actions: [
                            TextButton(
                              onPressed: () => navigator.pop(false),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () => navigator.pop(true),
                              child: const Text('حذف', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirestoreService.removeImportantRelationship(name);
                          if (mounted) {
                            setState(() {
                              _importantRelationships.remove(name);
                            });
                             // ✅ FIX 4: Set duration
                             scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('تم حذف "$name" بنجاح'), 
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                             // ✅ FIX 5: Set duration
                             scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('حدث خطأ أثناء الحذف: $e'), 
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إضافة علاقة جديدة'),
            onPressed: () => _showEditRelationshipDialog(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    if (children.every((child) => child is SizedBox && child.width == 0 && child.height == 0)) {
        return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          const Text('تعذر تحميل بيانات الملف الشخصي.'),
          const SizedBox(height: 16),
          CustomButton(
            onPressed: _loadUserData,
            text: 'حاول مرة أخرى',
          )
        ],
      ),
    );
  }
}