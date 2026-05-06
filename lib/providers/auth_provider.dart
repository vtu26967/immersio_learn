import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String _errorMessage = "";

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  String get userName => _user?.displayName ?? _user?.email?.split('@')[0] ?? "";
  String get userEmail => _user?.email ?? "";
  String get errorMessage => _errorMessage;

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    try {
      _errorMessage = "";
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "Login failed";
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = "An unexpected error occurred";
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    try {
      _errorMessage = "";
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      await _user?.updateDisplayName(name);
      await _user?.reload();
      _user = _firebaseAuth.currentUser;

      await _firestore.collection('users').doc(_user!.uid).set({
        'uid': _user!.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? "Sign up failed";
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = "An unexpected error occurred";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
      _user = null;
      _errorMessage = "";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Logout failed";
      notifyListeners();
    }
  }
}
