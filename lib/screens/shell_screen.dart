import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/catalog_sort.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'about_screen.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'detail_screen.dart';
import 'live_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Netflix-inspired navigation and content discovery. All titles and images
/// are from the active JSON server, never seeded or substituted.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with WindowListener {
  static const labels = [
    'Home', 'Movies', 'Series', 'Live TV', 'My List', 'Settings', 'About',
  ];
  static const icons = [
    Icons.home_rounded, Icons.movie_rounded, Icons.tv_rounded,
    Icons.live_tv_rounded, Icons.bookmark_outline_rounded,
    Icons.settings_outlined, Icons.info_outline_rounded,
  ];

  int tab = 0;
  CatalogSort sort = CatalogSort.newest;
  bool _exitDialogOpen = false;
  String search = '';
  String genre = 'All';
  int visibleLimit = 72;
  bool searchOpen = false;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
  }

  @override
  void onWindowClose() {
    _confirmExit();
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || !mounted) return;
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close MBox?'),
        content: const Text('Are you sure you want to exit MBox?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || leave != true) return;
    if (Platform.isWindows) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    searchController.dispose();
    super.dispose();
  }

  void changeTab(int next) {
    setState(() {
      tab = next;
      genre = 'All';
      visibleLimit = 72;
    });
  }

  Future<void> openDetail(MediaItem movie) async {
    await Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)));
  }

  Future<void> showLogin() async {
    await Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void openProfile() {
    Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = androidTvBuild || size.width >= 900;
    final compact = size.width < 430;
    final page = switch (tab) {
      3 => LiveScreen(onSelect: openDetail, onLogin: showLogin),
      4 => _SavedContent(onSelect: openDetail),
      5 => const SettingsScreen(),
      6 => const AboutScreen(),
      _ => _BrowseCatalog(
        tab: tab,
        sort: sort,
        onSort: (next) => setState(() {
          sort = next;
          visibleLimit = 72;
        }),
        search: search,
        genre: genre,
        visibleLimit: visibleLimit,
        onGenre: (next) => setState(() {
          genre = next;
          visibleLimit = 72;
        }),
        onMore: () => setState(() => visibleLimit += 72),
        onSelect: openDetail,
      ),
    };

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
      drawer: wide ? null : Drawer(
        backgroundColor: AppColors.card,
        child: SafeArea(child: ListView(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(19, 24, 12, 27),
            child: Text('MBOX', style: TextStyle(
              color: AppColors.red, fontSize: 30,
              fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          for (var i = 0; i < labels.length; i++)
            ListTile(
              selected: tab == i,
              selectedTileColor: AppColors.surface,
              leading: Icon(icons[i],
                color: tab == i ? AppColors.red : Colors.white70),
              title: Text(labels[i]),
              onTap: () {
                Navigator.pop(context);
                changeTab(i);
              },
            ),
        ])),
      ),
      appBar: AppBar(
        toolbarHeight: wide ? 78 : 62,
        titleSpacing: compact ? 0 : 16,
        title: searchOpen
          ? TextField(
              autofocus: true,
              controller: searchController,
              onChanged: (next) => setState(() {
                search = next;
                visibleLimit = 72;
                if (tab != 0 && tab != 1 && tab != 2) tab = 0;
              }),
              decoration: const InputDecoration(
                hintText: 'Search titles, genres...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            )
          : wide
            ? _DesktopNavigation(
                tab: tab, onTab: changeTab, labels: labels,
              )
            : const Align(alignment: Alignment.centerLeft,
                child: Text('MBOX', style: TextStyle(
                  fontSize: 25, letterSpacing: 1,
                  color: AppColors.red, fontWeight: FontWeight.w900))),
        actions: [
          IconButton(
            tooltip: 'Refresh content',
            onPressed: app.loading ? null : app.refresh,
            icon: app.loading
              ? const SizedBox(width: 19, height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: searchOpen ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              searchOpen = !searchOpen;
              if (!searchOpen) {
                search = '';
                searchController.clear();
              }
            }),
            icon: Icon(searchOpen ? Icons.close : Icons.search_rounded),
          ),
          if (app.servers.isNotEmpty) PopupMenuButton<int>(
            tooltip: 'Choose content server',
            onSelected: (value) {
              setState(() {
                genre = 'All';
                visibleLimit = 72;
              });
              app.setServer(value);
            },
            itemBuilder: (_) => List.generate(app.servers.length, (i) =>
              PopupMenuItem<int>(value: i, child: Row(children: [
                if (i == app.serverIndex)
                  const Icon(Icons.check_rounded, size: 19, color: AppColors.red),
                const SizedBox(width: 8),
                Text(app.servers[i].name),
              ]))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!compact) Text(app.currentServer,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
                else const Icon(Icons.dns_outlined, size: 20),
                const Icon(Icons.arrow_drop_down_rounded, size: 19),
              ]),
            ),
          ),
          if (app.isAdmin) IconButton(
            tooltip: 'Admin CMS',
            onPressed: () => Navigator.push<void>(context,
              MaterialPageRoute(builder: (_) => const AdminScreen())),
            icon: const Icon(Icons.admin_panel_settings_rounded),
          ),
          if (accountsEnabled) IconButton(
            tooltip: app.loggedIn ? 'Profile' : 'Sign in',
            onPressed: app.loggedIn ? openProfile : showLogin,
            icon: const CircleAvatar(radius: 16,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 19)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: page,
      bottomNavigationBar: wide ? null : NavigationBar(
        height: 66,
        selectedIndex: tab >= 5 ? 0 : tab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: changeTab,
        destinations: List.generate(5, (i) => NavigationDestination(
          icon: Icon(icons[i], size: 22),
          selectedIcon: Icon(icons[i], color: Colors.white, size: 23),
          label: labels[i], tooltip: labels[i],
        )),
      ),
    ));
  }
}

class _DesktopNavigation extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final List<String> labels;
  const _DesktopNavigation({
    required this.tab, required this.onTab, required this.labels,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    const Text('MBOX', style: TextStyle(
      color: AppColors.red, fontWeight: FontWeight.w900,
      fontSize: 27, letterSpacing: 1)),
    const SizedBox(width: 27),
    Flexible(child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: () => onTab(i),
              style: TextButton.styleFrom(
                foregroundColor: tab == i ? Colors.white : AppColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
                textStyle: TextStyle(fontSize: 13,
                  fontWeight: tab == i ? FontWeight.w800 : FontWeight.w500),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(labels[i]),
                const SizedBox(height: 3),
                Container(width: tab == i ? 22 : 0, height: 3,
                  color: AppColors.red),
              ]),
            ),
          ),
      ]),
    )),
  ]);
}

class _BrowseCatalog extends StatelessWidget {
  final CatalogSort sort;
  final ValueChanged<CatalogSort> onSort;
  final int tab;
  final String search;
  final String genre;
  final int visibleLimit;
  final VoidCallback onMore;
  final ValueChanged<String> onGenre;
  final ValueChanged<MediaItem> onSelect;

  const _BrowseCatalog({required this.tab, required this.sort,
    required this.onSort, required this.search,
    required this.genre, required this.visibleLimit,
    required this.onMore, required this.onGenre, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final catalog = app.videos;
    final base = sortCatalog(catalog.where((m) => tab == 0 ||
      (tab == 1 ? !m.isSeries : m.isSeries)), sort);
    final keyword = search.trim().toLowerCase();
    final selection = sortCatalog(base.where((m) =>
      (keyword.isEmpty || m.title.toLowerCase().contains(keyword) ||
        m.genres.any((g) => g.toLowerCase().contains(keyword))) &&
      (genre == 'All' || m.genres.any((g) =>
        g.toLowerCase() == genre.toLowerCase()))), sort);
    final filtered = keyword.isNotEmpty || genre != 'All' ||
        sort != CatalogSort.newest;
    final genres = ['All', ...{for (final m in base) ...m.genres}];
    final years = base.where((m) => m.releaseYear > 0)
        .map((m) => m.releaseYear).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final rated = List<MediaItem>.of(base)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final hasResults = selection.isNotEmpty;
    final featured = hasResults ? selection.firstWhere(
      (m) => m.isFeatured, orElse: () => selection.first) : null;
    final title = switch (tab) {
      1 => 'Movies',
      2 => 'TV Series',
      _ => 'Discover stories worth watching',
    };

    return RefreshIndicator(
      onRefresh: app.refresh,
      child: CustomScrollView(slivers: [
        if (app.loading && catalog.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (app.error != null && catalog.isEmpty)
          SliverFillRemaining(child: _NetworkError(
            error: app.error!, onRetry: app.refresh))
        else ...[
          if (app.loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(
              minHeight: 2, color: AppColors.red)),
          if (app.warnings.isNotEmpty)
            SliverToBoxAdapter(child: _SourceWarnings(
              server: app.currentServer, warnings: app.warnings)),
          if (featured != null && !filtered)
            SliverToBoxAdapter(child: _FeaturedHero(
              movie: featured, onSelect: onSelect)),
          SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 700 ? 35 : 17,
              20, 17, 8),
            child: Row(children: [
              Expanded(child: Text(title,
                style: TextStyle(fontSize:
                  MediaQuery.sizeOf(context).width >= 700 ? 26 : 21,
                  fontWeight: FontWeight.w900))),
              PopupMenuButton<CatalogSort>(
                tooltip: 'Sort movies and series',
                initialValue: sort,
                onSelected: onSort,
                icon: const Icon(Icons.sort_rounded),
                itemBuilder: (_) => CatalogSort.values
                  .map((value) => PopupMenuItem<CatalogSort>(
                    value: value, child: Text(value.label),
                  )).toList(),
              ),
              Text('${selection.length} titles',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          )),
          if (genres.length > 1)
            SliverToBoxAdapter(child: SizedBox(height: 49,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal:
                  MediaQuery.sizeOf(context).width >= 700 ? 35 : 17,
                  vertical: 4),
                itemCount: genres.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = genres[i] == genre;
                  return ChoiceChip(
                    label: Text(genres[i]),
                    selected: active,
                    showCheckmark: false,
                    onSelected: (_) => onGenre(genres[i]),
                    selectedColor: Colors.white,
                    backgroundColor: AppColors.card,
                    labelStyle: TextStyle(color: active ? Colors.black : Colors.white,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500),
                    side: const BorderSide(color: Colors.white24),
                  );
                },
              ),
            )),
          if (filtered)
            SliverToBoxAdapter(child: _ResultsGrid(
              items: selection, visibleLimit: visibleLimit,
              onMore: onMore, onSelect: onSelect))
          else ...[
            if (base.isEmpty)
              const SliverFillRemaining(child: Center(
                child: Text('No titles found on this server.',
                  style: TextStyle(color: AppColors.muted))))
            else if (tab == 1 || tab == 2)
              SliverList(delegate: SliverChildListDelegate([
                for (final year in years)
                  MediaRow(
                    title: '$year',
                    items: base.where((m) => m.releaseYear == year).toList(),
                    onTap: onSelect,
                  ),
                if (base.any((m) => m.releaseYear <= 0))
                  MediaRow(
                    title: 'Year not listed',
                    items: base.where((m) => m.releaseYear <= 0).toList(),
                    onTap: onSelect,
                  ),
                const SizedBox(height: 36),
              ]))
            else SliverList(delegate: SliverChildListDelegate([
              MediaRow(title: 'Explore picks', items: base.take(18).toList(),
                icon: Icons.local_fire_department_outlined, onTap: onSelect),
              if (tab == 0) ...[
                MediaRow(title: 'Movies for you',
                  items: base.where((m) => !m.isSeries).take(18).toList(),
                  icon: Icons.movie_outlined, onTap: onSelect),
                MediaRow(title: 'Series to binge',
                  items: base.where((m) => m.isSeries).take(18).toList(),
                  icon: Icons.tv_outlined, onTap: onSelect),
              ],
              MediaRow(title: 'Highly rated', items:
                rated.where((m) => m.rating > 0).take(18).toList(),
                icon: Icons.star_border_rounded, onTap: onSelect),
              for (final category in genres.skip(1).take(5))
                MediaRow(title: category,
                  items: base.where((m) => m.genres.contains(category)).take(18).toList(),
                  onTap: onSelect),
              const SizedBox(height: 36),
            ])),
          ],
        ],
      ]),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final List<MediaItem> items;
  final int visibleLimit;
  final VoidCallback onMore;
  final ValueChanged<MediaItem> onSelect;
  const _ResultsGrid({required this.items, required this.visibleLimit,
    required this.onMore, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(54),
        child: Center(child: Text('No matching titles found.',
          style: TextStyle(color: AppColors.muted))));
    }
    final count = items.length < visibleLimit ? items.length : visibleLimit;
    return Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final cols = (constraints.maxWidth / 162).floor().clamp(2, 8).toInt();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, childAspectRatio: .58,
            mainAxisSpacing: 16, crossAxisSpacing: 12),
          itemBuilder: (_, i) => MediaPoster(
            item: items[i], width: double.infinity,
            onTap: () => onSelect(items[i])),
        );
      }),
      if (items.length > count) Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: OutlinedButton(
          onPressed: onMore,
          child: Text('Show more (${items.length - count} remaining)'),
        ),
      ),
    ]));
  }
}

class _FeaturedHero extends StatelessWidget {
  final MediaItem movie;
  final ValueChanged<MediaItem> onSelect;
  const _FeaturedHero({required this.movie, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 750;
    return SizedBox(
      height: wide ? 510 : 424,
      child: Stack(fit: StackFit.expand, children: [
        ArtImage(url: movie.backdropUrl.isNotEmpty ?
          movie.backdropUrl : movie.posterUrl),
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xE7000000), Color(0x93000000), Colors.transparent],
            stops: [0, .44, 1],
          ),
        )),
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x33000000), Colors.transparent, AppColors.bg],
            stops: [0, .48, 1],
          ),
        )),
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 45 : 20, 0, 22, wide ? 50 : 30),
          child: Align(alignment: Alignment.bottomLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 585 : 350),
              child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 19, color: AppColors.red),
                  const SizedBox(width: 8),
                  const Text('FEATURED ON MBOX',
                    style: TextStyle(letterSpacing: 2, fontSize: 10,
                      fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 13),
                Text(movie.title,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 46 : 31,
                    height: 1.05, fontWeight: FontWeight.w900,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 17)],
                  )),
                const SizedBox(height: 12),
                Wrap(spacing: 13, runSpacing: 7, children: [
                  if (movie.releaseYear > 0) Text('${movie.releaseYear}'),
                  if (movie.rating > 0) Text('★ ${movie.rating.toStringAsFixed(1)}'),
                  if (movie.quality.isNotEmpty) Text(movie.quality),
                  Text(movie.isSeries ? 'Series' : 'Movie'),
                ]),
                if (movie.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(movie.description, maxLines: wide ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFDFDFDF),
                      fontSize: 13, height: 1.45)),
                ],
                const SizedBox(height: 20),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: () => onSelect(movie),
                    icon: const Icon(Icons.play_arrow_rounded, size: 25),
                    label: const Text('Play', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => onSelect(movie),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('More info'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xB4464646),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SourceWarnings extends StatelessWidget {
  final String server;
  final List<String> warnings;
  const _SourceWarnings({required this.server, required this.warnings});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    child: InkWell(
      onTap: () => showDialog<void>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$server — Source diagnostics'),
          content: SizedBox(width: 540,
            child: SingleChildScrollView(
              child: SelectableText(warnings.join('\n\n')))),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'))],
        )),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
            color: Colors.orangeAccent, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(
            '$server: ${warnings.length} sources unavailable. View details',
            style: const TextStyle(fontSize: 12, color: Colors.orangeAccent))),
        ])),
    ),
  );
}

class _NetworkError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _NetworkError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.muted),
        const SizedBox(height: 16),
        const Text('Unable to load titles',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 10),
        Text(error, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ])),
  );
}

class _SavedContent extends StatelessWidget {
  final ValueChanged<MediaItem> onSelect;
  const _SavedContent({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final saved = app.watchlist;
    if (saved.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_outline_rounded,
            size: 66, color: Colors.white30),
          SizedBox(height: 17),
          Text('Your list is empty', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 22)),
          SizedBox(height: 7),
          Text('Add movies and series to watch them later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted)),
        ],
      ));
    }
    return CustomScrollView(slivers: [
      const SliverToBoxAdapter(child: Padding(
        padding: EdgeInsets.fromLTRB(22, 30, 16, 22),
        child: Text('My List', style: TextStyle(
          fontSize: 27, fontWeight: FontWeight.w900)))),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverLayoutBuilder(builder: (context, constraints) {
          final cols = (constraints.crossAxisExtent / 162).floor().clamp(2, 8).toInt();
          return SliverGrid.builder(
            itemCount: saved.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, childAspectRatio: .58,
              crossAxisSpacing: 12, mainAxisSpacing: 15),
            itemBuilder: (_, i) => MediaPoster(
              item: saved[i], width: double.infinity,
              onTap: () => onSelect(saved[i])),
          );
        }),
      ),
    ]);
  }
}
