import 'package:flutter/material.dart';

class Mood {
  final String id;
  final String name;
  final String arabicName;
  final IconData icon;
  final Color color;
  final String description;

  const Mood({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.icon,
    required this.color,
    required this.description,
  });

  // --- إضافة جديدة: المزاج الافتراضي ---
  /// المزاج المحايد الذي يستخدم عند بدء محادثة جديدة.
  static Mood get general => const Mood(
        id: 'general',
        name: 'General',
        arabicName: 'فضفضة',
        icon: Icons.chat_bubble_outline,
        color: Color(0xFF757575), // Grey 600
        description: 'ابدأ محادثة عن أي شيء يخطر ببالك',
      );
  // --- نهاية الإضافة ---

  // الحالات النفسية المتاحة
  static List<Mood> getAllMoods() {
    return [
      general, // تمت إضافته هنا ليكون متاحاً
      const Mood(
        id: 'happy',
        name: 'Happy',
        arabicName: 'سعيد',
        icon: Icons.sentiment_very_satisfied,
        color: Color(0xFF4CAF50),
        description: 'أشعر بالسعادة والإيجابية',
      ),
      const Mood(
        id: 'anxious',
        name: 'Anxious',
        arabicName: 'قلق',
        icon: Icons.psychology_alt,
        color: Color(0xFFFF9800),
        description: 'أشعر بالقلق والتوتر',
      ),
      const Mood(
        id: 'sad',
        name: 'Sad',
        arabicName: 'حزين',
        icon: Icons.sentiment_very_dissatisfied,
        color: Color(0xFF2196F3),
        description: 'أشعر بالحزن أو الاكتئاب',
      ),
      // ... باقي الأمزجة
    ];
  }

  static Mood getById(String id) {
    // --- تعديل: استخدام المزاج المحايد كقيمة افتراضية ---
    return getAllMoods().firstWhere((mood) => mood.id == id, orElse: () => general);
    // --- نهاية التعديل ---
  }

  // ... باقي الكود يبقى كما هو
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabicName': arabicName,
      'description': description,
    };
  }

  factory Mood.fromJson(Map<String, dynamic> json) {
    return getById(json['id']);
  }
}
