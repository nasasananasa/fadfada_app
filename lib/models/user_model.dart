import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> preferences;
  final bool isFirstTime;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.lastLoginAt,
    this.preferences = const {},
    this.isFirstTime = true,
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
