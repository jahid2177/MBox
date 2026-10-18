import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/external_catalog_service.dart';

// Server account APIs are optional. Movies/TV/Series NEVER depend on Next.js.
const accountsEnabled = bool.fromEnvironment('ENABLE_ACCOUNTS', defaultValue: false);

class AppState extends ChangeNotifier {
  AppState({this.api, ExternalCatalogService? sources}) : sources = sources ?? ExternalCatalogService();
  final ApiService? api;
  final ExternalCatalogService sources;
  List<CatalogServer> servers = [];
  int serverIndex = 0;
  List<MediaItem> catalog = [];
  AppUser? user;
  Set<String> favoriteIds = {};
  bool loading = true;
  String? error;
  List<String> warnings = [];
  int _refreshVersion = 0;
  bool get loggedIn => user != null;
  bool get isAdmin => accountsEnabled && user?.isAdmin == true;
  String get currentServer => servers.isEmpty ? 'Server 1' : servers[serverIndex].name;
  List<MediaItem> get liveChannels => catalog.where((m) => m.isLive).toList();
  List<MediaItem> get videos => catalog.where((m) => !m.isLive).toList();
  List<MediaItem> get watchlist => catalog.where((m) => favoriteIds.contains(m.id)).toList();

  Future<void> init() async {
    final store = await SharedPreferences.getInstance();
    favoriteIds = store.getStringList('favorites_local')?.toSet() ?? {};
    servers = await ExternalCatalogService.availableServers();
    if (servers.isEmpty) {
      error = 'No servers found in catalog_sources.json';
      loading = false;
      notifyListeners();
      return;
    }
    serverIndex = (store.getInt('selected_server_index') ?? 0).clamp(0, servers.length - 1).toInt();
    notifyListeners();
    if (accountsEnabled && api != null) {
      try {
        user = await api!.currentUser();
      } catch (_) { user = null; }
    }
    await refresh();
  }

  Future<void> setServer(int index) async {
    if (index < 0 || index >= servers.length || serverIndex == index) {
      return;
    }
    serverIndex = index;
    catalog = [];
    warnings = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_server_index', index);
    await refresh();
  }

  Future<void> refresh() async {
    if (servers.isEmpty) {
      return;
    }
    final currentVersion = ++_refreshVersion;
    loading = true;
    error = null;
    warnings = [];
    notifyListeners();
    try {
      final results = await sources.load(servers[serverIndex], onProgress: (items, problems) {
        if (currentVersion != _refreshVersion) {
          return;
        }
        catalog = items;
        warnings = problems;
        notifyListeners();
      });
      if (currentVersion != _refreshVersion) {
        return;
      }
      catalog = results.items;
      warnings = results.problems;
    } catch (e) {
      if (currentVersion != _refreshVersion) {
        return;
      }
      // Do not replace failed requests with fabricated content.
      error = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
    } finally {
      if (currentVersion == _refreshVersion) { loading = false; notifyListeners(); }
    }
  }

  Future<void> login(String email, String password) async {
    if (!accountsEnabled || api == null) {
      throw StateError('Account backend is not configured.');
    }
    user = await api!.login(email, password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    if (!accountsEnabled || api == null) {
      throw StateError('Account backend is not configured.');
    }
    user = await api!.register(name, email, password);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (accountsEnabled) {
        await api?.logout();
      }
    } finally {
      user = null;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(MediaItem movie) async {
    // Local watchlist works WITHOUT logging in or any user backend.
    if (favoriteIds.contains(movie.id)) {
      favoriteIds.remove(movie.id);
    } else {
      favoriteIds.add(movie.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites_local', favoriteIds.toList());
    notifyListeners();
  }

  Future<void> switchProfile(String id) async {
    if (user == null || !accountsEnabled || api == null) {
      return;
    }
    user = await api!.switchProfile(id);
    notifyListeners();
  }

  Future<void> addProfile(String name, {bool isKids = false}) async {
    if (user == null || !accountsEnabled || api == null) {
      return;
    }
    user = await api!.addProfile(name, isKids: isKids);
    notifyListeners();
  }
}
