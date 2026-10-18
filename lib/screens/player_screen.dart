import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem movie;
  final String streamUrl;
  final Episode? episode;
  const PlayerScreen({super.key, required this.movie, required this.streamUrl, this.episode});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  StreamSubscription<Duration>? progressSub;
  StreamSubscription<String>? errorSub;
  Duration currentPosition = Duration.zero;
  Duration duration = Duration.zero;
  int lastHistorySecond = 0;
  String? playbackError;
  bool landscape = false;
  late AppState _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.streamUrl)).catchError((Object error) {
      if (mounted) {
      setState(() => playbackError = error.toString());
    }
    });
    progressSub = player.stream.position.listen((value) {
      currentPosition = value;
      duration = player.state.duration;
      if (mounted) {
      setState(() {});
    }
      if (value.inSeconds - lastHistorySecond >= 30) {
        lastHistorySecond = value.inSeconds;
        _writeHistory();
      }
    });
    errorSub = player.stream.error.listen((error) {
      if (mounted) {
      setState(() => playbackError = error);
    }
    });
  }

  void _writeHistory() {
    if (accountsEnabled && _app.api != null && _app.loggedIn && !widget.movie.isLive) {
      _app.api?.saveHistory(widget.movie.id, currentPosition, duration).catchError((Object _) {});
    }
  }

  Future<void> _toggleFullScreen() async {
    if (!landscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) {
      setState(() => landscape = !landscape);
    }
  }

  @override
  void dispose() {
    _writeHistory();
    progressSub?.cancel();
    errorSub?.cancel();
    player.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _videoSurface() => Stack(fit: StackFit.expand, children: [
    Video(controller: controller, fit: BoxFit.contain),
    if (playbackError != null) ColoredBox(color: const Color(0xF0000000), child: Center(
      child: Padding(padding: const EdgeInsets.all(25), child: Column(mainAxisSize: MainAxisSize.min,
        children: [const Icon(Icons.error_outline, color: AppColors.red, size: 44),
          const SizedBox(height: 12), const Text('Playback failed', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 7), Text(playbackError!, textAlign: TextAlign.center),
          const SizedBox(height: 12), OutlinedButton(onPressed: () {
            setState(() => playbackError = null);
            player.open(Media(widget.streamUrl));
          }, child: const Text('Retry'))])))),
  ]);

  String _clock(Duration d) => '${d.inHours > 0 ? '${d.inHours}:' : ''}${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final full = landscape;
    final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final position = currentPosition.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
    return Scaffold(
      appBar: full ? null : AppBar(title: Text(widget.episode?.title ?? widget.movie.title,
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(child: Column(children: [
        if (full) Expanded(child: _videoSurface())
        else AspectRatio(aspectRatio: 16 / 9, child: _videoSurface()),
        ColoredBox(color: const Color(0xFF101017), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(onPressed: () => player.seek(currentPosition.inSeconds < 10 ? Duration.zero : currentPosition - const Duration(seconds: 10)),
              icon: const Icon(Icons.replay_10)),
            StreamBuilder<bool>(stream: player.stream.playing, initialData: false, builder: (_, snapshot) =>
              IconButton(onPressed: () => player.playOrPause(),
                icon: Icon(snapshot.data == true ? Icons.pause : Icons.play_arrow, color: AppColors.teal))),
            IconButton(onPressed: () => player.seek(currentPosition + const Duration(seconds: 10)),
              icon: const Icon(Icons.forward_10)),
            const Spacer(),
            PopupMenuButton<double>(tooltip: 'Speed', onSelected: (value) => player.setRate(value),
              icon: const Icon(Icons.speed), itemBuilder: (_) => [0.5, 1.0, 1.25, 1.5, 2.0]
                .map((value) => PopupMenuItem(value: value, child: Text('${value}x'))).toList()),
            IconButton(tooltip: 'Fullscreen', onPressed: _toggleFullScreen,
              icon: Icon(full ? Icons.fullscreen_exit : Icons.fullscreen)),
          ]),
          Row(children: [
            const SizedBox(width: 9),
            Text(_clock(currentPosition), style: const TextStyle(fontSize: 11)),
            Expanded(child: Slider(value: position, max: max, activeColor: AppColors.teal,
              onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())))),
            Text(_clock(duration), style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 9),
          ]),
        ])),
        if (!full) Expanded(child: Padding(padding: const EdgeInsets.all(20), child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.movie.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 23)),
            const SizedBox(height: 7),
            Text(widget.movie.isLive ? 'LIVE NOW' : (widget.episode?.title ?? '${widget.movie.releaseYear} • ${widget.movie.quality}'),
              style: const TextStyle(color: AppColors.teal)),
            const SizedBox(height: 17),
            Text(widget.movie.description, maxLines: 6, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            if (widget.movie.subtitles.isNotEmpty) const Text('External subtitles are listed in the metadata; track switching depends on the stream/player.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]))),
      ])),
    );
  }
}
