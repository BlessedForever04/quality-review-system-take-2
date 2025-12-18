import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_user.dart';

class AuthService {
  Future<AuthUser> login(String email, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 400) {
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Login failed (${res.statusCode})';
      throw Exception(msg);
    }

    // Extract token from response body (backend now includes it)
    final data = (body is Map && body['data'] is Map)
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    String token = data['token']?.toString() ?? '';

    return AuthUser.fromJson(data, token: token);
  }
}
