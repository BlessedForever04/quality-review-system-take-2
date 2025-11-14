import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';

class AuthController extends GetxController {
  final Rx<AuthUser?> currentUser = Rx<AuthUser?>(null);
  final RxBool isLoading = false.obs;
  final _service = AuthService();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('auth_user');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final user = AuthUser(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        role: data['role'],
        token: data['token'] ?? '',
      );
      _applyToken(user.token);
      currentUser.value = user;
    }
  }

  void _applyToken(String token) {
    if (Get.isRegistered<SimpleHttp>()) {
      Get.find<SimpleHttp>().accessToken = token;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    isLoading.value = true;
    try {
      final user = await _service.login(email, password);
      _applyToken(user.token);
      currentUser.value = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user', jsonEncode(user.toJson()));
      return user;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    currentUser.value = null;
    _applyToken('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user');
  }
}
