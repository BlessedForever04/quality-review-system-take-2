import 'dart:convert';
import 'package:http/http.dart' as http;

class SimpleHttp {
  String? accessToken;

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final res = await http.get(uri, headers: _headers());
    final body = res.body;
    // Guard against HTML or non-JSON responses
    if (_looksLikeHtml(body)) {
      throw Exception(
        'Non-JSON response (HTML) from ${uri.toString()} status=${res.statusCode}',
      );
    }
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    final payload = jsonEncode(data);
    final res = await http.post(uri, headers: _headers(), body: payload);
    final body = res.body;
    if (_looksLikeHtml(body)) {
      throw Exception(
        'Non-JSON response (HTML) from ${uri.toString()} status=${res.statusCode}',
      );
    }
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putJson(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    final payload = jsonEncode(data);
    final res = await http.put(uri, headers: _headers(), body: payload);
    final body = res.body;
    if (_looksLikeHtml(body)) {
      throw Exception(
        'Non-JSON response (HTML) from ${uri.toString()} status=${res.statusCode}',
      );
    }
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchJson(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    final payload = jsonEncode(data);
    final res = await http.patch(uri, headers: _headers(), body: payload);
    final body = res.body;
    if (_looksLikeHtml(body)) {
      throw Exception(
        'Non-JSON response (HTML) from ${uri.toString()} status=${res.statusCode}',
      );
    }
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return json as Map<String, dynamic>;
  }

  Future<void> delete(Uri uri) async {
    final res = await http.delete(uri, headers: _headers());
    if (res.statusCode >= 400) {
      final body = res.body;
      if (_looksLikeHtml(body)) {
        throw Exception(
          'Non-JSON error response (HTML) from ${uri.toString()} status=${res.statusCode}',
        );
      }
      final json = body.isNotEmpty ? jsonDecode(body) : {};
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    Uri uri,
    Map<String, dynamic> data,
  ) async {
    final payload = jsonEncode(data);
    final req = http.Request('DELETE', uri);
    req.headers.addAll(_headers());
    req.body = payload;
    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);
    final body = res.body;
    if (_looksLikeHtml(body)) {
      throw Exception(
        'Non-JSON response (HTML) from ${uri.toString()} status=${res.statusCode}',
      );
    }
    final json = body.isNotEmpty ? jsonDecode(body) : {};
    if (res.statusCode >= 400) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message'].toString()
            : 'HTTP ${res.statusCode}',
      );
    }
    return json as Map<String, dynamic>;
  }

  bool _looksLikeHtml(String body) {
    if (body.isEmpty) return false;
    final trimmed = body.trimLeft();
    return trimmed.startsWith('<!DOCTYPE html') || trimmed.startsWith('<html');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }
}
