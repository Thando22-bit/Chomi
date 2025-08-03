import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // ✅ Default to dark mode

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadThemeFromFirestore();
  }

  Future<void> _loadThemeFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists || !doc.data()!.containsKey('darkMode')) {
      // ✅ Set default darkMode = true for first-time users
      await docRef.set({'darkMode': true}, SetOptions(merge: true));
      _isDarkMode = true;
    } else {
      _isDarkMode = doc['darkMode'];
    }

    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'darkMode': isDark,
      });
    }
  }
}




