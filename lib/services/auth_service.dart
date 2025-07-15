// lib/services/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static bool get isSignedIn => _auth.currentUser != null;

  static String? get currentUid => _auth.currentUser?.uid;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Sign Out Error: $e');
      rethrow;
    }
  }

  static Future<void> _createOrUpdateUser(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final userSnapshot = await userDoc.get();

      if (userSnapshot.exists) {
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
      } else {
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
      debugPrint('Error creating/updating user: $e');
      rethrow;
    }
  }

  static Future<UserModel?> getUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // ✅ START: This function has been simplified and secured
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    try {
      // The only step needed from the client.
      // On success, the `onUserDeleted` Cloud Function will automatically
      // delete all associated Firestore data with admin privileges.
      await user.delete();
      debugPrint("Successfully triggered account deletion. Backend function will handle data cleanup.");

    } on FirebaseAuthException catch (e) {
      // If the error is 'requires-recent-login', we just rethrow it
      // to be handled by the UI. We do NOT attempt manual deletion.
      debugPrint('Account deletion failed with code: ${e.code}. Rethrowing to UI.');
      rethrow;
    } catch (e) {
      // For any other unexpected error
      debugPrint('An unexpected error occurred during account deletion: $e');
      rethrow;
    }
  }
  // ✅ END: No more manual data deletion from the client.
  // The _deleteUserFirestoreData function has been completely removed.
}