import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // الحصول على المستخدم الحالي
  static User? get currentUser => _auth.currentUser;

  // تدفق حالة المصادقة
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // تسجيل الدخول بواسطة Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // بدء عملية تسجيل الدخول
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // المستخدم ألغى عملية تسجيل الدخول
        return null;
      }

      // الحصول على تفاصيل المصادقة
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // إنشاء بيانات الاعتماد الجديدة
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول إلى Firebase باستخدام بيانات الاعتماد
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      // حفظ أو تحديث بيانات المستخدم في Firestore
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Google Sign In Error: $e');
      rethrow;
    }
  }

  // تسجيل الخروج
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Sign Out Error: $e');
      rethrow;
    }
  }

  // إنشاء أو تحديث بيانات المستخدم في Firestore
  static Future<void> _createOrUpdateUser(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final userSnapshot = await userDoc.get();

      if (userSnapshot.exists) {
        // تحديث آخر تسجيل دخول
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
      } else {
        // إنشاء مستخدم جديد
        final newUser = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          preferences: UserModel.defaultPreferences,
          isFirstTime: true,
        );

        await userDoc.set(newUser.toJson());
      }
    } catch (e) {
      print('Error creating/updating user: $e');
      rethrow;
    }
  }

  // الحصول على بيانات المستخدم من Firestore
  static Future<UserModel?> getUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // تحديث بيانات المستخدم
  static Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toJson());
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  // تحديث تفضيلات المستخدم
  static Future<void> updateUserPreferences(
      String uid, Map<String, dynamic> preferences) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'preferences': preferences,
      });
    } catch (e) {
      print('Error updating user preferences: $e');
      rethrow;
    }
  }

  // تحديث حالة "أول مرة"
  static Future<void> markNotFirstTime(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isFirstTime': false,
      });
    } catch (e) {
      print('Error updating first time status: $e');
      rethrow;
    }
  }

  // حذف الحساب
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // حذف بيانات المستخدم من Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // حذف جميع المحادثات
        final chatSessions = await _firestore
            .collection('chat_sessions')
            .where('userId', isEqualTo: user.uid)
            .get();
            
        for (final doc in chatSessions.docs) {
          await doc.reference.delete();
        }
        
        // حذف جميع اليوميات
        final journalEntries = await _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: user.uid)
            .get();
            
        for (final doc in journalEntries.docs) {
          await doc.reference.delete();
        }

        // حذف الحساب من Firebase Auth
        await user.delete();
      }
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // التحقق من حالة الاتصال
  static bool get isSignedIn => _auth.currentUser != null;

  // الحصول على UID الحالي
  static String? get currentUid => _auth.currentUser?.uid;
}
