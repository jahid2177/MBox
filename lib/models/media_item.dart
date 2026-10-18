class Episode {
  final String id;
  final String title;
  final String videoUrl;
  final int number;
  final int duration;
  const Episode({required this.id, required this.title, required this.videoUrl, required this.number, required this.duration});
  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        videoUrl: '${json['videoUrl'] ?? ''}',
        number: _int(json['episodeNumber']),
        duration: _int(json['duration']),
      );
}

class Season {
  final int number;
  final String title;
  final List<Episode> episodes;
  const Season(this.number, this.title, this.episodes);
  factory Season.fromJson(Map<String, dynamic> json) => Season(
    _int(json['seasonNumber']),
    '${json['title'] ?? ''}',
    _maps(json['episodes']).map(Episode.fromJson).toList(),
  );
}

class Subtitle {
  final String language;
  final String label;
  final String url;
  const Subtitle(this.language, this.label, this.url);
  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    '${json['language'] ?? ''}', '${json['label'] ?? ''}', '${json['fileUrl'] ?? json['url'] ?? ''}',
  );
}

class MediaItem {
  final String id;
  final String title;
  final String description;
  final String posterUrl;
  final String backdropUrl;
  final String videoUrl;
  final String contentType;
  final int releaseYear;
  final int duration;
  final double rating;
  final String quality;
  final String tier;
  final List<String> genres;
  final List<String> cast;
  final List<Season> seasons;
  final List<Subtitle> subtitles;
  final bool isFeatured;

  const MediaItem({
    required this.id, required this.title, this.description = '', this.posterUrl = '',
    this.backdropUrl = '', this.videoUrl = '', this.contentType = 'movie',
    this.releaseYear = 0, this.duration = 0, this.rating = 0, this.quality = '',
    this.tier = 'free', this.genres = const [], this.cast = const [],
    this.seasons = const [], this.subtitles = const [], this.isFeatured = false,
  });

  bool get isLive => contentType == 'livetv' || id.startsWith('tv-');
  bool get isSeries => contentType == 'series';
  bool get hasStream => videoUrl.trim().isNotEmpty || seasons.any((s) => s.episodes.any((e) => e.videoUrl.trim().isNotEmpty));
  String get primaryStream => videoUrl.trim().isNotEmpty ? videoUrl :
      seasons.expand((s) => s.episodes).where((e) => e.videoUrl.trim().isNotEmpty).map((e) => e.videoUrl).firstOrNull ?? '';

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Untitled'}',
    description: '${json['description'] ?? ''}',
    posterUrl: '${json['posterUrl'] ?? ''}',
    backdropUrl: '${json['backdropUrl'] ?? ''}',
    videoUrl: '${json['videoUrl'] ?? ''}',
    contentType: '${json['contentType'] ?? (('${json['id'] ?? ''}').startsWith('tv-') ? 'livetv' : 'movie')}',
    releaseYear: _int(json['releaseYear'] ?? json['year']),
    duration: _int(json['duration']),
    rating: _double(json['rating']),
    quality: '${json['quality'] ?? ''}',
    tier: '${json['tier'] ?? 'free'}',
    genres: _strings(json['genres']),
    cast: _strings(json['cast']),
    seasons: _maps(json['seasons']).map(Season.fromJson).toList(),
    subtitles: _maps(json['subtitles']).map(Subtitle.fromJson).toList(),
    isFeatured: json['isFeatured'] == true || json['isBanner'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description, 'posterUrl': posterUrl,
    'backdropUrl': backdropUrl, 'videoUrl': videoUrl, 'contentType': contentType,
    'releaseYear': releaseYear, 'duration': duration, 'rating': rating,
    'quality': quality, 'tier': tier, 'genres': genres,
  };
}

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
List<String> _strings(dynamic value) => value is List ? value.map((e) => '$e').toList() : <String>[];
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
