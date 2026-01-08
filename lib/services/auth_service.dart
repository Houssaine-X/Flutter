import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '47334353646-j5t7ll1p8ct8428n844933kg193ohtkn.apps.googleusercontent.com' : null,
  );

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Email and Password
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign Up with Email and Password
  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔵 Starting Google Sign-In flow...');
      
      // 1. Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('⚠️ User cancelled Google Sign-In');
        return null; // User canceled the sign-in
      }
      
      print('✅ Google user obtained: ${googleUser.email}');

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('✅ Got authentication tokens');

      // 3. Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print('✅ Created Firebase credential');

      // 4. Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);
      print('✅ Successfully signed in to Firebase: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error during Google Sign-In: $e');
      throw 'An error occurred during Google Sign-In: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    print('🔴 SignOut called - starting logout process');
    try {
      // Only sign out from Google if user signed in with Google
      if (_auth.currentUser?.providerData.any((info) => info.providerId == 'google.com') ?? false) {
        await _googleSignIn.signOut();
        print('✅ Google sign out successful');
      }
      await _auth.signOut();
      print('✅ Firebase sign out successful');
    } catch (e) {
      print('❌ Error during sign out: $e');
      rethrow;
    }
  }

  // Helper to make Firebase errors user-friendly
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is invalid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}