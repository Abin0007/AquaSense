import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:aquasense/firebase_options.dart';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:aquasense/services/notifications/local_notification_service.dart';
import 'package:aquasense/services/notifications/push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? DefaultFirebaseOptions.webClientId : null,
  );

  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      return false;
    }
    try {
      final doc = await _db.collection('phoneNumbers').doc(phoneNumber).get();
      return doc.exists;
    } catch (e) {
      debugPrint("Error checking phone number: $e");
      return true;
    }
  }

  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
    required String wardId,
    required String phoneNumber,
    PhoneAuthCredential? credential,
  }) async {
    User? user;
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;

      if (user == null) {
        throw 'Could not create user. Please try again.';
      }

      if (credential != null) {
        await user.linkWithCredential(credential);
      }

      await sendEmailVerification();

      final userDocRef = _db.collection('users').doc(user.uid);
      final phoneDocRef = _db.collection('phoneNumbers').doc(phoneNumber);

      WriteBatch batch = _db.batch();

      batch.set(userDocRef, {
        'name': name,
        'email': email,
        'role': 'citizen',
        'wardId': wardId,
        'phoneNumber': phoneNumber,
        'isPhoneVerified': true,
        'isSystemUser': false,
        'createdAt': FieldValue.serverTimestamp(),
        'hasActiveConnection': false,
        'profileImageUrl': null,
      });

      batch.set(phoneDocRef, {
        'uid': user.uid,
      });

      await batch.commit();

        await PushNotificationService.instance.registerDeviceTokenForUser(user);
        await LocalNotificationService.instance
          .scheduleHydrationRemindersForUser(user.uid);

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') throw 'The password provided is too weak.';
      if (e.code == 'email-already-in-use') throw 'This email address is already registered.';
      throw e.message ?? 'An unknown error occurred.';
    } catch (e) {
      debugPrint("Registration Error: ${e.toString()}");
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDoc = _db.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'role': 'citizen',
            'isSystemUser': false,
            'createdAt': FieldValue.serverTimestamp(),
            'hasActiveConnection': false,
            // ✅ ADDED: Get profile picture from Google account
            'profileImageUrl': user.photoURL,
          });
        }

        await PushNotificationService.instance.registerDeviceTokenForUser(user);
        await LocalNotificationService.instance
            .scheduleHydrationRemindersForUser(user.uid);
      }
      return user;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      throw 'Google Sign-In failed. Please ensure pop-ups are enabled and try again.';
    }
  }

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

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        final userDoc = _db.collection('users').doc(user.uid);
        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          await userDoc.set({
            'name': appleCredential.givenName ?? 'Apple User',
            'email': user.email,
            'role': 'citizen',
            'isSystemUser': false,
            'createdAt': FieldValue.serverTimestamp(),
            'profileImageUrl': null, // Apple does not provide a photo URL
          });
        }

        await PushNotificationService.instance.registerDeviceTokenForUser(user);
        await LocalNotificationService.instance
            .scheduleHydrationRemindersForUser(user.uid);
      }
      return user;
    } catch (e) {
      throw 'Apple Sign-In failed. Please try again.';
    }
  }

  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw 'Could not send verification email. Error: ${e.toString()}';
    }
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(PhoneAuthCredential credential) verificationCompleted,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
    Function(String verificationId)? codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {
        if (codeAutoRetrievalTimeout != null) {
          codeAutoRetrievalTimeout(verificationId);
        }
      },
    );
  }

  Future<void> verifyOtpAndLink({
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
      } else {
        throw 'No user is currently signed in to link the phone number.';
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'credential-already-in-use':
          throw 'This phone number is already linked to another account.';
        case 'invalid-verification-code':
          throw 'Invalid OTP. Please check the code and try again.';
        case 'session-expired':
          throw 'OTP session expired. Please request a new code.';
        default:
          throw e.message ?? 'Failed to verify OTP. (${e.code})';
      }
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Failed to send reset link. Please try again.';
    } catch (e) {
      rethrow;
    }
  }

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

        if (refreshedUser != null) {
        await PushNotificationService.instance
          .registerDeviceTokenForUser(refreshedUser);
        await LocalNotificationService.instance
          .scheduleHydrationRemindersForUser(refreshedUser.uid);
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

  Future<void> logoutUser() async {
    final currentUser = _auth.currentUser;
    try {
      await PushNotificationService.instance.removeDeviceTokenForUser(currentUser);
    } catch (e) {
      debugPrint("FCM Token Removal Error: $e");
    }

    await _auth.signOut();
    try {
      // ✅ FIX: Use disconnect() instead of signOut() to fully clear the Google session token.
      // This prevents the Google Sign-In SDK from hanging on subsequent login attempts.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      }
    } catch (e) {
      debugPrint("Google Disconnect Error: $e");
      // Fallback if disconnect fails for some reason
      await _googleSignIn.signOut();
    }
  }
}