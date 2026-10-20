import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// MX-style controls, backed by actual media_kit/MPV track enumeration.
/// Audio languages can be switched only if supplied by the source file.
class PlayerScreen extends StatefulWidget {
  final MediaItem movie;
  final String streamUrl;
  final Episode? episode;
  const PlayerScreen({
    super.key, required this.movie, required this.streamUrl, this.episode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  late AppState app;
  final FocusNode surfaceFocus = FocusNode(debugLabel: 'TV video surface');
  final List<StreamSubscription<dynamic>> subscriptions = [];
  Timer? hideTimer;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration? previewSeek;
  String? playbackError;
  bool controlsVisible = true;
  bool fullScreen = androidTvBuild;
  bool locked = false;
  bool playing = false;
  bool buffering = false;
  bool audioPreferenceApplied = false;
  bool subtitlePreferenceApplied = false;
  double rate = 1.0;
  double volume = 100;
  bool fillVideo = false;
  int lastHistorySecond = 0;
  Offset? doubleTapPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    app = AppScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    // Defer access to inherited AppScope until didChangeDependencies has run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fillVideo = app.fillVideo;
      rate = app.playbackSpeed;
      _listen();
      _open();
      if (androidTvBuild) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        surfaceFocus.requestFocus();
      }
    });
  }

  void _listen() {
    subscriptions.add(player.stream.position.listen((v) {
      if (!mounted) return;
      setState(() { position = v; duration = player.state.duration; });
      if (v.inSeconds - lastHistorySecond >= 30) {
        lastHistorySecond = v.inSeconds;
        _writeHistory();
      }
    }));
    subscriptions.add(player.stream.duration.listen((v) {
      if (mounted) setState(() => duration = v);
    }));
    subscriptions.add(player.stream.playing.listen((v) {
      if (mounted) setState(() => playing = v);
    }));
    subscriptions.add(player.stream.buffering.listen((v) {
      if (mounted) setState(() => buffering = v);
    }));
    subscriptions.add(player.stream.volume.listen((v) {
      if (mounted) setState(() => volume = v);
    }));
    subscriptions.add(player.stream.rate.listen((v) {
      if (mounted) setState(() => rate = v);
    }));
    subscriptions.add(player.stream.error.listen((message) {
      if (mounted) setState(() => playbackError = message);
    }));
    subscriptions.add(player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() {});
      _applyTrackPreferences(tracks);
    }));
    subscriptions.add(player.stream.track.listen((_) {
      if (mounted) setState(() {});
    }));
  }

  Future<void> _open() async {
    audioPreferenceApplied = false;
    subtitlePreferenceApplied = false;
    setState(() => playbackError = null);
    try {
      await player.open(Media(widget.streamUrl), play: app.autoPlay);
      await player.setRate(app.playbackSpeed);
      _applyTrackPreferences(player.state.tracks);
      _showControls();
    } catch (e) {
      if (mounted) setState(() => playbackError = e.toString());
    }
  }

  void _applyTrackPreferences(Tracks tracks) {
    if (!audioPreferenceApplied && app.preferredAudioLanguage != 'auto') {
      final matching = tracks.audio.where((track) =>
        track.id != 'auto' && track.id != 'no' &&
        _matchesAudioLanguage(track.language, app.preferredAudioLanguage));
      if (matching.isNotEmpty) {
        audioPreferenceApplied = true;
        player.setAudioTrack(matching.first).catchError((Object _) {});
      }
    }
    if (!subtitlePreferenceApplied && !app.subtitlesEnabled) {
      subtitlePreferenceApplied = true;
      player.setSubtitleTrack(SubtitleTrack.no()).catchError((Object _) {});
    }
  }

  static bool _matchesAudioLanguage(String? actual, String desired) {
    if (actual == null || actual.isEmpty) return false;
    final a = actual.toLowerCase();
    final aliases = switch (desired) {
      'en' => ['en', 'eng', 'english'],
      'hi' => ['hi', 'hin', 'hindi'],
      'bn' => ['bn', 'ben', 'bangla', 'bengali'],
      'ko' => ['ko', 'kor', 'korean'],
      'tr' => ['tr', 'tur', 'turkish'],
      _ => [desired],
    };
    return aliases.any((label) => a == label || a.startsWith('$label-'));
  }

  void _writeHistory() {
    if (accountsEnabled && app.api != null && app.loggedIn && !widget.movie.isLive) {
      app.api?.saveHistory(widget.movie.id, position, duration)
        .catchError((Object _) {});
    }
  }

  void _showControls() {
    hideTimer?.cancel();
    if (mounted) setState(() => controlsVisible = true);
    if (!androidTvBuild && playing && !locked) {
      hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => controlsVisible = false);
      });
    }
  }

  void _seekRelative(int seconds) {
    if (widget.movie.isLive && duration == Duration.zero) return;
    final target = (position.inMilliseconds + seconds * 1000)
        .clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 0).toInt();
    player.seek(Duration(milliseconds: target));
    _showControls();
  }

  Future<void> _toggleFullScreen() async {
    if (androidTvBuild) return;
    final next = !fullScreen;
    await SystemChrome.setPreferredOrientations(next
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(next
        ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() => fullScreen = next);
    _showControls();
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    _writeHistory();
    for (final sub in subscriptions) {
      sub.cancel();
    }
    surfaceFocus.dispose();
    player.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.mediaRewind) {
      _seekRelative(-app.seekSeconds);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.mediaFastForward) {
      _seekRelative(app.seekSeconds);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.mediaPlayPause) {
      player.playOrPause();
      _showControls();
      return KeyEventResult.handled;
    }
    // Let Up/Down travel to focusable playback buttons, slider and menus.
    // TV volume remains accessible through its volume slider.
    return KeyEventResult.ignored;
  }

  String _clock(Duration d) {
    final hours = d.inHours;
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  String _audioName(AudioTrack track) {
    if (track.id == 'auto') return 'Auto / Original';
    if (track.id == 'no') return 'Mute audio track';
    final title = track.title?.trim() ?? '';
    final lang = track.language?.trim() ?? '';
    return [if (title.isNotEmpty) title, if (lang.isNotEmpty) lang]
      .isEmpty ? 'Audio ${track.id}' :
      [if (title.isNotEmpty) title, if (lang.isNotEmpty) lang].join(' · ');
  }

  String _subtitleName(SubtitleTrack track) {
    if (track.id == 'auto') return 'Auto';
    if (track.id == 'no') return 'Off';
    final title = track.title?.trim() ?? '';
    final lang = track.language?.trim() ?? '';
    return [if (title.isNotEmpty) title, if (lang.isNotEmpty) lang]
      .isEmpty ? 'Subtitle ${track.id}' :
      [if (title.isNotEmpty) title, if (lang.isNotEmpty) lang].join(' · ');
  }

  Future<void> _selectAudio() async {
    hideTimer?.cancel();
    final tracks = player.state.tracks.audio;
    final candidates = tracks.where((t) => t.id != 'no').toList();
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Audio tracks', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Choose an available language / audio track')),
          for (final track in candidates)
            ListTile(
              leading: Icon(player.state.track.audio == track ? Icons.check_circle : Icons.audiotrack,
                color: player.state.track.audio == track ? AppColors.teal : null),
              title: Text(_audioName(track)),
              onTap: () async {
                Navigator.pop(sheetContext);
                audioPreferenceApplied = true;
                try { await player.setAudioTrack(track); }
                catch (e) { _showError('Audio track: $e'); }
              },
            ),
          if (candidates.length <= 2) const Padding(
            padding: EdgeInsets.all(18),
            child: Text('This stream does not expose multiple selectable audio languages. Dual audio requires an actual multi-track video.',
              style: TextStyle(color: AppColors.muted))),
        ]))));
    _showControls();
  }

  Future<void> _selectSubtitle() async {
    hideTimer?.cancel();
    final tracks = player.state.tracks.subtitle;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Subtitles / Captions',
            style: TextStyle(fontWeight: FontWeight.w800))),
          for (final track in tracks)
            ListTile(
              leading: Icon(player.state.track.subtitle == track ? Icons.check_circle : Icons.subtitles,
                color: player.state.track.subtitle == track ? AppColors.teal : null),
              title: Text(_subtitleName(track)),
              onTap: () async {
                Navigator.pop(sheetContext);
                subtitlePreferenceApplied = true;
                try { await player.setSubtitleTrack(track); }
                catch (e) { _showError('Subtitle track: $e'); }
              },
            ),
          for (final subtitle in widget.movie.subtitles)
            if (Uri.tryParse(subtitle.url)?.hasScheme ?? false)
              ListTile(
                leading: const Icon(Icons.closed_caption),
                title: Text(subtitle.label.isEmpty ? subtitle.language : subtitle.label),
                subtitle: const Text('External subtitles'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  subtitlePreferenceApplied = true;
                  try {
                    await player.setSubtitleTrack(SubtitleTrack.uri(subtitle.url,
                      title: subtitle.label, language: subtitle.language));
                  } catch (e) { _showError('External subtitle: $e'); }
                },
              ),
        ]))));
    _showControls();
  }

  Future<void> _selectVolume() async {
    hideTimer?.cancel();
    await showModalBottomSheet<void>(context: context,
      builder: (sheetContext) => SafeArea(child: StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Playback volume', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700)),
            Row(children: [
              const Icon(Icons.volume_down),
              Expanded(child: Slider(value: volume.clamp(0.0, 100.0).toDouble(),
                max: 100, onChanged: (v) {
                  setSheetState(() => volume = v);
                  player.setVolume(v);
                })),
              const Icon(Icons.volume_up),
            ]),
          ]),
        ),
      )),
    );
    _showControls();
  }

  void _showError(String message) {
    if (mounted) setState(() => playbackError = message);
  }

  Widget _control(IconData icon, String label, VoidCallback? onTap,
      {bool emphasized = false}) => IconButton(
    tooltip: label,
    onPressed: onTap,
    iconSize: emphasized ? 33 : 24,
    style: IconButton.styleFrom(
      backgroundColor: emphasized ? AppColors.teal : const Color(0xAA30303B),
      foregroundColor: emphasized ? Colors.black : Colors.white,
      shape: const CircleBorder(),
    ),
    icon: Icon(icon),
  );

  Widget _videoSurface() => LayoutBuilder(builder: (context, constraints) {
    final small = constraints.maxWidth < 500;
    final total = duration.inMilliseconds.toDouble();
    final sliderMax = total > 0 ? total : 1.0;
    final seek = (previewSeek ?? position).inMilliseconds.toDouble().clamp(0.0, sliderMax).toDouble();
    final audioTracks = player.state.tracks.audio
      .where((track) => track.id != 'auto' && track.id != 'no').length;
    return Focus(
      focusNode: surfaceFocus,
      onKeyEvent: _handleRemoteKey,
      child: GestureDetector(
        onTap: () => setState(() => controlsVisible = !controlsVisible),
        onDoubleTapDown: (details) => doubleTapPosition = details.localPosition,
        onDoubleTap: () {
          if (doubleTapPosition == null) return;
          _seekRelative(doubleTapPosition!.dx < constraints.maxWidth / 2
            ? -app.seekSeconds : app.seekSeconds);
        },
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: Colors.black, child: Video(
            controller: controller,
            fit: fillVideo ? BoxFit.cover : BoxFit.contain,
            controls: NoVideoControls,
          )),
          if (buffering) const Center(child: CircularProgressIndicator(color: AppColors.teal)),
          if (controlsVisible || !playing || androidTvBuild)
            Positioned.fill(child: IgnorePointer(ignoring: locked, child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x88000000), Colors.transparent, Color(0xCC000000)],
                stops: [0, .4, 1])),
              child: Column(children: [
                Padding(padding: EdgeInsets.fromLTRB(small ? 6 : 18, 3, 5, 0), child: Row(children: [
                  Expanded(child: Text(widget.episode?.title ?? widget.movie.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: small ? 12 : 18, fontWeight: FontWeight.w700))),
                  _control(Icons.audiotrack_rounded,
                    'Audio tracks ($audioTracks)', _selectAudio),
                  _control(Icons.subtitles_outlined, 'Subtitles', _selectSubtitle),
                  if (!androidTvBuild) _control(Icons.fullscreen, 'Toggle fullscreen', _toggleFullScreen),
                ])),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _control(Icons.fast_rewind_rounded, 'Skip backward ${app.seekSeconds}s',
                    () => _seekRelative(-app.seekSeconds)),
                  SizedBox(width: small ? 5 : 24),
                  _control(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    playing ? 'Pause' : 'Play', player.playOrPause, emphasized: true),
                  SizedBox(width: small ? 5 : 24),
                  _control(Icons.fast_forward_rounded, 'Skip forward ${app.seekSeconds}s',
                    () => _seekRelative(app.seekSeconds)),
                ]),
                const Spacer(),
                Row(children: [
                  Padding(padding: const EdgeInsets.only(left: 8), child: Text(
                    widget.movie.isLive && duration == Duration.zero ? 'LIVE' : _clock(previewSeek ?? position),
                    style: const TextStyle(fontSize: 11))),
                  Expanded(child: Slider(
                    value: seek, max: sliderMax,
                    activeColor: AppColors.teal,
                    onChanged: duration == Duration.zero ? null : (v) => setState(() =>
                      previewSeek = Duration(milliseconds: v.toInt())),
                    onChangeEnd: (v) {
                      player.seek(Duration(milliseconds: v.toInt()));
                      setState(() => previewSeek = null);
                      _showControls();
                    },
                  )),
                  Padding(padding: const EdgeInsets.only(right: 8),
                    child: Text(_clock(duration), style: const TextStyle(fontSize: 11))),
                ]),
                Padding(padding: const EdgeInsets.only(bottom: 5, left: 8, right: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (small) _control(Icons.volume_up_outlined, 'Volume', _selectVolume),
                    if (!small) ...[
                      const Icon(Icons.volume_up, size: 17),
                      SizedBox(width: 95, child: Slider(value: volume.clamp(0.0, 100.0).toDouble(), max: 100,
                        onChanged: player.setVolume)),
                    ],
                    PopupMenuButton<double>(
                      tooltip: 'Playback speed',
                      icon: Text('${rate}x', style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
                      onSelected: (v) { player.setRate(v); _showControls(); },
                      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        .map((v) => PopupMenuItem(value: v, child: Text('${v}x'))).toList(),
                    ),
                    _control(fillVideo ? Icons.fit_screen : Icons.crop_free,
                      'Fit / fill screen', () { setState(() => fillVideo = !fillVideo); _showControls(); }),
                    if (!small) _control(locked ? Icons.lock : Icons.lock_open,
                      'Lock controls', () { setState(() => locked = !locked); _showControls(); }),
                  ])),
              ]),
            ))),
          if (locked) Positioned(top: 8, left: 8, child: IconButton(
            tooltip: 'Unlock controls', icon: const Icon(Icons.lock_open),
            onPressed: () => setState(() => locked = false))),
          if (playbackError != null) ColoredBox(color: const Color(0xE9000000), child: Center(
            child: Padding(padding: const EdgeInsets.all(20), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 36, color: AppColors.red),
                const SizedBox(height: 8),
                const Text('Unable to play this source', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                Text(playbackError!, textAlign: TextAlign.center, maxLines: 5,
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                FilledButton(onPressed: _open, child: const Text('Retry')),
              ]))),
          ),
        ]),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final full = fullScreen;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: full ? null : AppBar(title: Text(widget.episode?.title ?? widget.movie.title,
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(child: Column(children: [
        if (full) Expanded(child: _videoSurface())
        else AspectRatio(aspectRatio: 16 / 9, child: _videoSurface()),
        if (!full) Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.movie.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(widget.movie.isLive ? 'LIVE TV' :
            (widget.episode?.title ?? '${widget.movie.releaseYear} · ${widget.movie.quality}'),
            style: const TextStyle(color: AppColors.teal)),
          const SizedBox(height: 14),
          Text(widget.movie.description),
          const SizedBox(height: 17),
          const Text('Double tap left / right to seek. Select Audio to switch embedded languages.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ])),
      ])),
    );
  }
}
