import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';

/// Posters are real catalog artwork. No sample movies or placeholder URLs.
/// InkWell's default ActivateIntent allows Enter, Space and Android TV D-pad.
class MediaPoster extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  const MediaPoster({super.key, required this.item, required this.onTap, this.width = 138});

  @override
  State<MediaPoster> createState() => _MediaPosterState();
}

class _MediaPosterState extends State<MediaPoster> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedScale(
      scale: focused ? 1.045 : 1,
      duration: const Duration(milliseconds: 155),
      curve: Curves.easeOut,
      child: InkWell(
        onFocusChange: (value) => setState(() => focused = value),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        focusColor: Colors.transparent,
        child: SizedBox(width: widget.width, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: focused ? Colors.white : Colors.white10,
                  width: focused ? 2.5 : 0.75,
                ),
                boxShadow: focused ? [const BoxShadow(
                  color: Colors.black87, blurRadius: 22, offset: Offset(0, 6))] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(fit: StackFit.expand, children: [
                  ArtImage(url: item.posterUrl.isEmpty ? item.backdropUrl : item.posterUrl,
                    icon: item.isLive ? Icons.live_tv_rounded : Icons.movie_outlined),
                  if (item.isLive) Positioned(top: 7, left: 7,
                    child: _chip('LIVE', AppColors.red)),
                  if (item.tier.toLowerCase() == 'vip') Positioned(
                    top: 7, right: 7, child: _chip('VIP', const Color(0xFFAD8025))),
                  if (focused) const Align(alignment: Alignment.center,
                    child: CircleAvatar(backgroundColor: Color(0xD9000000),
                      radius: 22, child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30))),
                ]),
              ),
            )),
            const SizedBox(height: 7),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              if (item.releaseYear > 0) Text('${item.releaseYear}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              if (item.rating > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star, size: 11, color: Color(0xFFFFCF42)),
                const SizedBox(width: 3),
                Text(item.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ]),
          ],
        )),
      ),
    );
  }
}

Widget _chip(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
  child: Text(text, style: const TextStyle(color: Colors.white,
    fontSize: 10, fontWeight: FontWeight.w800)),
);

class ArtImage extends StatelessWidget {
  final String url;
  final IconData icon;
  final BoxFit fit;
  const ArtImage({super.key, required this.url,
    this.icon = Icons.movie_filter_outlined, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => url.trim().isEmpty
      ? _fallback()
      : Image.network(url, fit: fit,
          errorBuilder: (_, error, stack) => _fallback(),
          loadingBuilder: (_, child, progress) => progress == null ? child :
            Stack(fit: StackFit.expand, children: [_fallback(),
              Center(child: CircularProgressIndicator(
                value: progress.expectedTotalBytes == null ? null :
                  progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
                strokeWidth: 2, color: AppColors.red,
              )),
            ]));

  Widget _fallback() => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      colors: [Color(0xFF323232), Color(0xFF111111)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Icon(icon, color: Colors.white30, size: 42)),
  );
}

class MediaRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;
  final IconData icon;
  const MediaRow({super.key, required this.title, required this.items,
    required this.onTap, this.icon = Icons.movie_outlined});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width > 700;
    final tv = MediaQuery.sizeOf(context).width > 1500;
    final posterWidth = tv ? 188.0 : wide ? 158.0 : 124.0;
    final height = tv ? 348.0 : wide ? 295.0 : 243.0;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 35 : 17),
          child: Row(children: [
            Container(width: 4, height: 22,
              decoration: BoxDecoration(color: AppColors.red,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: TextStyle(fontSize: tv ? 25 : wide ? 21 : 17,
                fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ]),
        ),
        const SizedBox(height: 13),
        SizedBox(height: height, child: ListView.separated(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: wide ? 35 : 17, vertical: 4),
          itemBuilder: (_, i) => MediaPoster(
            item: items[i], onTap: () => onTap(items[i]), width: posterWidth),
          separatorBuilder: (_, index) => const SizedBox(width: 12),
          itemCount: items.length,
        )),
      ]),
    );
  }
}

void showErrorSnack(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error.toString().replaceFirst('Exception: ', '')),
      backgroundColor: const Color(0xFF9C2936),
    ));
  }
}
