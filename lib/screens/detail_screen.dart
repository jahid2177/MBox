import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'player_screen.dart';

/// A cinematic detail page with source chooser, local My List and episodes.
class DetailScreen extends StatelessWidget {
  final MediaItem movie;
  const DetailScreen({super.key, required this.movie});

  Future<void> _play(BuildContext context, {Episode? episode}) async {
    final sources = episode == null ? movie.streams : episode.sources;
    String url = episode?.videoUrl ?? movie.primaryStream;
    if (url.trim().isEmpty && sources.isNotEmpty) {
      url = sources.first.url;
    }

    if (sources.length > 1) {
      final choice = await showModalBottomSheet<StreamSource>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (sheetContext) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose streaming source',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SizedBox(
              height: (sources.length * 70.0).clamp(72.0,
                MediaQuery.sizeOf(sheetContext).height * .55).toDouble(),
              child: ListView(children: [
                for (final source in sources)
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline_rounded,
                      color: AppColors.red),
                    title: Text(source.displayName),
                    subtitle: Text(Uri.tryParse(source.url)?.host ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(sheetContext, source),
                  ),
              ]),
            ),
          ]),
        )),
      );
      if (choice == null) return;
      url = choice.url;
    }
    if (!context.mounted) return;
    if (url.trim().isEmpty) {
      showErrorSnack(context, 'No playable stream URL is available.');
      return;
    }
    await Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(
        movie: movie, streamUrl: url, episode: episode)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 780;
    final maxWidth = wide ? 1250.0 : 780.0;
    final hasSeasons = movie.seasons.isNotEmpty;
    final saved = app.favoriteIds.contains(movie.id);
    final artwork = movie.backdropUrl.isNotEmpty ?
      movie.backdropUrl : movie.posterUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MBOX', style: TextStyle(
          fontWeight: FontWeight.w900, color: AppColors.red,
          letterSpacing: 1.2)),
      ),
      body: SingleChildScrollView(
        child: Center(child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: wide ? 490 : 305,
                child: Stack(fit: StackFit.expand, children: [
                  ArtImage(url: artwork),
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA090909), AppColors.bg],
                      stops: [0, .52, 1],
                    ),
                  )),
                  Padding(
                    padding: EdgeInsets.all(wide ? 35 : 19),
                    child: Align(alignment: Alignment.bottomLeft,
                      child: Column(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(movie.title,
                            maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w900,
                              height: 1.1, fontSize: wide ? 44 : 29)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 12, runSpacing: 7, children: [
                            if (movie.releaseYear > 0) Text('${movie.releaseYear}'),
                            if (movie.rating > 0) Text('★ ${movie.rating.toStringAsFixed(1)}',
                              style: const TextStyle(color: Color(0xFFFFCE54))),
                            if (movie.quality.isNotEmpty) Text(movie.quality),
                            Text(movie.isLive ? 'LIVE' : movie.isSeries ? 'SERIES' : 'MOVIE',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (movie.duration > 0) Text('${movie.duration} min'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 35 : 19, 8,
                  wide ? 35 : 19, 34),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      FilledButton.icon(
                        onPressed: movie.hasStream ? () => _play(context) : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 27),
                        label: Text(movie.isLive ? 'Watch live' : 'Play',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(148, 50)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await app.toggleFavorite(movie);
                          } catch (error) {
                            if (context.mounted) showErrorSnack(context, error);
                          }
                        },
                        icon: Icon(saved ? Icons.check_rounded : Icons.add_rounded),
                        label: Text(saved ? 'Added to My List' : 'My List'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(148, 50)),
                      ),
                    ]),
                    const SizedBox(height: 23),
                    Text(movie.description.trim().isEmpty ?
                      'No synopsis has been provided for this title.' : movie.description,
                      style: TextStyle(fontSize: wide ? 16 : 14,
                        height: 1.55, color: const Color(0xFFEEEEEE))),
                    if (movie.genres.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 17),
                      child: Text('Genres  ${movie.genres.join(' • ')}',
                        style: const TextStyle(color: AppColors.muted))),
                    if (movie.cast.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Cast  ${movie.cast.take(8).join(', ')}',
                        style: const TextStyle(color: AppColors.muted))),
                    if (hasSeasons) ...[
                      const SizedBox(height: 36),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Episodes', style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900)),
                      for (final season in movie.seasons) ...[
                        const SizedBox(height: 20),
                        Text('Season ${season.number}${season.title.isEmpty ? '' : ' · ${season.title}'}',
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        for (final episode in season.episodes)
                          _EpisodeTile(
                            episode: episode,
                            onTap: () => _play(context, episode: episode)),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;
  const _EpisodeTile({required this.episode, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        enabled: episode.videoUrl.isNotEmpty || episode.sources.isNotEmpty,
        onTap: onTap,
        leading: Container(
          width: 67, height: 60,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(5)),
          child: const Icon(Icons.play_circle_outline_rounded,
            color: Colors.white, size: 34),
        ),
        title: Text('${episode.number}. ${episode.title}',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(episode.duration > 0 ? '${episode.duration} min' :
            '${episode.sources.length} streaming source(s)',
            style: const TextStyle(color: AppColors.muted)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
}
