import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/external_catalog_service.dart';

// Server account APIs are optional. Movies/TV/Series NEVER depend on Next.js.
const accountsEnabled = bool.fromEnvironment('ENABLE_ACCOUNTS', defaultValue: false);

// Separate TV build: app navigation and remote focus are optimized for televisions.
const androidTvBuild = bool.fromEnvironment('ANDROID_TV', defaultValue: false);

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

  // Local, cross-platform player preferences (never stored on the catalog server).
  double playbackSpeed = 1.0;
  int seekSeconds = 10;
  bool autoPlay = true;
  bool subtitlesEnabled = true;
  bool fillVideo = false;
  String preferredAudioLanguage = 'auto';

  bool get loggedIn => user != null;
  bool get isAdmin => accountsEnabled && user?.isAdmin == true;
  String get currentServer => servers.isEmpty ? 'Server 1' : servers[serverIndex].name;
  String get liveTvUrl => servers.isEmpty ? '' : servers[serverIndex].liveTvUrl;
  String get defaultLiveTvUrl => defaultServers.isEmpty ? '' : defaultServers[serverIndex].liveTvUrl;
  bool get hasCustomLiveTvUrl => liveTvUrl != defaultLiveTvUrl;
  List<MediaItem> get liveChannels => catalog.where((m) => m.isLive).toList();
  List<MediaItem> get videos => catalog.where((m) => !m.isLive).toList();
  List<MediaItem> get watchlist => catalog.where((m) => favoriteIds.contains(m.id)).toList();

  // Content browsing must work even if optional Android local settings fail.
  // This is a fallback; the actual release plugin issue is fixed in pubspec.yaml.
  Future<SharedPreferences?> _readLocalSettings() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e, stack) {
      debugPrint('Could not access local settings: $e\n$stack');
      return null;
    }
  }

  Future<void> _saveLocalSettings(
      Future<Object?> Function(SharedPreferences) update) async {
    final prefs = await _readLocalSettings();
    if (prefs == null) {
      return;
    }
    try {
      await update(prefs);
    } catch (e, stack) {
      debugPrint('Could not save local settings: $e\n$stack');
    }
  }

  Future<void> init() async {
    // Report startup/plugin/asset errors in the app instead of leaving a
    // permanent loading indicator on Android.
    try {
      final store = await _readLocalSettings();
      favoriteIds = store?.getStringList('favorites_local')?.toSet() ?? {};
      playbackSpeed = store?.getDouble('player_speed') ?? 1.0;
      if (![0.5, 0.75, 1.0, 1.25, 1.5, 2.0].contains(playbackSpeed)) {
        playbackSpeed = 1.0;
      }
      seekSeconds = store?.getInt('player_seek_seconds') ?? 10;
      if (![10, 15, 30].contains(seekSeconds)) seekSeconds = 10;
      autoPlay = store?.getBool('player_autoplay') ?? true;
      subtitlesEnabled = store?.getBool('player_subtitles') ?? true;
      fillVideo = store?.getBool('player_fill_video') ?? false;
      preferredAudioLanguage = store?.getString('player_audio_language') ?? 'auto';
      defaultServers = await ExternalCatalogService.availableServers();
      servers = List<CatalogServer>.of(defaultServers);
      for (var i = 0; i < servers.length; i++) {
        final overrideUrl = store?.getString('live_tv_override_$i');
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
      serverIndex = (store?.getInt('selected_server_index') ?? 0)
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
    await _saveLocalSettings(
        (prefs) => prefs.setInt('selected_server_index', index));
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
    await _saveLocalSettings(
        (prefs) => prefs.setString('live_tv_override_$index', uri.toString()));
    servers[index] = _withLiveTvUrl(servers[index], uri.toString());
    await refresh();
  }

  Future<void> resetLiveTvUrl() async {
    final index = serverIndex;
    await _saveLocalSettings(
        (prefs) => prefs.remove('live_tv_override_$index'));
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

  Future<void> updatePlaybackSpeed(double speed) async {
    if (![0.5, 0.75, 1.0, 1.25, 1.5, 2.0].contains(speed)) return;
    playbackSpeed = speed;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setDouble('player_speed', speed));
  }

  Future<void> updateSeekSeconds(int seconds) async {
    if (![10, 15, 30].contains(seconds)) return;
    seekSeconds = seconds;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setInt('player_seek_seconds', seconds));
  }

  Future<void> updateAutoPlay(bool value) async {
    autoPlay = value;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setBool('player_autoplay', value));
  }

  Future<void> updateSubtitles(bool value) async {
    subtitlesEnabled = value;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setBool('player_subtitles', value));
  }

  Future<void> updateVideoFill(bool value) async {
    fillVideo = value;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setBool('player_fill_video', value));
  }

  Future<void> updateAudioLanguage(String value) async {
    if (!['auto', 'en', 'hi', 'bn', 'ko', 'tr'].contains(value)) return;
    preferredAudioLanguage = value;
    notifyListeners();
    await _saveLocalSettings((prefs) => prefs.setString('player_audio_language', value));
  }

  Future<void> resetPlayerPreferences() async {
    playbackSpeed = 1.0;
    seekSeconds = 10;
    autoPlay = true;
    subtitlesEnabled = true;
    fillVideo = false;
    preferredAudioLanguage = 'auto';
    notifyListeners();
    await _saveLocalSettings((prefs) async {
      for (final key in [
        'player_speed', 'player_seek_seconds', 'player_autoplay',
        'player_subtitles', 'player_fill_video', 'player_audio_language',
      ]) {
        await prefs.remove(key);
      }
    });
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
    await _saveLocalSettings(
        (prefs) => prefs.setStringList('favorites_local', favoriteIds.toList()));
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

