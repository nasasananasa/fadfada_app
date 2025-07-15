// lib/models/important_relationship.dart

class ImportantRelationship {
  // تم حذف حقل 'name' لأنه سيكون مفتاح الخريطة
  final List<String> relations;

  ImportantRelationship({
    this.relations = const [],
  });

  // التحويل من JSON
  // يتوقع الآن أن يكون JSON هو الخريطة التي تحتوي على قائمة الصفات مباشرة
  factory ImportantRelationship.fromJson(Map<String, dynamic> json) {
    return ImportantRelationship(
      relations: (json['relations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  // التحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'relations': relations,
    };
  }
}