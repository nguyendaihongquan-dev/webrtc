import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _userKey = 'user';

  // Save user to local storage
  Future<void> saveUser(UserInfoEntity user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Get user from local storage
  Future<UserInfoEntity?> getUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_userKey);

    if (userJson == null) return null;

    try {
      return UserInfoEntity.fromJson(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  // Clear user data from local storage
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Demo login - In real app, this would make an API call
  Future<UserInfoEntity?> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // Demo validation
    if (email == 'demo@example.com' && password == 'password') {
      final user = UserInfoEntity(
        uid: '1',
        name: 'Demo User',
        username: email,
        avatar: null,
      );

      await saveUser(user);
      return user;
    }

    return null;
  }

  // Demo registration - In real app, this would make an API call
  Future<UserInfoEntity?> register(
    String name,
    String email,
    String password,
  ) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    final user = UserInfoEntity(
      uid: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      username: email,
      avatar: null,
    );

    await saveUser(user);
    return user;
  }
}
