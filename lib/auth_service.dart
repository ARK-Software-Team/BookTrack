// lib/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/log_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  String? displayName;
  String? preferredCity;
  String? preferredDistrict;

  AuthService() {
    _auth.authStateChanges().listen((event) async {
      user = event;
      if (event != null) {
        await _loadProfile(event.uid);
      } else {
        displayName = null;
        preferredCity = null;
        preferredDistrict = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      displayName = data?['displayName'] as String?;
      preferredCity = data?['preferredCity'] as String?;
      preferredDistrict = data?['preferredDistrict'] as String?;
    } catch (_) {}
  }

  Future<void> updateDisplayName(String name) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({'displayName': name, 'updatedAt': FieldValue.serverTimestamp()});
    displayName = name;
    notifyListeners();

    // Log
    await LogService().addLog(
      userId: user!.uid,
      type: LogType.bookStatusChanged,
      description: 'Kullanıcı adı "$name" olarak güncellendi.',
    );
  }

  Future<void> updateLocation(String? city, String? district) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({
      'preferredCity': city,
      'preferredDistrict': district,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    preferredCity = city;
    preferredDistrict = district;
    notifyListeners();

    // Log
    if (city != null) {
      await LogService().addLog(
        userId: user!.uid,
        type: LogType.bookStatusChanged,
        description: 'Varsayılan konum "$city${district != null ? " / $district" : ""}" olarak güncellendi.',
      );
    }
  }

  Future<String?> register(String email, String password,
      {String displayName = ''}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      user = cred.user;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
        'userId': user!.uid,
        'email': email,
        'displayName': displayName,
        'preferredCity': null,
        'preferredDistrict': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'stats': {
          'totalBooks': 0,
          'booksRead': 0,
          'currentlyReading': 0,
          'wantToRead': 0,
          'totalPagesRead': 0,
        },
      });
      this.displayName = displayName;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      user = cred.user;
      await _loadProfile(user!.uid);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    user = null;
    displayName = null;
    preferredCity = null;
    preferredDistrict = null;
    notifyListeners();
  }
}