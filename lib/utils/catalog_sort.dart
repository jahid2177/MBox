import '../models/media_item.dart';

enum CatalogSort { newest, oldest, title, rating }

extension CatalogSortLabel on CatalogSort {
  String get label => switch (this) {
    CatalogSort.newest => 'Year: Newest first',
    CatalogSort.oldest => 'Year: Oldest first',
    CatalogSort.title => 'Title: A–Z',
    CatalogSort.rating => 'Highest rated',
  };
}

/// Missing years always appear after known years, even when sorting oldest-first.
/// Original input is not mutated; stable tie-breaks make incremental loading calm.
List<MediaItem> sortCatalog(Iterable<MediaItem> items, CatalogSort order) {
  final result = List<MediaItem>.of(items);
  int byName(MediaItem a, MediaItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int byYear(MediaItem a, MediaItem b, {required bool newestFirst}) {
    if (a.releaseYear <= 0 && b.releaseYear > 0) return 1;
    if (b.releaseYear <= 0 && a.releaseYear > 0) return -1;
    final diff = newestFirst
        ? b.releaseYear.compareTo(a.releaseYear)
        : a.releaseYear.compareTo(b.releaseYear);
    return diff == 0 ? byName(a, b) : diff;
  }

  result.sort((a, b) => switch (order) {
        CatalogSort.newest => byYear(a, b, newestFirst: true),
        CatalogSort.oldest => byYear(a, b, newestFirst: false),
        CatalogSort.title => byName(a, b),
        CatalogSort.rating => b.rating.compareTo(a.rating) == 0
            ? byYear(a, b, newestFirst: true)
            : b.rating.compareTo(a.rating),
      });
  return result;
}
