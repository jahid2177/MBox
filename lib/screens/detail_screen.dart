import 'package:flutter/material.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'auth_screen.dart';
import 'player_screen.dart';

class DetailScreen extends StatelessWidget {
  final MediaItem movie;
  const DetailScreen({super.key, required this.movie});

  Future<void> _play(BuildContext context, {Episode? episode}) async {
    final app = AppScope.of(context);
    if (!app.loggedIn && !demoMode) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!context.mounted || !app.loggedIn) {
      return;
    }
    }
    if (!context.mounted) {
      return;
    }
    if (movie.tier == 'vip' && app.user?.isPremium != true && !demoMode) {
      showErrorSnack(context, 'VIP content requires an active premium subscription.');
      return;
    }
    final url = episode?.videoUrl ?? movie.primaryStream;
    if (url.isEmpty) { showErrorSnack(context, 'No stream URL configured for this title.'); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(movie: movie,
      streamUrl: url, episode: episode)));
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
                if (!app.loggedIn && !demoMode) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                  if (!context.mounted || !app.loggedIn) {
      return;
    }
                }
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
                    subtitle: Text('${episode.duration} min'),
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
