import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_user.dart';

class AuthService {
  Future<AuthUser> login(String email, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/login');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 400) {
      final msg = body is Map && body['message'] != null ? body['message'].toString() : 'Login failed (${res.statusCode})';
      throw Exception(msg);
    }

    // Token is provided via cookie in backend; also mirror token in a header or body if available.
    // For SPA we need a token value; try to read from Set-Cookie or from a "token" field if backend sends it later.
    String token = '';
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null) {
      final parts = setCookie.split(';');
      final tokenPair = parts.firstWhere((p) => p.trim().startsWith('token='), orElse: () => '');
      if (tokenPair.isNotEmpty) token = tokenPair.split('=').last;
    }

    final data = (body is Map && body['data'] is Map) ? body['data'] as Map<String, dynamic> : <String, dynamic>{};
    return AuthUser.fromJson(data, token: token);
  }
}
