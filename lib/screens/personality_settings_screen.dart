// lib/screens/personality_settings_screen.dart

import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class PersonalitySettingsScreen extends StatefulWidget {
  const PersonalitySettingsScreen({super.key});

  @override
  State<PersonalitySettingsScreen> createState() =>
      _PersonalitySettingsScreenState();
}

class _PersonalitySettingsScreenState extends State<PersonalitySettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    final settings = await FirestoreService.getPersonalitySettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      _settings[key] = value;
    });

    try {
      await FirestoreService.updatePersonalitySetting(key, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _loadSettings(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص شخصية فضفضة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildDropdownSetting(
                  title: 'الجنس اللغوي للمخاطبة',
                  value: _settings['linguistic_gender'] ?? 'male',
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('مذكر')),
                    DropdownMenuItem(value: 'female', child: Text('مؤنث')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateSetting('linguistic_gender', value);
                    }
                  },
                ),
                const Divider(height: 32),
                _buildDropdownSetting(
                  title: 'نبرة الحديث المفضلة',
                  value: _settings['preferred_tone'] ?? 'friendly',
                  items: const [
                    DropdownMenuItem(value: 'friendly', child: Text('ودودة')),
                    DropdownMenuItem(value: 'formal', child: Text('رسمية')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateSetting('preferred_tone', value);
                    }
                  },
                ),
                const Divider(height: 32),
                _buildDropdownSetting(
                  title: 'طول الردود',
                  value: _settings['response_length'] ?? 'medium',
                  items: const [
                    DropdownMenuItem(value: 'short', child: Text('قصيرة')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                    DropdownMenuItem(value: 'detailed', child: Text('مفصلة')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateSetting('response_length', value);
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildDropdownSetting<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }
}