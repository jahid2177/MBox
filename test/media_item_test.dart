import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/models/media_item.dart';

void main() {
  test('parses movie fields and numeric strings', () {
    final item = MediaItem.fromJson({
      'id': 'mov-1', 'title': 'Example Movie', 'rating': '8.7', 'releaseYear': 2026,
      'genres': ['Action', 'Adventure'], 'contentType': 'movie',
    });
    expect(item.title, 'Example Movie');
    expect(item.rating, 8.7);
    expect(item.genres, ['Action', 'Adventure']);
    expect(item.isLive, false);
  });

  test('parses seasons and episodes', () {
    final item = MediaItem.fromJson({
      'id': 's1', 'title': 'Show', 'contentType': 'series',
      'seasons': [{'seasonNumber': 1, 'episodes': [
        {'id': 'e1', 'episodeNumber': 1, 'title': 'Pilot', 'videoUrl': 'https://example.com/pilot.m3u8'}
      ]}]
    });
    expect(item.isSeries, true);
    expect(item.primaryStream, 'https://example.com/pilot.m3u8');
    expect(item.seasons.first.episodes.first.number, 1);
  });

  test('live tv inferred from tv prefix', () {
    final item = MediaItem.fromJson({'id': 'tv-1', 'title': 'Channel'});
    expect(item.isLive, true);
  });
}
