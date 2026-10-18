import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_user.dart';
import '../models/media_item.dart';

const defaultBackendUrl = String.fromEnvironment(
  'API_BASE_URL', defaultValue: '',
);

class ApiService {
  ApiService._(this._client, this._cookies);
  final Dio _client;
  final PersistCookieJar _cookies;

  static Future<ApiService> create({String baseUrl = defaultBackendUrl}) async {
    final root = Uri.tryParse(baseUrl);
    if (root == null || !root.hasAuthority || !(root.isScheme('https') || root.host == 'localhost' || root.host == '10.0.2.2')) {
      throw ArgumentError('API_BASE_URL must use HTTPS (except local development).');
    }
    final dir = await getApplicationSupportDirectory();
    final store = Directory('${dir.path}${Platform.pathSeparator}cookies');
    await store.create(recursive: true);
    final jar = PersistCookieJar(storage: FileStorage(store.path));
    final client = Dio(BaseOptions(
      baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {'Accept': 'application/json'},
    ));
    client.interceptors.add(CookieManager(jar));
    return ApiService._(client, jar);
  }

  Future<dynamic> _get(String url, {Map<String, dynamic>? query}) async {
    try {
      return (await _client.get<dynamic>(url, queryParameters: query)).data;
    } on DioException catch (e) { throw _error(e); }
  }

  Future<dynamic> _send(String method, String url, [Object? payload]) async {
    try {
      return (await _client.request<dynamic>(url, data: payload, options: Options(method: method))).data;
    } on DioException catch (e) { throw _error(e); }
  }

  Exception _error(DioException error) {
    final data = error.response?.data;
    final bodyMessage = data is Map ? data['error'] ?? data['message'] : null;
    return Exception(bodyMessage?.toString() ??
        (error.response?.statusCode != null ? 'Server error ${error.response!.statusCode}' : 'Cannot connect to the streaming server.'));
  }

  Future<List<MediaItem>> catalog() async {
    final data = await _get('/api/movies');
    final list = data is List ? data : (data is Map ? data['movies'] : null);
    if (list is! List) {
      throw const FormatException('Expected movie array from server');
    }
    return list.whereType<Map>().map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<MediaItem> detail(String id) async => MediaItem.fromJson(
      Map<String, dynamic>.from(await _get('/api/movies/${Uri.encodeComponent(id)}') as Map));

  Future<AppUser?> currentUser() async {
    final response = await _get('/api/auth/me');
    final item = response is Map ? response['user'] : null;
    return item is Map ? AppUser.fromJson(Map<String, dynamic>.from(item)) : null;
  }

  Future<AppUser> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', {'email': email.trim().toLowerCase(), 'password': password});
    if (data is! Map || data['success'] != true || data['user'] is! Map) {
      throw Exception('Login was not accepted.');
    }
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<AppUser> register(String name, String email, String password) async {
    final data = await _send('POST', '/api/auth/register', {
      'name': name.trim(), 'email': email.trim().toLowerCase(), 'password': password,
    });
    if (data is! Map || data['user'] is! Map) {
      throw Exception('Registration failed.');
    }
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  Future<void> logout() async {
    try { await _send('POST', '/api/auth/logout'); }
    finally { await _cookies.deleteAll(); }
  }

  Future<List<String>> favorites() async {
    final data = await _get('/api/user/favorites');
    // Backend getFavorites may return IDs or media objects.
    final list = data is Map ? data['favorites'] : data;
    if (list is! List) {
      return [];
    }
    return list.map((it) => it is Map ? '${it['movieId'] ?? it['id'] ?? ''}' : '$it')
        .where((id) => id.isNotEmpty).toList();
  }

  Future<void> addFavorite(String id) async { await _send('POST', '/api/user/favorites', {'movieId': id}); }
  Future<void> removeFavorite(String id) async { await _send('DELETE', '/api/user/favorites/${Uri.encodeComponent(id)}'); }
  Future<void> saveHistory(String id, Duration position, Duration duration) async {
    await _send('POST', '/api/user/history', {
      'movieId': id, 'progress': position.inSeconds, 'duration': duration.inSeconds,
    });
  }
  Future<List<dynamic>> history() async {
    final result = await _get('/api/user/history');
    return result is List ? result : [];
  }

  Future<AppUser> switchProfile(String id) async {
    final result = await _send('POST', '/api/auth/profile/switch', {'profileId': id});
    return AppUser.fromJson(Map<String, dynamic>.from((result as Map)['user'] as Map));
  }
  Future<AppUser> addProfile(String name, {bool isKids = false}) async {
    final result = await _send('POST', '/api/auth/profile/create', {'name': name, 'isKids': isKids});
    return AppUser.fromJson(Map<String, dynamic>.from((result as Map)['user'] as Map));
  }
  Future<List<AppUser>> users() async {
    final result = await _get('/api/users');
    final list = result is List ? result : (result is Map ? result['users'] : null);
    if (list is! List) {
      return [];
    }
    return list.whereType<Map>().map((m) => AppUser.fromJson(Map<String, dynamic>.from(m))).toList();
  }
  Future<AppUser> setRole(String id, String role) async {
    final result = await _send('PUT', '/api/users/${Uri.encodeComponent(id)}/role', {'role': role});
    return AppUser.fromJson(Map<String, dynamic>.from((result as Map)['user'] as Map));
  }
  Future<void> deleteUser(String id) async { await _send('DELETE', '/api/users/${Uri.encodeComponent(id)}'); }
  Future<void> addContent(Map<String, dynamic> data) async { await _send('POST', '/api/movies', data); }
  Future<void> updateContent(String id, Map<String, dynamic> data) async { await _send('PUT', '/api/movies/${Uri.encodeComponent(id)}', data); }
  Future<void> deleteContent(String id) async { await _send('DELETE', '/api/movies/${Uri.encodeComponent(id)}'); }
}
