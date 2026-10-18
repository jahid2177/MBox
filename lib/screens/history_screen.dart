import 'package:flutter/material.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<dynamic>> historyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    historyFuture = AppScope.of(context).api!.history();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Watch History')),
    body: FutureBuilder<List<dynamic>>(future: historyFuture, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Could not load watch history: ${snapshot.error}'));
      final items = snapshot.data ?? [];
      if (items.isEmpty) return const Center(child: Text('Your watch history is empty.',
        style: TextStyle(color: AppColors.muted)));
      return ListView.builder(itemCount: items.length, itemBuilder: (context, index) {
        final entry = items[index];
        if (entry is! Map || entry['movie'] is! Map) return const SizedBox.shrink();
        final movie = MediaItem.fromJson(Map<String, dynamic>.from(entry['movie'] as Map));
        final duration = (entry['duration'] as num?)?.toDouble() ?? 0;
        final progress = (entry['progress'] as num?)?.toDouble() ?? 0;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: SizedBox(width: 60, child: ArtImage(url: movie.posterUrl)),
          title: Text(movie.title),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: duration > 0 ? (progress / duration).clamp(0.0, 1.0).toDouble() : 0.0,
              backgroundColor: AppColors.surface, color: AppColors.teal),
            const SizedBox(height: 5),
            Text('${progress.toInt()} of ${duration.toInt()} seconds', style: const TextStyle(color: AppColors.muted)),
          ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(movie: movie))),
        );
      });
    }),
  );
}
