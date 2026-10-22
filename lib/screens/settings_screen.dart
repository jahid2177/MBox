import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';

/// Preferences are stored only on this device, not in any remote JSON feed.
class SettingsScreen extends StatelessWidget {

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Streaming and playback preferences',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _section('CONTENT SERVER', Icons.dns_outlined),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Active content server'),
                subtitle: Text(app.currentServer),
                trailing: DropdownButton<int>(
                  value: app.servers.isEmpty ? null : app.serverIndex,
                  hint: const Text('Loading'),
                  items: List.generate(
                    app.servers.length,
                    (i) => DropdownMenuItem<int>(
                      value: i,
                      child: Text(app.servers[i].name),
                    ),
                  ),
                  onChanged: (index) {
                    if (index != null) {
                      app.setServer(index);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Refresh all content'),
                subtitle: const Text(
                  'Download the latest Movies, Series and Live TV JSON',
                ),
                trailing: app.loading
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onTap: app.loading ? null : app.refresh,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _section('VIDEO PLAYER', Icons.movie_filter_outlined),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Autoplay video'),
                subtitle: const Text('Start playback when opening a video'),
                secondary: const Icon(Icons.play_circle_outline),
                value: app.autoPlay,
                onChanged: app.updateAutoPlay,
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Fill screen'),
                subtitle: const Text(
                  'Crop edges to fill the display; off preserves full frame',
                ),
                secondary: const Icon(Icons.aspect_ratio),
                value: app.fillVideo,
                onChanged: app.updateVideoFill,
              ),
              const Divider(height: 1),
              _selection<double>(
                icon: Icons.speed,
                title: 'Default playback speed',
                current: app.playbackSpeed,
                choices: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
                label: (speed) => '${speed}x',
                onChanged: app.updatePlaybackSpeed,
              ),
              const Divider(height: 1),
              _selection<int>(
                icon: Icons.fast_forward,
                title: 'Skip forward / backward',
                current: app.seekSeconds,
                choices: const [10, 15, 30],
                label: (seconds) => '$seconds seconds',
                onChanged: app.updateSeekSeconds,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _section('AUDIO & SUBTITLES', Icons.subtitles_outlined),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Enable subtitles by default'),
                subtitle: const Text(
                  'When subtitle tracks are present in the stream',
                ),
                secondary: const Icon(Icons.closed_caption_outlined),
                value: app.subtitlesEnabled,
                onChanged: app.updateSubtitles,
              ),
              const Divider(height: 1),
              _selection<String>(
                icon: Icons.language,
                title: 'Preferred audio language',
                current: app.preferredAudioLanguage,
                choices: const ['auto', 'en', 'hi', 'bn', 'ko', 'tr'],
                label: audioLanguageLabel,
                onChanged: app.updateAudioLanguage,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 16),
                child: Text(
                  'Audio selection requires matching tracks in the media file. '
                  'It cannot create a second audio track.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Reset player settings?'),
                content: const Text(
                  'Playback preferences will reset. Your My List and '
                  'server URLs will remain unchanged.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );

            if (confirmed != true) {
              return;
            }

            await app.resetPlayerPreferences();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Player settings reset')),
              );
            }
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset player preferences'),
        ),
      ],
    );
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 9),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.teal),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );

  Widget _selection<T>({
    required IconData icon,
    required String title,
    required T current,
    required List<T> choices,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: DropdownButton<T>(
          value: current,
          underline: const SizedBox.shrink(),
          items: choices
              .map(
                (value) => DropdownMenuItem<T>(
                  value: value,
                  child: Text(label(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      );
}

String audioLanguageLabel(String language) => switch (language) {
      'en' => 'English',
      'hi' => 'Hindi',
      'bn' => 'Bangla',
      'ko' => 'Korean',
      'tr' => 'Turkish',
      _ => 'Auto (stream default)',
    };
