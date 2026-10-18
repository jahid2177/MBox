import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'admin_screen.dart';
import 'history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _newProfile(BuildContext context) async {
    final input = TextEditingController();
    bool kids = false;
    await showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Add profile'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: input, decoration: const InputDecoration(labelText: 'Profile name')),
        SwitchListTile(value: kids, title: const Text('Kids profile'),
          onChanged: (v) => setLocal(() => kids = v)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (input.text.trim().isEmpty) return;
          try {
            await AppScope.of(context).addProfile(input.text.trim(), isKids: kids);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (e) { if (context.mounted) showErrorSnack(context, e); }
        }, child: const Text('Create'))],
    )));
    input.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;
    if (user == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not signed in')));
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Profiles')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Center(child: CircleAvatar(radius: 36, backgroundColor: AppColors.card,
            child: Icon(Icons.person_rounded, size: 42, color: AppColors.teal))),
          const SizedBox(height: 13),
          Text(user.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(user.email, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          Center(child: Chip(label: Text(user.isPremium ? 'Premium Member' : 'Free Account'),
            avatar: const Icon(Icons.workspace_premium, color: AppColors.teal, size: 17))),
          const SizedBox(height: 19),
          const Text('Your profiles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          for (final profile in user.profiles) ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.card, child: Icon(profile.isKids ? Icons.child_care : Icons.person,
              color: AppColors.teal)),
            title: Text(profile.name), subtitle: Text(profile.isKids ? 'Kids' : 'Standard'),
            trailing: profile.id == user.activeProfileId ? const Icon(Icons.check_circle, color: AppColors.teal) : null,
            onTap: () async { try { await app.switchProfile(profile.id); }
              catch (e) { if (context.mounted) showErrorSnack(context, e); } },
          ),
          if (user.profiles.length < 5) ListTile(leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add profile'), onTap: () => _newProfile(context)),
          const Divider(height: 26),
          ListTile(leading: const Icon(Icons.history, color: AppColors.teal),
            title: const Text('Watch History'), trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
          if (app.isAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings, color: AppColors.teal),
            title: const Text('Admin CMS'), trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
          ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Sign out'),
            onTap: () async { await app.logout(); if (context.mounted) Navigator.pop(context); }),
        ]),
      )),
    );
  }
}
