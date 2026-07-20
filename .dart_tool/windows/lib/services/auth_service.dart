// services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';

  // Save login data
  static Future<void> saveLoginData({
    required String token,
    required Map<String, dynamic> userData,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(key: _userDataKey, value: json.encode(userData));
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setBool(_rememberMeKey, rememberMe);
  }

  // Save remember me credentials
  static Future<void> saveRememberMeCredentials({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email);
      await _secureStorage.write(key: _savedPasswordKey, value: password);
    } else {
      await prefs.setBool(_rememberMeKey, false);
      await prefs.remove(_savedEmailKey);
      await _secureStorage.delete(key: _savedPasswordKey);
    }
  }

  // Load saved credentials
  static Future<Map<String, String?>> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

    if (rememberMe) {
      final email = prefs.getString(_savedEmailKey) ?? '';
      final password = await _secureStorage.read(key: _savedPasswordKey) ?? '';
      return {'email': email, 'password': password};
    }
    return {'email': '', 'password': ''};
  }

  // Get stored token
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = await _secureStorage.read(key: _userDataKey);
    
    if (userDataString != null) {
      try {
        return json.decode(userDataString) as Map<String, dynamic>;
      } catch (e) {
        print('❌ Error decoding user data: $e');
        return null;
      }
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final token = await getToken();
    
    return isLoggedIn && token != null && token.isNotEmpty;
  }

  // Get user role
  static Future<String?> getUserRole() async {
    final userData = await getUserData();
    return userData?['role']?.toString().toLowerCase();
  }

  // Clear login data (logout)
// In auth_service.dart
static Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Clear all login data
  await _secureStorage.delete(key: _tokenKey);
  await _secureStorage.delete(key: _userDataKey);
  await prefs.setBool(_isLoggedInKey, false);
  
  // Optionally, you might want to keep or clear remember me credentials
  // If you want to clear remember me on logout:
  await prefs.setBool(_rememberMeKey, false);
  await prefs.remove(_savedEmailKey);
  await _secureStorage.delete(key: _savedPasswordKey);
}

  // Update user data (if needed)
  static Future<void> updateUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(key: _userDataKey, value: json.encode(userData));
  }
}