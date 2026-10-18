import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/services/external_catalog_service.dart';

void main() {
  test('movie map keyed by title and multiple stream links', () {
    final rows = CatalogParser.parse({
      'Film (2026)': {'year': '2026', 'tvg_logo': 'https://example.org/poster.jpg',
        'links': [
          {'url': 'https://a.example.org/video.mp4', 'quality': '1080p'},
          {'url': 'https://b.example.org/video.m3u8', 'quality': '720p'},
        ]},
    }, type: 'movie', category: 'Hollywood', sourceUrl: 'https://source.example.org/catalog.json');
    expect(rows, hasLength(1));
    expect(rows.first.title, 'Film (2026)');
    expect(rows.first.streams, hasLength(2));
    expect(rows.first.primaryStream, 'https://a.example.org/video.mp4');
    expect(rows.first.genres, ['Hollywood']);
    expect(rows.first.releaseYear, 2026);
  });

  test('series groups seasons and episodes with alternate sources', () {
    final shows = CatalogParser.parse({
      'Drama (TV Series)': {'links': [
        {'url': 'https://a.example.org/s1e1.mkv', 'season': 1, 'episode': 1, 'episode_title': '1080p'},
        {'url': 'https://b.example.org/s1e1.mkv', 'season': 1, 'episode': 1, 'episode_title': '720p'},
        {'url': 'https://a.example.org/s1e2.mkv', 'season': 1, 'episode': 2},
        {'url': 'https://a.example.org/s2e1.mkv', 'season': 2, 'episode': 1},
      ]}
    }, type: 'series', category: 'English Series', sourceUrl: 'https://source.example.org/shows.json');
    expect(shows.single.isSeries, isTrue);
    expect(shows.single.seasons, hasLength(2));
    expect(shows.single.seasons.first.episodes, hasLength(2));
    expect(shows.single.seasons.first.episodes.first.sources, hasLength(2));
  });

  test('live channel grouped JSON and direct URLs', () {
    final tv = CatalogParser.parse({
      'News': [{'name': 'Channel A', 'url': 'https://a.example.org/live.m3u8', 'tvg_logo': 'https://a.example.org/logo.png'}],
      'Sports': {'Channel B': {'stream_url': 'https://b.example.org/live.m3u8'}},
    }, type: 'livetv', category: 'Live TV', sourceUrl: 'https://source.example.org/live.json');
    expect(tv, hasLength(2));
    expect(tv[0].genres, ['News']);
    expect(tv[1].isLive, isTrue);
  });

  test('does not treat website pages as playable movie link sources', () {
    final movies = CatalogParser.parse({
      'Web only': {'links': [{'url': 'https://example.org/cn/film/'}, {'url': 'https://example.org/poster.jpg'}]},
    }, type: 'movie', category: 'Bollywood', sourceUrl: 'https://source.example.org/catalog.json');
    expect(movies.single.streams, isEmpty);
    expect(movies.single.hasStream, isFalse);
  });

  test('server config normalization', () {
    final raw = jsonDecode('{"name":"Server 2","api_config":{"live_tv_url":"https://example.org/tv.json","movie_categories":[{"name":"Hollywood","url":"https://example.org/m.json"}],"series_categories":[],"maintenance":false}}');
    final server = CatalogServer.fromJson(Map<String, dynamic>.from(raw));
    expect(server.movies.single.name, 'Hollywood');
    expect(server.maintenance, isFalse);
  });
}
