// lib/models/user_model.dart

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

  final int? age;
  final String? maritalStatus;
  final String? job;
  // ✅ *** FIX 1: All List fields are now NON-nullable ***
  final List<dynamic> lifeChallenges;
  final List<dynamic> importantRelationships;
  final String? birthPlace;
  final String? currentResidence;
  final List<dynamic> dreams;
  final List<dynamic> impactfulExperiences;
  final bool? seesTherapist;
  final bool? takesMedication;
  final String? medicationName;
  final Map<String, dynamic>? personalityTestResults;
  final List<dynamic> preferencesList;
  final List<dynamic> hobbies;
  final List<dynamic> profileSummary;
  final String? gender;
  final List<dynamic> sleepingDreams;
  final List<dynamic> preferredTone;
  final List<dynamic> communicationStyle;
  final List<dynamic> emotionalTriggers;
  final List<dynamic> cognitivePatterns;
  final List<dynamic> preferredInteractionTime;
  final List<dynamic> knownSupportNeeds;
  final List<dynamic> growthAreas;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.createdAt,
    this.lastLoginAt,
    this.preferences = const {},
    this.isFirstTime = true,
    this.age,
    this.maritalStatus,
    this.job,
    // ✅ *** FIX 2: All List fields now default to an empty list `const []` ***
    this.lifeChallenges = const [],
    this.importantRelationships = const [],
    this.birthPlace,
    this.currentResidence,
    this.dreams = const [],
    this.impactfulExperiences = const [],
    this.seesTherapist,
    this.takesMedication,
    this.medicationName,
    this.personalityTestResults,
    this.preferencesList = const [],
    this.hobbies = const [],
    this.profileSummary = const [],
    this.gender,
    this.sleepingDreams = const [],
    this.preferredTone = const [],
    this.communicationStyle = const [],
    this.emotionalTriggers = const [],
    this.cognitivePatterns = const [],
    this.preferredInteractionTime = const [],
    this.knownSupportNeeds = const [],
    this.growthAreas = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'preferences': preferences,
      'isFirstTime': isFirstTime,
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
      'medicationName': medicationName,
      'personalityTestResults': personalityTestResults,
      'preferencesList': preferencesList,
      'hobbies': hobbies,
      'profileSummary': profileSummary,
      'gender': gender,
      'sleepingDreams': sleepingDreams,
      'preferredTone': preferredTone,
      'communicationStyle': communicationStyle,
      'emotionalTriggers': emotionalTriggers,
      'cognitivePatterns': cognitivePatterns,
      'preferredInteractionTime': preferredInteractionTime,
      'knownSupportNeeds': knownSupportNeeds,
      'growthAreas': growthAreas,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // This helper function now guarantees a non-nullable list
    List<dynamic> parseDynamicList(dynamic value) {
      if (value is List) {
        return List<dynamic>.from(value);
      }
      return []; // Return an empty list instead of null
    }

    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp?)?.toDate(),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      isFirstTime: json['isFirstTime'] ?? true,
      age: json['age'] as int?,
      maritalStatus: json['maritalStatus'] as String?,
      job: json['job'] as String?,
      birthPlace: json['birthPlace'] as String?,
      currentResidence: json['currentResidence'] as String?,
      seesTherapist: json['seesTherapist'] as bool?,
      takesMedication: json['takesMedication'] as bool?,
      medicationName: json['medicationName'] as String?,
      gender: json['gender'] as String?,
      personalityTestResults: json['personalityTestResults'] as Map<String, dynamic>?,

      // ✅ *** FIX 3: All calls now use the safe parsing function ***
      importantRelationships: parseDynamicList(json['importantRelationships']),
      lifeChallenges: parseDynamicList(json['lifeChallenges']),
      dreams: parseDynamicList(json['dreams']),
      impactfulExperiences: parseDynamicList(json['impactfulExperiences']),
      preferencesList: parseDynamicList(json['preferencesList']),
      hobbies: parseDynamicList(json['hobbies']),
      profileSummary: parseDynamicList(json['profileSummary']),
      sleepingDreams: parseDynamicList(json['sleepingDreams']),
      preferredTone: parseDynamicList(json['preferredTone']),
      communicationStyle: parseDynamicList(json['communicationStyle']),
      emotionalTriggers: parseDynamicList(json['emotionalTriggers']),
      cognitivePatterns: parseDynamicList(json['cognitivePatterns']),
      preferredInteractionTime: parseDynamicList(json['preferredInteractionTime']),
      knownSupportNeeds: parseDynamicList(json['knownSupportNeeds']),
      growthAreas: parseDynamicList(json['growthAreas']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({
      'uid': doc.id,
      ...data,
    });
  }

  // ✅ *** FIX 4: `copyWith` now correctly handles non-nullable list fields ***
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
    bool? isFirstTime,
    int? age,
    String? maritalStatus,
    String? job,
    List<dynamic>? lifeChallenges,
    List<dynamic>? importantRelationships,
    String? birthPlace,
    String? currentResidence,
    List<dynamic>? dreams,
    List<dynamic>? impactfulExperiences,
    bool? seesTherapist,
    bool? takesMedication,
    String? medicationName,
    Map<String, dynamic>? personalityTestResults,
    List<dynamic>? preferencesList,
    List<dynamic>? hobbies,
    List<dynamic>? profileSummary,
    String? gender,
    List<dynamic>? sleepingDreams,
    List<dynamic>? preferredTone,
    List<dynamic>? communicationStyle,
    List<dynamic>? emotionalTriggers,
    List<dynamic>? cognitivePatterns,
    List<dynamic>? preferredInteractionTime,
    List<dynamic>? knownSupportNeeds,
    List<dynamic>? growthAreas,
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
      medicationName: medicationName ?? this.medicationName,
      personalityTestResults: personalityTestResults ?? this.personalityTestResults,
      preferencesList: preferencesList ?? this.preferencesList,
      hobbies: hobbies ?? this.hobbies,
      profileSummary: profileSummary ?? this.profileSummary,
      gender: gender ?? this.gender,
      sleepingDreams: sleepingDreams ?? this.sleepingDreams,
      preferredTone: preferredTone ?? this.preferredTone,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      emotionalTriggers: emotionalTriggers ?? this.emotionalTriggers,
      cognitivePatterns: cognitivePatterns ?? this.cognitivePatterns,
      preferredInteractionTime: preferredInteractionTime ?? this.preferredInteractionTime,
      knownSupportNeeds: knownSupportNeeds ?? this.knownSupportNeeds,
      growthAreas: growthAreas ?? this.growthAreas,
    );
  }
  
  static Map<String, dynamic> get defaultPreferences => {
        'darkMode': false,
        'notifications': true,
        'language': 'ar',
        'fontSize': 14.0,
        'chatHistory': true,
        'analytics': false,
      };

  T getPreference<T>(String key, T defaultValue) {
    return preferences[key] ?? defaultValue;
  }

  UserModel updatePreference(String key, dynamic value) {
    final newPreferences = Map<String, dynamic>.from(preferences);
    newPreferences[key] = value;
    return copyWith(preferences: newPreferences);
  }

  bool get isDarkMode => getPreference('darkMode', false);
  bool get notificationsEnabled => getPreference('notifications', true);
  String get preferredLanguage => getPreference('language', 'ar');
  double get fontSize => getPreference('fontSize', 14.0);
  bool get chatHistoryEnabled => getPreference('chatHistory', true);
}