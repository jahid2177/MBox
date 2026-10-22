import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/media_item.dart';

// The ONLY catalog sources are the user-supplied JSON URLs in this asset.
const catalogConfigAsset = 'assets/sources/catalog_sources.json';

class CategorySource {
  const CategorySource(this.name, this.url);
  final String name;
  final String url;
}

class CatalogServer {
  const CatalogServer({required this.name, required this.liveTvUrl,
    required this.movies, required this.series, required this.maintenance});
  final String name;
  final String liveTvUrl;
  final List<CategorySource> movies;
  final List<CategorySource> series;
  final bool maintenance;

  factory CatalogServer.fromJson(Map<String, dynamic> raw) {
    final cfg = Map<String, dynamic>.from(raw['api_config'] as Map);
    List<CategorySource> sections(String key) => (cfg[key] as List? ?? [])
      .whereType<Map>().map((s) => CategorySource('${s['name']}', '${s['url']}')).toList();
    return CatalogServer(name: '${raw['name']}', liveTvUrl: '${cfg['live_tv_url']}',
      movies: sections('movie_categories'), series: sections('series_categories'),
      maintenance: cfg['maintenance'] == true);
  }
}

class CatalogLoadResult {
  const CatalogLoadResult(this.items, this.problems);
  final List<MediaItem> items;
  final List<String> problems;
}

// Decode large (14-20 MB) catalog parts in a background isolate, not on
// Flutter's UI thread. A manifest is distinguished from actual media items.
class _ParsedCatalogResponse {
  const _ParsedCatalogResponse(this.items, this.parts);

  final List<MediaItem> items;
  final List<String>? parts;
}

_ParsedCatalogResponse _parseCatalogTask(Map<String, dynamic> task) {
  final raw = task['body'];
  final data = raw is String ? jsonDecode(raw) : raw;
  final sourceUrl = task['sourceUrl'] as String;
  final parts = CatalogParser.manifestParts(data, sourceUrl: sourceUrl);
  if (parts != null) {
    return _ParsedCatalogResponse(const [], parts);
  }
  return _ParsedCatalogResponse(
    CatalogParser.parse(data,
      type: task['type'] as String,
      category: task['category'] as String,
      sourceUrl: sourceUrl),
    null,
  );
}

class ExternalCatalogService {
  ExternalCatalogService({Dio? client}) : _dio = client ?? Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    // Individual English Series parts are 14-19 MB; slower connections may
    // need more than the old 45-second timeout.
    receiveTimeout: const Duration(minutes: 2),
    responseType: ResponseType.json,
    headers: const {'Accept': 'application/json'},
  ));

  final Dio _dio;

  /// Checks a replacement URL before it is saved. A reachable empty or
  /// incompatible JSON file is not treated as a valid Live TV source.
  Future<int> validateLiveTvUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https') || !uri.hasAuthority) {
      throw const FormatException('Enter a valid HTTPS URL to a Live TV JSON file.');
    }
    try {
      final response = await _dio.get<dynamic>(uri.toString());
      final data = response.data is String
          ? jsonDecode(response.data as String) : response.data;
      final channels = CatalogParser.parse(data, type: 'livetv',
          category: 'Live TV', sourceUrl: uri.toString());
      if (channels.isEmpty) {
        throw const FormatException(
            'The JSON was downloaded, but no playable channels were found. Check its structure.');
      }
      return channels.length;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        throw const FormatException('HTTP 404: File not found. Check repository, branch, folder and filename.');
      }
      if (status != null) {
        throw FormatException('HTTP $status: Could not download Live TV JSON.');
      }
      throw FormatException('Unable to reach URL: ${e.message ?? 'network error'}');
    }
  }

  static Future<List<CatalogServer>> availableServers() async {
    final data = jsonDecode(await rootBundle.loadString(catalogConfigAsset)) as Map;
    return (data['servers'] as List).whereType<Map>()
      .map((row) => CatalogServer.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<CatalogLoadResult> load(CatalogServer server, {
    void Function(List<MediaItem> items, List<String> problems)? onProgress,
  }) async {
    if (server.maintenance) {
      throw StateError('${server.name} is under maintenance.');
    }
    // Start the first movie and the first series in parallel. This avoids a
    // large movie catalog queue starving English TV Series on slow devices.
    final movieSources = server.movies.map((c) =>
      (label: c.name, url: c.url, type: 'movie')).toList();
    final seriesSources = server.series.map((c) =>
      (label: c.name, url: c.url, type: 'series')).toList();
    final sources = <({String label, String url, String type})>[
      if (movieSources.isNotEmpty) movieSources.first,
      if (seriesSources.isNotEmpty) seriesSources.first,
      ...movieSources.skip(1),
      ...seriesSources.skip(1),
      (label: 'Live TV', url: server.liveTvUrl, type: 'livetv'),
    ];
    if (sources.isEmpty) {
      throw StateError('No catalog sources configured for ${server.name}.');
    }

    final problemsByIndex = <int, String>{};
    final loadedByIndex = <int, List<MediaItem>>{};
    var nextSource = 0;

    List<MediaItem> currentItems() {
      final seen = <String>{};
      final unique = <MediaItem>[];
      for (var i = 0; i < sources.length; i++) {
        for (final item in loadedByIndex[i] ?? <MediaItem>[]) {
          if (seen.add(item.id)) {
            unique.add(item);
          }
        }
      }
      return unique;
    }

    void publish() {
      onProgress?.call(
        List<MediaItem>.unmodifiable(currentItems()),
        List<String>.unmodifiable([
          for (var i = 0; i < sources.length; i++)
            if (problemsByIndex.containsKey(i)) problemsByIndex[i]!,
        ]),
      );
    }

    // Receive text rather than asking Dio to JSON-decode a huge part on the
    // UI isolate. The isolate handles both decoding and conversion to MediaItem.
    Future<_ParsedCatalogResponse> downloadAndParse(
      String url, String type, String category, String sourceId,
    ) async {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isScheme('https') || !uri.hasAuthority) {
        throw const FormatException('Catalog URL must be a valid HTTPS URL');
      }
      final response = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const FormatException('JSON file is empty');
      }
      return compute(_parseCatalogTask, <String, dynamic>{
        'body': body,
        'type': type,
        'category': category,
        // For a multipart catalog, IDs must be independent of the part URL,
        // so moving a series between parts does not break its Favorites ID.
        'sourceUrl': sourceId,
      });
    }

    // At most two source downloads are active to reduce memory pressure on
    // Android/TV. Multipart files are fetched sequentially and each completed
    // part is published immediately, before the other parts finish.
    Future<void> worker() async {
      while (nextSource < sources.length) {
        final index = nextSource++;
        final source = sources[index];
        try {
          final main = await downloadAndParse(
            source.url, source.type, source.label, source.url);
          if (main.parts == null) {
            if (main.items.isEmpty) {
              problemsByIndex[index] =
                  '${source.label}: JSON loaded, but no entries were recognized';
            } else {
              loadedByIndex[index] = main.items;
            }
          } else {
            final combined = <MediaItem>[];
            final partProblems = <String>[];
            final parts = main.parts!;
            for (var partIndex = 0; partIndex < parts.length; partIndex++) {
              try {
                final part = await downloadAndParse(
                  parts[partIndex], source.type, source.label, source.url);
                if (part.parts != null) {
                  throw const FormatException(
                      'Nested manifests are not supported');
                }
                if (part.items.isEmpty) {
                  partProblems.add('part ${partIndex + 1}: no entries found');
                } else {
                  combined.addAll(part.items);
                  loadedByIndex[index] = List<MediaItem>.of(combined);
                  publish(); // Series appear as soon as the first part is ready.
                }
              } catch (e) {
                partProblems.add(
                    'part ${partIndex + 1}: ${_shortError(e)}');
              }
            }
            if (combined.isEmpty) {
              problemsByIndex[index] = '${source.label}: '
                  'Could not load any of ${parts.length} JSON parts. '
                  '${partProblems.take(3).join(' | ')}';
            } else if (partProblems.isNotEmpty) {
              problemsByIndex[index] = '${source.label}: '
                  '${combined.length} entries loaded, '
                  '${partProblems.length}/${parts.length} parts had issues. '
                  '${partProblems.take(3).join(' | ')}';
            }
          }
        } catch (e) {
          problemsByIndex[index] = '${source.label}: ${_shortError(e)}';
        }
        publish();
      }
    }

    await Future.wait(List.generate(
      sources.length < 2 ? sources.length : 2,
      (_) => worker(),
    ));
    final items = currentItems();
    final problems = [for (var i = 0; i < sources.length; i++)
      if (problemsByIndex.containsKey(i)) problemsByIndex[i]!];
    if (items.isEmpty) {
      throw StateError('No content loaded from ${server.name}. '
          '${problems.take(4).join(' | ')}');
    }
    return CatalogLoadResult(items, problems);
  }

  String _shortError(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode != null) {
        return 'HTTP ${e.response!.statusCode}';
      }
      final description = '${e.message ?? ''} ${e.error ?? ''}'.toLowerCase();
      if (description.contains('permission denied') ||
          description.contains('operation not permitted')) {
        return 'Network permission denied. Check Android INTERNET permission.';
      }
      if (description.contains('failed host lookup') ||
          description.contains('socketexception')) {
        return 'Cannot reach host (DNS/network). Check Wi-Fi/mobile data.';
      }
      return e.message ?? 'network connection failed';
    }
    return e.toString().replaceFirst('FormatException: ', '');
  }
}

/// Reads external movie, series and live-TV JSON. Does not fabricate sample entries.
class CatalogParser {
  /// Return resolved multipart URLs, or null for an ordinary movie/series JSON.
  /// Relative filenames and full HTTPS links are both accepted. Reject invalid
  /// manifests explicitly rather than reporting "no series found".
  static List<String>? manifestParts(dynamic data, {
    required String sourceUrl,
  }) {
    if (data is! Map || !data.containsKey('parts')) {
      return null;
    }
    final raw = data['parts'];
    if (raw is! List || raw.isEmpty || raw.length > 100) {
      throw const FormatException(
          'Invalid multipart JSON: parts must contain 1 to 100 entries');
    }
    final base = Uri.parse(sourceUrl);
    final parts = <String>[];
    final seen = <String>{};
    for (final value in raw) {
      final link = value is String
          ? value.trim()
          : value is Map && value['url'] is String
              ? (value['url'] as String).trim()
              : '';
      if (link.isEmpty) {
        throw const FormatException('Invalid multipart JSON part URL');
      }
      final uri = base.resolve(link);
      if (!uri.isScheme('https') || !uri.hasAuthority) {
        throw const FormatException('Multipart JSON parts must use HTTPS');
      }
      if (seen.add(uri.toString())) {
        parts.add(uri.toString());
      }
    }
    return parts;
  }

  static List<MediaItem> parse(dynamic data, {
    required String type, required String category, required String sourceUrl,
  }) {
    if (type == 'livetv') {
      return _parseLive(data, category, sourceUrl);
    }
    final result = <MediaItem>[];
    if (data is List) {
      for (var i = 0; i < data.length; i++) {
        if (data[i] is Map) {
          final m = Map<String, dynamic>.from(data[i] as Map);
          result.add(_item('${m['title'] ?? m['name'] ?? 'Title ${i + 1}'}', m,
            type, category, sourceUrl));
        }
      }
    } else if (data is Map) {
      final collection = data['movies'] ?? data['series'] ?? data['items'] ?? data['data'];
      if (collection is List) {
        return parse(collection, type: type, category: category, sourceUrl: sourceUrl);
      }
      for (final entry in data.entries) {
        if (entry.value is Map) {
          result.add(_item('${entry.key}', Map<String, dynamic>.from(entry.value as Map),
            type, category, sourceUrl));
        }
      }
    } else {
      throw const FormatException('Unsupported catalog JSON shape');
    }
    return result;
  }

  static MediaItem _item(String title, Map<String, dynamic> row,
      String type, String category, String sourceUrl) {
    final links = _sources(row['links'] ?? row['streams'] ?? row['sources']);
    final primary = _streamUrl(row['videoUrl'] ?? row['stream_url'] ?? row['url']);
    if (primary.isNotEmpty && !links.any((s) => s.url == primary)) {
      links.insert(0, StreamSource(url: primary, label: 'Default'));
    }
    final seasons = <Season>[];
    if (type == 'series') {
      final groups = <int, Map<int, List<StreamSource>>>{};
      final titles = <String, String>{};
      for (final rawLink in _maps(row['links'])) {
        final season = _number(rawLink['season'], defaultValue: 1);
        final episode = _number(rawLink['episode'] ?? rawLink['episode_number'], defaultValue: 1);
        final url = _safeUrl(rawLink['url'] ?? rawLink['videoUrl']);
        if (url.isEmpty) {
          continue;
        }
        final streams = groups.putIfAbsent(season, () => {}).putIfAbsent(episode, () => []);
        if (!streams.any((s) => s.url == url)) {
          streams.add(StreamSource(
            url: url, quality: '${rawLink['quality'] ?? ''}',
            language: '${rawLink['language'] ?? ''}',
            label: '${rawLink['episode_title'] ?? rawLink['filename'] ?? ''}',
          ));
        }
        final epTitle = '${rawLink['episode_name'] ?? ''}'.trim();
        if (epTitle.isNotEmpty) {
          titles['$season:$episode'] = epTitle;
        }
      }
      final seasonNums = groups.keys.toList()..sort();
      for (final n in seasonNums) {
        final eps = groups[n]!;
        final episodeNums = eps.keys.toList()..sort();
        seasons.add(Season(n, 'Season $n', [for (final e in episodeNums)
          Episode(id: '${_id(sourceUrl, title, type)}-s${n}e$e',
            title: titles['$n:$e'] ?? 'Episode $e', number: e, duration: 0,
            videoUrl: eps[e]!.first.url, sources: eps[e]!),
        ]));
      }
    }
    return MediaItem(id: _id(sourceUrl, title, type), title: title,
      description: '${row['description'] ?? row['overview'] ?? ''}',
      posterUrl: _safeUrl(row['tvg_logo'] ?? row['poster'] ?? row['posterUrl'] ?? row['logo']),
      backdropUrl: _safeUrl(row['backdrop'] ?? row['backdropUrl']),
      releaseYear: _number(row['year'] ?? row['releaseYear']),
      quality: '${row['quality'] ?? (links.isEmpty ? '' : links.first.quality)}',
      videoUrl: primary.isNotEmpty ? primary : (type == 'movie' && links.isNotEmpty ? links.first.url : ''),
      streams: type == 'movie' ? links : const [],
      genres: [category], contentType: type, seasons: seasons);
  }

  static List<MediaItem> _parseLive(dynamic data, String category, String sourceUrl) {
    final channels = <MediaItem>[];
    void walk(dynamic node, String inherited, [int depth = 0]) {
      if (depth > 6 || channels.length >= 5000) {
        return;
      }
      if (node is List) {
        for (final item in node) { walk(item, inherited, depth + 1); }
      } else if (node is Map) {
        final row = Map<String, dynamic>.from(node);
        final title = '${row['tvg_name'] ?? row['channel_name'] ?? row['name'] ?? row['title'] ?? ''}'.trim();
        final sources = _sources(row['links'] ?? row['streams'] ?? row['sources']);
        final direct = _streamUrl(row['url'] ?? row['stream_url'] ?? row['streamUrl'] ?? row['videoUrl'] ?? row['link']);
        if (direct.isNotEmpty && !sources.any((s) => s.url == direct)) {
          sources.insert(0, StreamSource(url: direct));
        }
        if (title.isNotEmpty && sources.isNotEmpty) {
          final group = '${row['group-title'] ?? row['group_title'] ?? row['category'] ?? row['group'] ?? inherited}';
          channels.add(MediaItem(id: _id(sourceUrl, '$title/$group', 'livetv'),
            title: title, contentType: 'livetv', posterUrl: _safeUrl(row['tvg_logo'] ?? row['logo'] ?? row['image'] ?? row['thumbnail']),
            videoUrl: sources.first.url, streams: sources, genres: [group]));
          return;
        }
        final nested = row['channels'] ?? row['live_tv'] ?? row['data'] ?? row['items'] ?? row['categories'];
        if (nested != null) { walk(nested, inherited, depth + 1); return; }
        for (final entry in row.entries) {
          final value = entry.value;
          if (value is Map) {
            final m = Map<String, dynamic>.from(value);
            if (!m.containsKey('name') && !m.containsKey('title') && (m.containsKey('url') || m.containsKey('links') || m.containsKey('stream_url'))) {
              m['name'] = entry.key;
            }
            walk(m, title.isNotEmpty ? title : entry.key.toString(), depth + 1);
          } else if (value is List) {
            walk(value, title.isNotEmpty ? title : entry.key.toString(), depth + 1);
          } else if (value is String && _streamUrl(value).isNotEmpty) {
            walk({'name': entry.key, 'url': value}, inherited, depth + 1);
          }
        }
      }
    }
    walk(data, category);
    return channels;
  }

  static List<StreamSource> _sources(dynamic raw) {
    final result = <StreamSource>[];
    if (raw is List) {
      for (final link in raw) {
        if (link is String) {
          final url = _streamUrl(link);
          if (url.isNotEmpty) {
            result.add(StreamSource(url: url));
          }
        } else if (link is Map) {
          final url = _streamUrl(link['url'] ?? link['stream_url'] ?? link['videoUrl'] ?? link['link']);
          if (url.isNotEmpty && !result.any((s) => s.url == url)) {
            result.add(StreamSource(
              url: url, quality: '${link['quality'] ?? ''}', language: '${link['language'] ?? ''}',
              label: '${link['episode_title'] ?? link['filename'] ?? link['name'] ?? ''}',
            ));
          }
        }
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final url = _streamUrl(entry.value is Map ? (entry.value as Map)['url'] : entry.value);
        if (url.isNotEmpty) {
          result.add(StreamSource(url: url, label: '${entry.key}'));
        }
      }
    }
    return result;
  }

  static String _safeUrl(dynamic input) {
    final value = input is String ? input.trim() : '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasAuthority && (uri.isScheme('http') || uri.isScheme('https')) ? value : '';
  }

  static String _streamUrl(dynamic input) {
    final value = _safeUrl(input);
    if (value.isEmpty) {
      return '';
    }
    final path = Uri.parse(value).path.toLowerCase();
    if (path.endsWith('.html') || path.endsWith('.htm') ||
        path.endsWith('.jpg') || path.endsWith('.jpeg') ||
        path.endsWith('.png') || path.endsWith('.webp') ||
        path.endsWith('.json') || path.endsWith('/cn/') || path.startsWith('/cn/')) {
      return '';
    }
    return value;
  }

  static List<Map<String, dynamic>> _maps(dynamic val) => val is List
      ? val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static int _number(dynamic value, {int defaultValue = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? defaultValue;
  }

  static String _id(String source, String title, String type) {
    // Stable 32-bit FNV-1a across restarts (unlike String.hashCode).
    var n = 2166136261;
    for (final b in utf8.encode('$type|$source|$title')) {
      n = ((n ^ b) * 16777619) & 0xffffffff;
    }
    return '${type == 'livetv' ? 'tv' : type}-$n';
  }
}
