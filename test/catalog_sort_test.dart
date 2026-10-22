import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamflix_flutter/models/media_item.dart';
import 'package:mystreamflix_flutter/utils/catalog_sort.dart';

void main() {
  final items = [
    const MediaItem(id: 'a', title: 'Old Movie', releaseYear: 2025),
    const MediaItem(id: 'b', title: 'New Movie', releaseYear: 2026),
    const MediaItem(id: 'c', title: 'Unknown', releaseYear: 0),
  ];
  test('newest first, unknown last', () {
    expect(sortCatalog(items, CatalogSort.newest).map((m) => m.id),
        ['b', 'a', 'c']);
  });
  test('oldest first, unknown last', () {
    expect(sortCatalog(items, CatalogSort.oldest).map((m) => m.id),
        ['a', 'b', 'c']);
  });
  test('original list is not modified', () {
    sortCatalog(items, CatalogSort.newest);
    expect(items.first.id, 'a');
  });
}
