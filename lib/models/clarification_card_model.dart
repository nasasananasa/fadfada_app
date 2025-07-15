// lib/models/clarification_card_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ClarificationCardModel {
  final String id;
  final String point;
  final String category; // ✅ تمت إضافة حقل التصنيف

  ClarificationCardModel({
    required this.id,
    required this.point,
    required this.category, // ✅ تم تحديث المُنشئ ليشمل التصنيف
  });

  factory ClarificationCardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClarificationCardModel(
      id: doc.id,
      point: data['point'] as String? ?? 'نقطة غير متوفرة',
      
      // ✅ تتم الآن قراءة التصنيف من قاعدة البيانات
      // تم وضع قيمة افتراضية ('general') لتجنب أي خطأ في حال 
      // كانت بعض البطاقات القديمة لا تحتوي على هذا الحقل
      category: data['category'] as String? ?? 'general', 
    );
  }
}