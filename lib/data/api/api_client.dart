import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL. Override per deployment without a code change:
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://aonego9-backend.onrender.com/api/v1',
);

/// HTTP wrapper shared in shape with the user and vendor apps: every request
/// has a deadline, GETs retry once (riding out a cold Render instance), a 401
/// triggers one token refresh, and writes are never retried.
class ApiClient {
  static const _tokenKey = 'admin_access_token';
  static const _refreshKey = 'admin_refresh_token';
  static const _emailKey = 'admin_email';
  static const _cityKey = 'admin_city';
  static String? _cachedToken;
  static String? _cachedEmail;
  static String? _cachedCity;

  /// Ticks whenever the session ends, so the router sends an expired admin
  /// to sign-in immediately rather than on the next tap.
  static final ValueNotifier<int> sessionChanges = ValueNotifier(0);

  static const _getTimeout = Duration(seconds: 30);
  static const _writeTimeout = Duration(seconds: 45);
  static const _uploadTimeout = Duration(seconds: 90);

  static Future<void> saveTokens(String access, String refresh, {String? email, String? city}) async {
    _cachedToken = access;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, access);
    await prefs.setString(_refreshKey, refresh);
    if (email != null && email.isNotEmpty) {
      _cachedEmail = email;
      await prefs.setString(_emailKey, email);
    }
    if (city != null) {
      _cachedCity = city;
      await prefs.setString(_cityKey, city);
    }
  }

  static Future<String?> getAccessToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<String?> getEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final prefs = await SharedPreferences.getInstance();
    _cachedEmail = prefs.getString(_emailKey);
    return _cachedEmail;
  }

  /// The city an admin signed in for ('' = all cities).
  static Future<String> getCity() async {
    if (_cachedCity != null) return _cachedCity!;
    final prefs = await SharedPreferences.getInstance();
    _cachedCity = prefs.getString(_cityKey) ?? '';
    return _cachedCity!;
  }

  static Future<void> clearTokens() async {
    final hadSession = _cachedToken != null;
    _cachedToken = null;
    _cachedEmail = null;
    _cachedCity = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_cityKey);
    if (hadSession) sessionChanges.value++;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<bool>? _refreshing;

  static Future<bool> _refreshAccessToken() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  static Future<bool> _doRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_writeTimeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await saveTokens(
        body['access_token'] as String,
        (body['refresh_token'] as String?) ?? refresh,
        email: await getEmail(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isLoggedIn() async => (await getAccessToken())?.isNotEmpty == true;

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final t = await getAccessToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static String _formatDetail(dynamic raw, int statusCode) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is List) {
      return raw.map((e) {
        if (e is Map) {
          final loc = e['loc'];
          final field = loc is List && loc.isNotEmpty ? '${loc.last}' : '';
          final msg = '${e['msg'] ?? e}';
          return field.isEmpty || field == 'body' ? msg : '$field: $msg';
        }
        return '$e';
      }).join('; ');
    }
    if (raw is Map && raw['message'] != null) return '${raw['message']}';
    if (raw != null) return raw.toString();
    return 'Request failed ($statusCode)';
  }

  /// A 422's `detail` is a list of field errors; the old `?? detail` assigned
  /// that List to a String and threw a TypeError instead of the message.
  static dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      try {
        return jsonDecode(res.body);
      } catch (_) {
        return res.body;
      }
    }
    String detail = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('detail')) {
        detail = _formatDetail(body['detail'], res.statusCode);
      } else if (body is Map && body['message'] != null) {
        detail = '${body['message']}';
      }
    } catch (_) {}
    throw ApiException(res.statusCode, detail);
  }

  static Future<http.Response> _withAuthRetry(Future<http.Response> Function() send, {bool auth = true}) async {
    var res = await send();
    if (auth && res.statusCode == 401 && await _refreshAccessToken()) res = await send();
    if (auth && res.statusCode == 401) await clearTokens();
    return res;
  }

  static Uri _uri(String path) => Uri.parse('$kBaseUrl$path');

  static Future<dynamic> get(String path) async {
    Future<http.Response> send() async => http.get(_uri(path), headers: await _headers()).timeout(_getTimeout);
    try {
      return _decode(await _withAuthRetry(send));
    } on TimeoutException {
      return _decode(await _withAuthRetry(send));
    } on http.ClientException {
      return _decode(await _withAuthRetry(send));
    }
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    Future<http.Response> send() async =>
        http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body)).timeout(_writeTimeout);
    return _decode(await _withAuthRetry(send, auth: auth));
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    Future<http.Response> send() async =>
        http.put(_uri(path), headers: await _headers(), body: jsonEncode(body)).timeout(_writeTimeout);
    return _decode(await _withAuthRetry(send));
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    Future<http.Response> send() async => http
        .patch(_uri(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null)
        .timeout(_writeTimeout);
    return _decode(await _withAuthRetry(send));
  }

  static Future<void> delete(String path) async {
    Future<http.Response> send() async => http.delete(_uri(path), headers: await _headers()).timeout(_writeTimeout);
    final res = await _withAuthRetry(send);
    if (res.statusCode >= 300) _decode(res);
  }

  /// List endpoints answer either a bare array or a page envelope.
  static List<Map<String, dynamic>> asList(dynamic data, [String key = 'items']) {
    final raw = data is List
        ? data
        : data is Map
            ? (data[key] ?? data['items'] ?? data['results'] ?? data['data'] ?? const [])
            : const [];
    return (raw is List ? raw : const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  static Map<String, dynamic> asMap(dynamic data) => data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  /// Image upload — JSON base64 on web (multipart from the browser was
  /// unreliable), multipart elsewhere; same contract as the vendor app.
  static Future<Map<String, dynamic>> uploadImage({
    required List<int> bytes,
    required String filename,
    String folder = 'misc',
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) throw const ApiException(400, 'Selected file is empty — try another image');
    if (bytes.length > 10 * 1024 * 1024) throw const ApiException(413, 'That image is over 10 MB — pick a smaller one');

    Future<http.Response> sendBase64() async => http
        .post(
          _uri('/uploads/image-base64'),
          headers: await _headers(),
          body: jsonEncode({'data': base64Encode(bytes), 'filename': filename, 'folder': folder, 'content_type': mimeType}),
        )
        .timeout(_uploadTimeout);

    Future<http.Response> sendMultipart() async {
      final token = await getAccessToken();
      final request = http.MultipartRequest('POST', _uri('/uploads/image').replace(queryParameters: {'folder': folder}));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType.parse(mimeType)));
      return http.Response.fromStream(await request.send().timeout(_uploadTimeout));
    }

    Future<http.Response> send() async {
      if (kIsWeb) {
        final r = await sendBase64();
        if (r.statusCode != 404) return r;
      }
      return sendMultipart();
    }

    return asMap(_decode(await _withAuthRetry(send)));
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  bool get isMissingRoute => statusCode == 404 || statusCode == 405 || statusCode == 501;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
