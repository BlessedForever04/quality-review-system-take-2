import 'dart:convert';
import 'package:http/http.dart' as http;

class SimpleHttp {
  String? accessToken;

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final res = await http.get(uri, headers: _headers());
    final body = res.body;
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(json is Map && json['message'] != null ? json['message'].toString() : 'HTTP ${res.statusCode}');
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(Uri uri, Map<String, dynamic> data) async {
    final payload = jsonEncode(data);
    final res = await http.post(uri, headers: _headers(), body: payload);
    final body = res.body;
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(json is Map && json['message'] != null ? json['message'].toString() : 'HTTP ${res.statusCode}');
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putJson(Uri uri, Map<String, dynamic> data) async {
    final payload = jsonEncode(data);
    final res = await http.put(uri, headers: _headers(), body: payload);
    final body = res.body;
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(json is Map && json['message'] != null ? json['message'].toString() : 'HTTP ${res.statusCode}');
    }
    return json as Map<String, dynamic>;
  }

  Future<void> delete(Uri uri) async {
    final res = await http.delete(uri, headers: _headers());
    if (res.statusCode >= 400) {
      final body = res.body;
      final json = body.isNotEmpty ? jsonDecode(body) : {};
      throw Exception(json is Map && json['message'] != null ? json['message'].toString() : 'HTTP ${res.statusCode}');
    }
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }
}
