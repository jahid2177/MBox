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
  List<CatalogServer> defaultServers = [];
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
  String get liveTvUrl => servers.isEmpty ? '' : servers[serverIndex].liveTvUrl;
  String get defaultLiveTvUrl => defaultServers.isEmpty ? '' : defaultServers[serverIndex].liveTvUrl;
  bool get hasCustomLiveTvUrl => liveTvUrl != defaultLiveTvUrl;
  List<MediaItem> get liveChannels => catalog.where((m) => m.isLive).toList();
  List<MediaItem> get videos => catalog.where((m) => !m.isLive).toList();
  List<MediaItem> get watchlist => catalog.where((m) => favoriteIds.contains(m.id)).toList();

  Future<void> init() async {
    // Report startup/plugin/asset errors in the app instead of leaving a
    // permanent loading indicator on Android.
    try {
      final store = await SharedPreferences.getInstance();
      favoriteIds = store.getStringList('favorites_local')?.toSet() ?? {};
      defaultServers = await ExternalCatalogService.availableServers();
      servers = List<CatalogServer>.of(defaultServers);
      for (var i = 0; i < servers.length; i++) {
        final overrideUrl = store.getString('live_tv_override_$i');
        if (overrideUrl != null && overrideUrl.isNotEmpty) {
          servers[i] = _withLiveTvUrl(servers[i], overrideUrl);
        }
      }
      if (servers.isEmpty) {
        error = 'No servers found in assets/sources/catalog_sources.json';
        loading = false;
        notifyListeners();
        return;
      }
      serverIndex = (store.getInt('selected_server_index') ?? 0)
          .clamp(0, servers.length - 1).toInt();
      notifyListeners();
      if (accountsEnabled && api != null) {
        try {
          user = await api!.currentUser();
        } catch (_) {
          user = null;
        }
      }
      await refresh();
    } catch (e, stack) {
      debugPrint('MyStreamFlix initialization error: $e\n$stack');
      error = 'App initialization failed: $e';
      loading = false;
      notifyListeners();
    }
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

  /// Keep movies and series unchanged when the user updates a TV feed.
  CatalogServer _withLiveTvUrl(CatalogServer server, String url) => CatalogServer(
    name: server.name,
    liveTvUrl: url,
    movies: server.movies,
    series: server.series,
    maintenance: server.maintenance,
  );

  /// Saves a user-provided URL per server on this device. Validate it first
  /// with sources.validateLiveTvUrl() to avoid storing another broken feed.
  Future<void> setLiveTvUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https') || !uri.hasAuthority) {
      throw const FormatException('Live TV URL must be a valid HTTPS address.');
    }
    final index = serverIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('live_tv_override_$index', uri.toString());
    servers[index] = _withLiveTvUrl(servers[index], uri.toString());
    await refresh();
  }

  Future<void> resetLiveTvUrl() async {
    final index = serverIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('live_tv_override_$index');
    servers[index] = defaultServers[index];
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
