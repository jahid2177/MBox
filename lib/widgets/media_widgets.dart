import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

class MediaPoster extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  const MediaPoster({super.key, required this.item, required this.onTap, this.width = 132});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(fit: StackFit.expand, children: [
                  ArtImage(url: item.posterUrl, icon: item.isLive ? Icons.live_tv : Icons.movie),
                  if (item.tier.toLowerCase() == 'vip')
                    Positioned(top: 8, right: 8, child: _chip('VIP', Colors.amber.shade700)),
                  if (item.isLive) Positioned(top: 8, left: 8, child: _chip('LIVE', AppColors.red)),
                ]),
              ),
            ),
            const SizedBox(height: 7),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${item.releaseYear == 0 ? '' : item.releaseYear}  ${item.rating > 0 ? '★ ${item.rating.toStringAsFixed(1)}' : ''}',
                maxLines: 1, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      );
}

Widget _chip(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
  child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
);

class ArtImage extends StatelessWidget {
  final String url;
  final IconData icon;
  final BoxFit fit;
  const ArtImage({super.key, required this.url, this.icon = Icons.movie_filter, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) => url.trim().isEmpty
      ? _fallback()
      : Image.network(url, fit: fit, errorBuilder: (context, error, stack) => _fallback(),
          loadingBuilder: (context, child, progress) => progress == null ? child :
              Stack(fit: StackFit.expand, children: [_fallback(), Center(child: CircularProgressIndicator(
                value: progress.expectedTotalBytes == null ? null : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                strokeWidth: 2, color: AppColors.teal,
              ))]));

  Widget _fallback() => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF24293B), Color(0xFF101017)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Icon(icon, color: Colors.white30, size: 45)),
  );
}

class MediaRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final IconData icon;
  const MediaRow({super.key, required this.title, required this.items, required this.onTap, this.icon = Icons.movie});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [Icon(icon, size: 19, color: AppColors.teal), const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: wide ? 22 : 17, fontWeight: FontWeight.w800))]),
        ),
        const SizedBox(height: 13),
        SizedBox(height: wide ? 306 : 247, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemBuilder: (_, i) => MediaPoster(item: items[i], onTap: () => onTap(items[i]), width: wide ? 168 : 133),
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemCount: items.length,
        )),
      ]),
    );
  }
}

void showErrorSnack(BuildContext context, Object error) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error.toString().replaceFirst('Exception: ', '')),
    backgroundColor: const Color(0xFF9C2936),
  ));
}
