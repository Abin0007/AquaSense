import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ Use your actual Web Client ID here (replace if needed)
  static const String _webClientId =
      "575158481229-1c4g51hrtnfg2imp83u608ur2sdn6n37.apps.googleusercontent.com";

  // ✅ Google Sign-In setup
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
  );

  // ---------------- GOOGLE SIGN IN ----------------
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User canceled
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDoc = _db.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'role': 'citizen',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  // ---------------- APPLE SIGN IN ----------------
  Future<User?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDoc = _db.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'name': appleCredential.givenName ?? 'Apple User',
            'email': user.email,
            'role': 'citizen',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } catch (e) {
      throw 'Apple Sign-In failed: $e';
    }
  }

  // ---------------- HELPERS ----------------
  String _generateNonce([int length = 32]) {
    final random = math.Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // ---------------- EMAIL REGISTRATION ----------------
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
    required String wardId,
    required String phoneNumber,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': 'citizen',
          'wardId': wardId,
          'phoneNumber': phoneNumber,
          'isPhoneVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.sendEmailVerification();
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw 'The password provided is too weak.';
      if (e.code == 'email-already-in-use') throw 'An account already exists for that email.';
      throw e.message ?? 'An unknown error occurred.';
    } catch (e) {
      throw 'Registration failed. Please try again.';
    }
  }

  // ---------------- EMAIL VERIFICATION ----------------
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw 'Could not send verification email. Please try again later.';
    }
  }

  // ---------------- PHONE AUTH ----------------
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.currentUser?.linkWithCredential(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      if (_auth.currentUser != null) {
        await _auth.currentUser!.linkWithCredential(credential);
      }
    } on FirebaseAuthException {
      throw 'Invalid OTP or the code has expired. Please request a new one.';
    }
  }

  // ---------------- PASSWORD RESET ----------------
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') throw 'No user found for that email.';
      throw 'Failed to send reset link. Please try again.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }

  // ---------------- LOGIN ----------------
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      await user?.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser != null && !refreshedUser.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(code: 'email-not-verified');
      }

      return refreshedUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw 'Invalid email or password.';
      }
      if (e.code == 'email-not-verified') {
        throw 'Please verify your email before logging in.';
      }
      throw e.message ?? 'An unknown error occurred.';
    } catch (e) {
      throw 'Login failed. Please try again.';
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logoutUser() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}