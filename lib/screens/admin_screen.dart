import 'package:flutter/material.dart';
import '../main.dart';
import '../models/app_user.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int tab = 0;
  String query = '';
  List<AppUser> accounts = [];
  bool busy = false;
  bool requestedUsers = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requestedUsers && AppScope.of(context).isAdmin) {
      requestedUsers = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadUsers(); });
    }
  }

  Future<void> _loadUsers() async {
    final app = AppScope.of(context);
    if (!app.isAdmin) {
      return;
    }
    setState(() => busy = true);
    try { final data = await app.api!.users(); if (mounted) setState(() => accounts = data); }
    catch (e) { if (mounted) showErrorSnack(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _confirmDelete(MediaItem movie) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete content?'),
      content: Text('Remove "${movie.title}" permanently from the backend?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok != true || !mounted) {
      return;
    }
    final app = AppScope.of(context);
    try {
      await app.api!.deleteContent(movie.id);
      await app.refresh();
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e);
      }
    }
  }

  Future<void> _contentEditor({MediaItem? item}) async {
    final title = TextEditingController(text: item?.title ?? '');
    final url = TextEditingController(text: item?.videoUrl ?? '');
    final poster = TextEditingController(text: item?.posterUrl ?? '');
    final backdrop = TextEditingController(text: item?.backdropUrl ?? '');
    final description = TextEditingController(text: item?.description ?? '');
    final genres = TextEditingController(text: item?.genres.join(', ') ?? 'Action');
    final app = AppScope.of(context);
    String contentType = item?.contentType ?? (tab == 1 ? 'livetv' : 'movie');
    bool saving = false;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (ctx, update) {
        InputDecoration deco(String label) => InputDecoration(labelText: label);
        return AlertDialog(
          title: Text(item == null ? 'Add new content' : 'Edit content'),
          content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: deco('Title *')), const SizedBox(height: 10),
            TextField(controller: url, decoration: deco('Stream URL *')), const SizedBox(height: 10),
            TextField(controller: poster, decoration: deco('Poster URL')), const SizedBox(height: 10),
            TextField(controller: backdrop, decoration: deco('Backdrop URL')), const SizedBox(height: 10),
            TextField(controller: description, decoration: deco('Description'), maxLines: 3), const SizedBox(height: 10),
            TextField(controller: genres, decoration: deco('Genres (comma separated)')), const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: contentType, decoration: deco('Content Type'),
              items: ['movie', 'series', 'livetv'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
              onChanged: saving ? null : (v) => update(() => contentType = v ?? 'movie')),
          ]))),
          actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: saving ? null : () async {
              if (title.text.trim().isEmpty || url.text.trim().isEmpty) {
                showErrorSnack(ctx, 'Title and stream URL are required.'); return;
              }
              final parsed = Uri.tryParse(url.text.trim());
              if (parsed == null || !['http', 'https'].contains(parsed.scheme)) {
                showErrorSnack(ctx, 'Enter a valid http(s) stream URL.'); return;
              }
              update(() => saving = true);
              final data = <String, dynamic>{
                'title': title.text.trim(), 'videoUrl': url.text.trim(),
                'posterUrl': poster.text.trim(), 'backdropUrl': backdrop.text.trim(),
                'description': description.text.trim(), 'contentType': contentType,
                'genres': genres.text.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
                'releaseYear': item?.releaseYear == 0 ? DateTime.now().year : (item?.releaseYear ?? DateTime.now().year),
                'rating': item?.rating ?? 0, 'quality': item?.quality ?? 'HD',
              };
              try {
                final api = app.api!;
                if (item == null) { await api.addContent(data); }
                else { await api.updateContent(item.id, data); }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await app.refresh();
              } catch (e) {
                if (ctx.mounted) {
                  showErrorSnack(ctx, e);
                  update(() => saving = false);
                }
              }
            }, child: Text(saving ? 'Saving...' : 'Save'))],
        );
      }));
    } finally {
      title.dispose(); url.dispose(); poster.dispose(); backdrop.dispose(); description.dispose(); genres.dispose();
    }
  }

  Future<void> _changeRole(AppUser user) async {
    if (user.id == AppScope.of(context).user?.id) {
      showErrorSnack(context, 'You cannot change the active admin account role.'); return;
    }
    try {
      await AppScope.of(context).api!.setRole(user.id, user.isAdmin ? 'user' : 'admin');
      if (mounted) {
        await _loadUsers();
      }
    } catch (e) { if (mounted) showErrorSnack(context, e); }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.id == AppScope.of(context).user?.id) {
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete account?'), content: Text('Permanently delete ${user.email}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok != true || !mounted) {
      return;
    }
    try { await AppScope.of(context).api!.deleteUser(user.id); if (mounted) await _loadUsers(); }
    catch (e) { if (mounted) showErrorSnack(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.isAdmin) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Administrator access required.')));
    }
    final types = [app.videos, app.liveChannels];
    final filtered = tab == 2 ? <MediaItem>[] : types[tab].where((m) => m.title.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.admin_panel_settings, color: AppColors.teal), SizedBox(width: 9), Text('Master CMS')]),
        actions: [IconButton(tooltip: 'Refresh', onPressed: () async { await app.refresh(); await _loadUsers(); },
          icon: const Icon(Icons.refresh))]),
      floatingActionButton: tab == 2 ? null : FloatingActionButton.extended(
        onPressed: () => _contentEditor(), backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add, color: Colors.black), label: const Text('Add Content', style: TextStyle(color: Colors.black))),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child:
        Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            _stat('Titles', '${app.videos.length}', Icons.movie), const SizedBox(width: 9),
            _stat('Live TV', '${app.liveChannels.length}', Icons.live_tv), const SizedBox(width: 9),
            _stat('Users', '${accounts.length}', Icons.people),
          ])),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.movie_outlined), label: Text('Catalog')),
            ButtonSegment(value: 1, icon: Icon(Icons.sensors), label: Text('Live TV')),
            ButtonSegment(value: 2, icon: Icon(Icons.people), label: Text('Users')),
          ], selected: {tab}, onSelectionChanged: (s) => setState(() { tab = s.first; query = ''; }))),
          Padding(padding: const EdgeInsets.all(14), child: TextField(
            onChanged: (s) => setState(() => query = s),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
              hintText: tab == 2 ? 'Find account' : 'Find content'))),
          Expanded(child: tab == 2 ? (busy ? const Center(child: CircularProgressIndicator()) :
            ListView.builder(itemCount: accounts.where((u) =>
                u.name.toLowerCase().contains(query.toLowerCase()) || u.email.toLowerCase().contains(query.toLowerCase())).length,
              itemBuilder: (context, i) {
                final u = accounts.where((u) => u.name.toLowerCase().contains(query.toLowerCase()) ||
                    u.email.toLowerCase().contains(query.toLowerCase())).toList()[i];
                return ListTile(leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                  title: Text(u.name), subtitle: Text(u.email),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(u.role, style: const TextStyle(color: AppColors.teal)),
                    PopupMenuButton<String>(onSelected: (v) {
                      if (v == 'role') {
                        _changeRole(u);
                      }
                      if (v == 'delete') {
                        _deleteUser(u);
                      }
                    },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'role', child: Text('Toggle Admin / User')),
                        if (u.id != app.user?.id) const PopupMenuItem(value: 'delete', child: Text('Delete account'))]),
                  ]));
              })) :
            ListView.separated(itemCount: filtered.length, separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = filtered[i];
                return ListTile(leading: SizedBox(width: 54, height: 66, child: ClipRRect(
                  borderRadius: BorderRadius.circular(7), child: ArtImage(url: m.posterUrl))),
                  title: Text(m.title, maxLines: 1),
                  subtitle: Text('${m.contentType.toUpperCase()}  •  ${m.releaseYear}  •  ${m.quality}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Edit', onPressed: () => _contentEditor(item: m),
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(tooltip: 'Delete', onPressed: () => _confirmDelete(m),
                        icon: const Icon(Icons.delete_outline, color: AppColors.red)),
                  ]));
              })),
        ]),
      )),
    );
  }

  Widget _stat(String title, String count, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [Icon(icon, color: AppColors.teal), const SizedBox(height: 5),
      Text(count, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12))]),
  ));
}
