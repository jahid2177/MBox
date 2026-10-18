import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';

const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

class AppState extends ChangeNotifier {
  AppState({this.api});
  final ApiService? api;
  List<MediaItem> catalog = [];
  AppUser? user;
  Set<String> favoriteIds = {};
  bool loading = true;
  String? error;
  bool get loggedIn => user != null;
  bool get isAdmin => user?.isAdmin == true && !demoMode;
  List<MediaItem> get liveChannels => catalog.where((m) => m.isLive).toList();
  List<MediaItem> get videos => catalog.where((m) => !m.isLive).toList();
  List<MediaItem> get watchlist => catalog.where((m) => favoriteIds.contains(m.id)).toList();

  Future<void> init() async {
    final store = await SharedPreferences.getInstance();
    favoriteIds = store.getStringList('favorites_local')?.toSet() ?? {};
    notifyListeners();
    if (!demoMode && api != null) {
      try {
        user = await api!.currentUser();
        if (user != null) {
          favoriteIds = (await api!.favorites()).toSet();
          await _saveFavorites();
        }
      } catch (_) {
        // Offline: do not restore an unverified admin session.
        user = null;
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (demoMode) {
        final data = jsonDecode(await rootBundle.loadString('assets/demo/catalog.json')) as List;
        catalog = data.whereType<Map>().map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m))).toList();
      } else {
        if (api == null) {
          throw Exception('Backend client is not initialized.');
        }
        catalog = await api!.catalog();
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    if (demoMode) {
      throw Exception('Login requires a running backend. Disable DEMO_MODE.');
    }
    user = await api!.login(email, password);
    favoriteIds = (await api!.favorites()).toSet();
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    if (demoMode) {
      throw Exception('Register requires a running backend. Disable DEMO_MODE.');
    }
    user = await api!.register(name, email, password);
    favoriteIds = {};
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> logout() async {
    try { if (!demoMode) await api?.logout(); }
    finally {
      user = null;
      favoriteIds = {};
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(MediaItem movie) async {
    if (user == null && !demoMode) {
      throw Exception('Please sign in to save your list.');
    }
    final alreadySaved = favoriteIds.contains(movie.id);
    if (!demoMode) {
      if (alreadySaved) { await api!.removeFavorite(movie.id); }
      else { await api!.addFavorite(movie.id); }
    }
    if (alreadySaved) { favoriteIds.remove(movie.id); }
    else { favoriteIds.add(movie.id); }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites_local', favoriteIds.toList());
  }

  Future<void> switchProfile(String id) async {
    if (user == null || demoMode) {
      return;
    }
    user = await api!.switchProfile(id);
    notifyListeners();
  }

  Future<void> addProfile(String name, {bool isKids = false}) async {
    if (user == null || demoMode) {
      return;
    }
    user = await api!.addProfile(name, isKids: isKids);
    notifyListeners();
  }
}
