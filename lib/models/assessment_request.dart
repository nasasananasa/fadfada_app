// lib/models/assessment_request.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AssessmentRequest {
  final String id; // معرف الطلب
  final String userId; // معرف المستخدم صاحب الطلب
  final DateTime submittedAt; // تاريخ تقديم الطلب
  final String status; // حالة الطلب (مثال: 'pending', 'viewed', 'completed')

  // القسم الأول: نسخة من معلومات المستخدم وقت تقديم الطلب
  final Map<String, dynamic> reviewedInfo;

  // القسم الثاني: ملخص الذكاء الاصطناعي
  final bool sharedAiSummary;
  final String? aiSummary; // الملخص المعدل من قبل المستخدم

  // القسم الثالث: إجابات الأسئلة المكملة
  final String mainReason;
  final List<String> symptoms;
  final String? traumaResponse;
  final String? selfHarmResponse;
  final String? hopes;

  AssessmentRequest({
    required this.id,
    required this.userId,
    required this.submittedAt,
    this.status = 'pending',
    required this.reviewedInfo,
    required this.sharedAiSummary,
    this.aiSummary,
    required this.mainReason,
    required this.symptoms,
    this.traumaResponse,
    this.selfHarmResponse,
    this.hopes,
  });

  // دالة لتحويل الكائن إلى JSON ليتم حفظه في Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'reviewedInfo': reviewedInfo,
      'sharedAiSummary': sharedAiSummary,
      'aiSummary': aiSummary,
      'mainReason': mainReason,
      'symptoms': symptoms,
      'traumaResponse': traumaResponse,
      'selfHarmResponse': selfHarmResponse,
      'hopes': hopes,
    };
  }
}