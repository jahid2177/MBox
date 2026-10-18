import 'package:flutter/material.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'player_screen.dart';

class DetailScreen extends StatelessWidget {
  final MediaItem movie;
  const DetailScreen({super.key, required this.movie});

  Future<void> _play(BuildContext context, {Episode? episode}) async {
    final sources = episode == null ? movie.streams : episode.sources;
    String url = episode?.videoUrl ?? movie.primaryStream;
    if (sources.length > 1) {
      final selected = await showModalBottomSheet<StreamSource>(context: context,
        isScrollControlled: true, builder: (sheetContext) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select video source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(height: (sources.length * 72.0).clamp(72.0, MediaQuery.sizeOf(sheetContext).height * 0.55).toDouble(),
            child: ListView(shrinkWrap: true, children: sources.asMap().entries.map((e) => ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(e.value.displayName),
            subtitle: Text(Uri.parse(e.value.url).host),
            onTap: () => Navigator.pop(sheetContext, e.value),
          )).toList())),
        ]))));
      if (selected == null) return;
      url = selected.url;
    }
    if (!context.mounted) return;
    if (url.trim().isEmpty) {
      showErrorSnack(context, 'No playable stream URL available for this item.');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      movie: movie, streamUrl: url, episode: episode)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hasSeasons = movie.seasons.isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Scaffold(
      appBar: AppBar(title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: wide ? 21 / 8 : 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              ArtImage(url: movie.backdropUrl.isEmpty ? movie.posterUrl : movie.backdropUrl),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.bg], begin: Alignment.center, end: Alignment.bottomCenter))),
              Center(child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.black,
                  minimumSize: const Size(68, 68)),
                onPressed: movie.hasStream ? () => _play(context) : null, icon: const Icon(Icons.play_arrow_rounded, size: 37))),
            ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(movie.title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 9, children: [
              Text('${movie.releaseYear}', style: const TextStyle(color: AppColors.muted)),
              Text('★ ${movie.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber)),
              if (movie.quality.isNotEmpty) Text(movie.quality, style: const TextStyle(color: AppColors.teal)),
              if (movie.duration > 0) Text('${movie.duration} min', style: const TextStyle(color: AppColors.muted)),
              if (movie.tier == 'vip') const Text('VIP', style: TextStyle(color: Colors.amber)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              FilledButton.icon(onPressed: movie.hasStream ? () => _play(context) : null,
                icon: const Icon(Icons.play_arrow), label: Text(movie.isLive ? 'Watch Live' : 'Play'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.black)),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: () async {
                                try { await app.toggleFavorite(movie); }
                catch (e) { if (context.mounted) showErrorSnack(context, e); }
              }, icon: Icon(app.favoriteIds.contains(movie.id) ? Icons.check : Icons.add),
                label: Text(app.favoriteIds.contains(movie.id) ? 'In My List' : 'My List')),
            ]),
            const SizedBox(height: 20),
            Text(movie.description.isEmpty ? 'No synopsis available.' : movie.description,
              style: const TextStyle(height: 1.6, color: Color(0xFFCFD0D7))),
            if (movie.genres.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child:
              Text('Genres: ${movie.genres.join(' • ')}', style: const TextStyle(color: AppColors.muted))),
            if (movie.cast.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child:
              Text('Cast: ${movie.cast.take(8).join(', ')}', style: const TextStyle(color: AppColors.muted))),
            if (hasSeasons) ...[
              const SizedBox(height: 25), const Text('Episodes', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              for (final season in movie.seasons) ...[
                const SizedBox(height: 15), Text('Season ${season.number}${season.title.isEmpty ? '' : ' • ${season.title}'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.teal)),
                for (final episode in season.episodes)
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.play_circle_outline, size: 34),
                    title: Text('${episode.number}. ${episode.title}'),
                    subtitle: Text('${episode.sources.length} source(s) · ${episode.duration > 0 ? '${episode.duration} min' : 'Video'}'),
                    enabled: episode.videoUrl.isNotEmpty,
                    onTap: () => _play(context, episode: episode)),
              ],
            ],
          ])),
        ]),
      ))),
    );
  }
}
