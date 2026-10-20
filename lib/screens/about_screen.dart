import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 35),
    children: [
      const Center(child: Icon(Icons.play_circle_fill_rounded, color: AppColors.teal, size: 84)),
      const SizedBox(height: 12),
      const Center(child: Text('MyStreamFlix',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
      const SizedBox(height: 6),
      const Center(child: Text('Movies • TV Series • Live Television',
        style: TextStyle(color: AppColors.muted))),
      const SizedBox(height: 30),
      const Card(child: Column(children: [
        ListTile(leading: Icon(Icons.person_outline, color: AppColors.teal),
          title: Text('Developer'), subtitle: Text('Md Jahidul Islam')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.info_outline),
          title: Text('App version'), subtitle: Text('1.0.0')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.devices_other_outlined),
          title: Text('Supported platforms'), subtitle: Text('Android • Android TV • Windows')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.cloud_download_outlined),
          title: Text('Content sources'),
          subtitle: Text('Server 1 / Server 2 — configured GitHub JSON feeds')),
      ])),
      const SizedBox(height: 18),
      const Center(child: Text('Video playback and audio tracks depend on the format and streams supplied by each content source.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted))),
    ],
  );
}
