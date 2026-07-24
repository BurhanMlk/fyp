/// Firebase implementation of [IAuthRepository].
/// Wraps Firebase Auth SDK calls.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../i_auth_repository.dart';
import '../../models/user_model.dart';

class FirebaseAuthRepository implements IAuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  Future<UserModel?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;

    // Fetch user profile from Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(user.uid, doc.data() ?? {});
    }
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? email,
      contact: '',
      bloodGroup: '',
      role: 'user',
      location: '',
    );
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) return null;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken!,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) return null;

    // Check if user exists in Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(user.uid, doc.data() ?? {});
    }

    // Create new user profile
    final email = user.email ?? googleUser.email;
    final name = user.displayName ?? googleUser.displayName ?? (email.split('@').first);
    final newUser = UserModel(
      id: user.uid,
      name: name,
      email: email,
      contact: '',
      bloodGroup: '',
      role: 'donor',
      location: '',
    );
    await _firestore.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'contact': '',
      'bloodGroup': '',
      'role': 'donor',
      'location': '',
      'approved': false,
      'isDonor': true,
      'verificationStatus': 'not_uploaded',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return newUser;
  }

  @override
  Future<UserModel?> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      name: '',
      email: user.email ?? email,
      contact: '',
      bloodGroup: '',
      role: 'user',
      location: '',
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(user.uid, doc.data() ?? {});
      }
    } catch (_) {}
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      contact: '',
      bloodGroup: '',
      role: 'user',
      location: '',
    );
  }

  @override
  Future<bool> isSignedIn() async {
    return _auth.currentUser != null;
  }

  @override
  Stream<UserModel?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromFirestore(user.uid, doc.data() ?? {});
        }
      } catch (_) {}
      return UserModel(
        id: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        contact: '',
        bloodGroup: '',
        role: 'user',
        location: '',
      );
    });
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
    }
  }
}
