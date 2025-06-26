import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName; // الاسم المعروض (سيتم حفظ الاسم المستخلص هنا)
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> preferences;
  final bool isFirstTime;

  // --- معلومات الملف الشخصي المخصصة (محدثة وشاملة) ---
  final int? age; // العمر (رقم وليس مجموعة عمرية)
  final String? maritalStatus;
  final String? job; // المهنة/العمل
  final List<String>? lifeChallenges; // التحديات الرئيسية في الحياة/العمل
  final List<String>? importantRelationships; // الأشخاص المقربون والعلاقات المهمة (أفراد العائلة والأصدقاء)
  final String? birthPlace; // مكان الولادة
  final String? currentResidence; // مكان الإقامة
  final List<String>? dreams; // الأحلام والطموحات
  final List<String>? impactfulExperiences; // تجارب لها أثر في الحياة
  final bool? seesTherapist; // هل يراجع طبيب نفسي أو مرشد نفسي
  final bool? takesMedication; // هل يتناول أدوية نفسية
  final Map<String, dynamic>? personalityTestResults; // لحفظ نتائج الاختبارات المختلفة
  final List<String>? preferencesList; // قائمة بالتفضيلات (مثلاً: أنواع الموسيقى، الأفلام)
  final List<String>? hobbies; // الهوايات

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.lastLoginAt,
    this.preferences = const {},
    this.isFirstTime = true,
    // --- إضافة معلومات الملف الشخصي المخصصة هنا ---
    this.age,
    this.maritalStatus,
    this.job,
    this.lifeChallenges,
    this.importantRelationships,
    this.birthPlace,
    this.currentResidence,
    this.dreams,
    this.impactfulExperiences,
    this.seesTherapist,
    this.takesMedication,
    this.personalityTestResults,
    this.preferencesList,
    this.hobbies,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'preferences': preferences,
      'isFirstTime': isFirstTime,
      // --- إضافة معلومات الملف الشخصي المخصصة للـ JSON هنا ---
      'age': age,
      'maritalStatus': maritalStatus,
      'job': job,
      'lifeChallenges': lifeChallenges,
      'importantRelationships': importantRelationships,
      'birthPlace': birthPlace,
      'currentResidence': currentResidence,
      'dreams': dreams,
      'impactfulExperiences': impactfulExperiences,
      'seesTherapist': seesTherapist,
      'takesMedication': takesMedication,
      'personalityTestResults': personalityTestResults,
      'preferencesList': preferencesList,
      'hobbies': hobbies,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp?)?.toDate(),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      isFirstTime: json['isFirstTime'] ?? true,
      // --- إضافة معلومات الملف الشخصي المخصصة هنا ---
      age: json['age'] as int?,
      maritalStatus: json['maritalStatus'] as String?,
      job: json['job'] as String?,
      lifeChallenges: (json['lifeChallenges'] as List<dynamic>?)?.map((e) => e as String).toList(),
      importantRelationships: (json['importantRelationships'] as List<dynamic>?)?.map((e) => e as String).toList(),
      birthPlace: json['birthPlace'] as String?,
      currentResidence: json['currentResidence'] as String?,
      dreams: (json['dreams'] as List<dynamic>?)?.map((e) => e as String).toList(),
      impactfulExperiences: (json['impactfulExperiences'] as List<dynamic>?)?.map((e) => e as String).toList(),
      seesTherapist: json['seesTherapist'] as bool?,
      takesMedication: json['takesMedication'] as bool?,
      personalityTestResults: json['personalityTestResults'] as Map<String, dynamic>?,
      preferencesList: (json['preferencesList'] as List<dynamic>?)?.map((e) => e as String).toList(),
      hobbies: (json['hobbies'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({
      'uid': doc.id,
      ...data,
    });
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    bool? isFirstTime,
    // --- إضافة معلومات الملف الشخصي المخصصة هنا ---
    int? age,
    String? maritalStatus,
    String? job,
    List<String>? lifeChallenges,
    List<String>? importantRelationships,
    String? birthPlace,
    String? currentResidence,
    List<String>? dreams,
    List<String>? impactfulExperiences,
    bool? seesTherapist,
    bool? takesMedication,
    Map<String, dynamic>? personalityTestResults,
    List<String>? preferencesList,
    List<String>? hobbies,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      // --- تمرير المعلومات المخصصة في البناء ---
      age: age ?? this.age,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      job: job ?? this.job,
      lifeChallenges: lifeChallenges ?? this.lifeChallenges,
      importantRelationships: importantRelationships ?? this.importantRelationships,
      birthPlace: birthPlace ?? this.birthPlace,
      currentResidence: currentResidence ?? this.currentResidence,
      dreams: dreams ?? this.dreams,
      impactfulExperiences: impactfulExperiences ?? this.impactfulExperiences,
      seesTherapist: seesTherapist ?? this.seesTherapist,
      takesMedication: takesMedication ?? this.takesMedication,
      personalityTestResults: personalityTestResults ?? this.personalityTestResults,
      preferencesList: preferencesList ?? this.preferencesList,
      hobbies: hobbies ?? this.hobbies,
    );
  }

  // التفضيلات الافتراضية
  static Map<String, dynamic> get defaultPreferences => {
    'darkMode': false,
    'notifications': true,
    'language': 'ar',
    'fontSize': 14.0,
    'chatHistory': true,
    'analytics': false,
  };

  // الحصول على تفضيل معين
  T getPreference<T>(String key, T defaultValue) {
    return preferences[key] ?? defaultValue;
  }

  // تحديث تفضيل معين
  UserModel updatePreference(String key, dynamic value) {
    final newPreferences = Map<String, dynamic>.from(preferences);
    newPreferences[key] = value;
    return copyWith(preferences: newPreferences);
  }

  // التحقق من الإعداد المظلم
  bool get isDarkMode => getPreference('darkMode', false);
  
  // التحقق من تفعيل الإشعارات
  bool get notificationsEnabled => getPreference('notifications', true);
  
  // اللغة المفضلة
  String get preferredLanguage => getPreference('language', 'ar');
  
  // حجم الخط
  double get fontSize => getPreference('fontSize', 14.0);
  
  // حفظ سجل المحادثات
  bool get chatHistoryEnabled => getPreference('chatHistory', true);
}