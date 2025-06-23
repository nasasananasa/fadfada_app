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

  // الحالات النفسية المتاحة
  static List<Mood> getAllMoods() {
    return [
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
      const Mood(
        id: 'stressed',
        name: 'Stressed',
        arabicName: 'متوتر',
        icon: Icons.warning_amber,
        color: Color(0xFFF44336),
        description: 'أشعر بالضغط والتوتر',
      ),
      const Mood(
        id: 'confused',
        name: 'Confused',
        arabicName: 'مشوش',
        icon: Icons.help_outline,
        color: Color(0xFF9C27B0),
        description: 'أشعر بالتشويش وعدم الوضوح',
      ),
      const Mood(
        id: 'tired',
        name: 'Tired',
        arabicName: 'متعب',
        icon: Icons.bedtime,
        color: Color(0xFF607D8B),
        description: 'أشعر بالتعب والإرهاق',
      ),
      const Mood(
        id: 'angry',
        name: 'Angry',
        arabicName: 'غاضب',
        icon: Icons.sentiment_very_dissatisfied,
        color: Color(0xFFE91E63),
        description: 'أشعر بالغضب والانزعاج',
      ),
      const Mood(
        id: 'peaceful',
        name: 'Peaceful',
        arabicName: 'هادئ',
        icon: Icons.spa,
        color: Color(0xFF00BCD4),
        description: 'أشعر بالهدوء والسلام الداخلي',
      ),
    ];
  }

  static Mood? getMoodById(String id) {
    try {
      return getAllMoods().firstWhere((mood) => mood.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabicName': arabicName,
      'description': description,
    };
  }

  factory Mood.fromJson(Map<String, dynamic> json) {
    final mood = getMoodById(json['id']);
    if (mood != null) {
      return mood;
    }
    
    // إذا لم نجد الحالة، نعيد حالة افتراضية
    return getAllMoods().first;
  }
}
