import 'package:flutter/material.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';

class LiveScreen extends StatefulWidget {
  final ValueChanged<MediaItem> onSelect;
  final VoidCallback onLogin;
  const LiveScreen({super.key, required this.onSelect, required this.onLogin});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  String search = '';
  String category = 'All';
  // Category values come from the supplied JSON, not demo data.
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final categories = ['All', ...{for (final c in app.liveChannels) ...c.genres}];
    final channels = app.liveChannels.where((m) =>
      m.title.toLowerCase().contains(search.toLowerCase()) &&
      (category == 'All' || m.genres.any((g) => g.toLowerCase() == category.toLowerCase()))).toList();
    return RefreshIndicator(onRefresh: app.refresh, child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 12), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.sensors, color: AppColors.red), SizedBox(width: 9),
            Text('Live Television', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 5),
          Text('${app.liveChannels.length} channels available', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find a TV channel')),
          const SizedBox(height: 13),
          SizedBox(height: 39, child: ListView.separated(scrollDirection: Axis.horizontal,
            separatorBuilder: (context, index) => const SizedBox(width: 7), itemCount: categories.length,
            itemBuilder: (_, i) => ChoiceChip(label: Text(categories[i]), selected: category == categories[i],
              showCheckmark: false, selectedColor: AppColors.teal,
              labelStyle: TextStyle(color: category == categories[i] ? Colors.black : Colors.white),
              onSelected: (_) => setState(() => category = categories[i])))),
        ]))),
      if (app.loading && channels.isEmpty) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
      else if (channels.isEmpty) SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  app.error ?? (app.warnings.isEmpty
                    ? 'No Live TV channels found in the selected server.'
                    : 'Live TV feed unavailable: ${app.warnings.first}'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: app.refresh, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      )
      else SliverPadding(padding: const EdgeInsets.all(16), sliver:
        SliverLayoutBuilder(builder: (context, constraints) {
          final cols = (constraints.crossAxisExtent / 210).floor().clamp(2, 6).toInt();
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
            itemCount: channels.length,
            itemBuilder: (_, i) {
              final m = channels[i];
              return InkWell(onTap: () {
                widget.onSelect(m);
              }, child: Card(clipBehavior: Clip.antiAlias, child: Stack(fit: StackFit.expand, children: [
                ArtImage(url: m.posterUrl, icon: Icons.live_tv, fit: BoxFit.contain),
                const Positioned(top: 7, left: 7, child: Icon(Icons.circle, size: 10, color: AppColors.red)),
                Align(alignment: Alignment.bottomCenter, child: Container(
                  color: const Color(0xC7000000), padding: const EdgeInsets.all(8),
                  child: Text(m.title, maxLines: 1, textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)))),
              ])));
            },
          );
        })),
    ]));
  }
}
