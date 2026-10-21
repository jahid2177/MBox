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
  // Change only the current server's Live TV feed. No demo URL is added.
  Future<void> _editLiveTvSource() async {
    final app = AppScope.of(context);
    if (app.servers.isEmpty) {
      return;
    }
    final controller = TextEditingController(text: app.liveTvUrl);
    var checking = false;
    String? validationMessage;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('${app.currentServer} — Live TV source'),
            content: SizedBox(
              width: 570,
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Paste a publicly accessible HTTPS JSON URL for this server. '
                    'If the source returns HTTP 404, verify the exact GitHub Raw path.'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  minLines: 2, maxLines: 4,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Live TV JSON URL', border: OutlineInputBorder()),
                ),
                if (validationMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(validationMessage!, style: const TextStyle(color: Colors.orangeAccent)),
                ],
                if (checking) const Padding(
                  padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              ]),
            ),
            actions: [
              TextButton(onPressed: checking ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              if (app.hasCustomLiveTvUrl)
                TextButton(onPressed: checking ? null : () async {
                  Navigator.pop(dialogContext);
                  await app.resetLiveTvUrl();
                }, child: const Text('Restore original')),
              FilledButton(
                onPressed: checking ? null : () async {
                  final url = controller.text.trim();
                  setDialogState(() {
                    checking = true;
                    validationMessage = 'Checking JSON and channel entries…';
                  });
                  try {
                    final count = await app.sources.validateLiveTvUrl(url);
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await app.setLiveTvUrl(url);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Live TV source saved: $count channels found.')));
                    }
                  } catch (e) {
                    if (!dialogContext.mounted) {
                      return;
                    }
                    setDialogState(() {
                      validationMessage = e.toString()
                          .replaceFirst('FormatException: ', '');
                      checking = false;
                    });
                  }
                },
                child: const Text('Verify & Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // Category values come from the supplied JSON, not demo data.
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final categories = ['All', ...{for (final c in app.liveChannels) ...c.genres}];
    final channels = app.liveChannels.where((m) =>
      m.title.toLowerCase().contains(search.toLowerCase()) &&
      (category == 'All' || m.genres.any((g) => g.toLowerCase() == category.toLowerCase()))).toList();
    final liveProblems = app.warnings.where((w) => w.startsWith('Live TV:')).toList();
    final liveProblem = liveProblems.isEmpty ? null : liveProblems.first;
    return RefreshIndicator(onRefresh: app.refresh, child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 12), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.live_tv_rounded, color: AppColors.red),
            const SizedBox(width: 9),
            const Flexible(child: Text('Live TV',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _editLiveTvSource,
              tooltip: 'Configure Live TV JSON URL',
              icon: const Icon(Icons.settings_input_antenna_rounded, color: AppColors.teal),
            ),
          ]),
          const SizedBox(height: 5),
          Text('${app.liveChannels.length} channels available', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(onChanged: (value) => setState(() => search = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find a TV channel')),
          const SizedBox(height: 13),
          SizedBox(height: 44, child: ListView.separated(scrollDirection: Axis.horizontal,
            separatorBuilder: (context, index) => const SizedBox(width: 7), itemCount: categories.length,
            itemBuilder: (_, i) => ChoiceChip(label: Text(categories[i]), selected: category == categories[i],
              showCheckmark: false, selectedColor: Colors.white,
              labelStyle: TextStyle(color: category == categories[i] ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => category = categories[i])))),
        ]))),
      if (app.loading && channels.isEmpty && liveProblem == null)
        const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
      else if (channels.isEmpty) SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  liveProblem ?? app.error ??
                    'No Live TV channels found in the selected server.',
                  textAlign: TextAlign.center,
                ),
                if (app.liveTvUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Current source URL:',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 5),
                  SelectableText(app.liveTvUrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 12,
                  runSpacing: 8, children: [
                  FilledButton(onPressed: app.refresh, child: const Text('Retry')),
                  OutlinedButton.icon(
                    onPressed: _editLiveTvSource,
                    icon: const Icon(Icons.edit_link),
                    label: const Text('Change Live TV URL')),
                ]),
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
              return _LiveChannelCard(
                channel: m, onTap: () => widget.onSelect(m));
            },
          );
        })),
    ]));
  }
}

/// A focus-visible tile for TV remote/keyboard and touch navigation.
class _LiveChannelCard extends StatefulWidget {
  final MediaItem channel;
  final VoidCallback onTap;
  const _LiveChannelCard({required this.channel, required this.onTap});

  @override
  State<_LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends State<_LiveChannelCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: const Duration(milliseconds: 160),
    scale: focused ? 1.035 : 1,
    child: InkWell(
      onFocusChange: (value) => setState(() => focused = value),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.card,
          border: Border.all(
            color: focused ? Colors.white : Colors.white12,
            width: focused ? 2.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(fit: StackFit.expand, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 37),
              child: ArtImage(url: widget.channel.posterUrl,
                icon: Icons.live_tv_rounded, fit: BoxFit.contain),
            ),
            Positioned(top: 8, left: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.red,
                borderRadius: BorderRadius.circular(3)),
              child: const Text('LIVE', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900)),
            )),
            Align(alignment: Alignment.bottomCenter, child: Container(
              width: double.infinity,
              color: const Color(0xE4000000),
              padding: const EdgeInsets.all(9),
              child: Text(widget.channel.title, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    ),
  );
}
