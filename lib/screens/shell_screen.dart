import 'package:flutter/material.dart';
import '../main.dart';
import '../models/media_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/media_widgets.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'detail_screen.dart';
import 'live_screen.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int tab = 0;
  String search = '';
  String genre = 'All';
  bool searchOpen = false;
  final searchController = TextEditingController();

  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  Future<void> openDetail(MediaItem movie) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(movie: movie)));
  }

  Future<void> showLogin() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final labels = ['Home', 'Movies', 'Series', 'Live TV', 'My List'];
    final icons = [Icons.home_rounded, Icons.movie_creation_outlined, Icons.tv_outlined, Icons.live_tv_outlined, Icons.bookmark_outline];
    final page = switch (tab) {
      3 => LiveScreen(onSelect: openDetail, onLogin: showLogin),
      4 => _SavedContent(onSelect: openDetail, onLogin: showLogin),
      _ => _CatalogContent(tab: tab, search: search, genre: genre,
          onGenre: (value) => setState(() => genre = value), onSelect: openDetail),
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: wide ? 76 : 61,
        titleSpacing: 16,
        title: searchOpen ? TextField(
          autofocus: true, controller: searchController,
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(hintText: 'Search movies and TV shows', prefixIcon: Icon(Icons.search), isDense: true),
        ) : Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.teal, size: 29),
          const SizedBox(width: 5),
          Text('MyStream', style: TextStyle(fontWeight: FontWeight.w900, fontSize: wide ? 24 : 19)),
          Text('Flix', style: TextStyle(fontWeight: FontWeight.w900, fontSize: wide ? 24 : 19, color: AppColors.teal)),
        ]),
        actions: [
          IconButton(tooltip: searchOpen ? 'Close search' : 'Search',
            onPressed: () => setState(() { searchOpen = !searchOpen; if (!searchOpen) { search = ''; searchController.clear(); } }),
            icon: Icon(searchOpen ? Icons.close : Icons.search_rounded)),
          if (app.isAdmin) IconButton(tooltip: 'Admin CMS', onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminScreen())), icon: const Icon(Icons.admin_panel_settings, color: AppColors.teal)),
          Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(
            onPressed: app.loggedIn ? openProfile : showLogin,
            tooltip: app.loggedIn ? 'Profile' : 'Sign in',
            icon: CircleAvatar(radius: 16, backgroundColor: AppColors.surface,
                child: Icon(app.loggedIn ? Icons.person : Icons.person_outline, color: Colors.white, size: 19)),
          )),
        ],
      ),
      body: Row(children: [
        if (wide) NavigationRail(
          selectedIndex: tab, onDestinationSelected: (v) => setState(() { tab = v; genre = 'All'; }),
          labelType: NavigationRailLabelType.all,
          backgroundColor: AppColors.bg, indicatorColor: AppColors.teal.withValues(alpha: .16),
          destinations: List.generate(5, (i) => NavigationRailDestination(icon: Icon(icons[i]),
              selectedIcon: Icon(icons[i], color: AppColors.teal), label: Text(labels[i]))),
        ),
        Expanded(child: page),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        backgroundColor: const Color(0xFF101017),
        height: 69, labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.teal.withValues(alpha: .19),
        selectedIndex: tab, onDestinationSelected: (v) => setState(() { tab = v; genre = 'All'; }),
        destinations: List.generate(5, (i) => NavigationDestination(
            icon: Icon(icons[i], size: 22), selectedIcon: Icon(icons[i], color: AppColors.teal),
            label: labels[i], tooltip: labels[i])),
      ),
    );
  }
}

class _CatalogContent extends StatelessWidget {
  final int tab;
  final String search;
  final String genre;
  final ValueChanged<String> onGenre;
  final ValueChanged<MediaItem> onSelect;
  const _CatalogContent({required this.tab, required this.search, required this.genre,
    required this.onGenre, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final catalog = app.videos;
    final selection = catalog.where((m) =>
      (tab == 0 || (tab == 1 ? !m.isSeries : m.isSeries)) &&
      (search.isEmpty || m.title.toLowerCase().contains(search.toLowerCase()) ||
          m.genres.any((g) => g.toLowerCase().contains(search.toLowerCase()))) &&
      (genre == 'All' || m.genres.any((g) => g.toLowerCase() == genre.toLowerCase()))
    ).toList();
    final hasFilter = tab != 0 || genre != 'All' || search.trim().isNotEmpty;
    final topRated = List<MediaItem>.from(catalog)..sort((a, b) => b.rating.compareTo(a.rating));
    return RefreshIndicator(
      color: AppColors.teal, onRefresh: app.refresh,
      child: CustomScrollView(slivers: [
        if (app.loading && catalog.isEmpty) const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
        else if (app.error != null && catalog.isEmpty) SliverFillRemaining(
          child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [const Icon(Icons.wifi_off, size: 54, color: AppColors.muted), const SizedBox(height: 16),
              Text(app.error!, textAlign: TextAlign.center), const SizedBox(height: 12),
              FilledButton(onPressed: app.refresh, child: const Text('Retry'))]))))
        else ...[
          if (!hasFilter && catalog.isNotEmpty) SliverToBoxAdapter(
            child: _HeroBanner(movie: catalog.firstWhere((m) => m.isFeatured, orElse: () => catalog.first), onTap: onSelect)),
          SliverToBoxAdapter(child: SizedBox(height: 58, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            itemCount: const ['All', 'Action', 'Adventure', 'Comedy', 'Drama', 'Sci-Fi', 'Horror',
              'Animation', 'Romance', 'Thriller', 'Documentary'].length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              const genres = ['All', 'Action', 'Adventure', 'Comedy', 'Drama', 'Sci-Fi', 'Horror',
                'Animation', 'Romance', 'Thriller', 'Documentary'];
              final active = genre == genres[i];
              return ChoiceChip(label: Text(genres[i]), selected: active,
                showCheckmark: false, onSelected: (_) => onGenre(genres[i]),
                selectedColor: AppColors.teal,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.black : Colors.white),
                backgroundColor: AppColors.card, side: BorderSide.none);
            },
          ))),
          if (hasFilter) SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate([
            Text('Explore  ·  ${selection.length} titles', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            if (selection.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(50),
              child: Text('No matching titles found', style: TextStyle(color: AppColors.muted))))
            else LayoutBuilder(builder: (context, constraints) {
              final cols = (constraints.maxWidth / 155).floor().clamp(2, 7).toInt();
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                itemCount: selection.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols,
                  childAspectRatio: .55, mainAxisSpacing: 15, crossAxisSpacing: 12),
                itemBuilder: (_, i) => MediaPoster(item: selection[i], onTap: () => onSelect(selection[i]),
                  width: double.infinity));
            }),
          ])))
          else SliverList(delegate: SliverChildListDelegate([
            MediaRow(title: 'Trending Now', items: catalog.take(12).toList(), icon: Icons.local_fire_department, onTap: onSelect),
            MediaRow(title: 'Popular Movies', items: catalog.where((m) => !m.isSeries).take(18).toList(), icon: Icons.local_movies, onTap: onSelect),
            MediaRow(title: 'Binge-worthy Series', items: catalog.where((m) => m.isSeries).take(18).toList(), icon: Icons.tv, onTap: onSelect),
            MediaRow(title: 'Top Rated', items: topRated.take(18).toList(), icon: Icons.star, onTap: onSelect),
            const SizedBox(height: 24),
          ])),
        ],
      ]),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final MediaItem movie;
  final ValueChanged<MediaItem> onTap;
  const _HeroBanner({required this.movie, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 800;
    return SizedBox(height: wide ? 430 : 288, child: Stack(fit: StackFit.expand, children: [
      ArtImage(url: movie.backdropUrl.isEmpty ? movie.posterUrl : movie.backdropUrl),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x4F09090D), Color(0xFF09090D)], stops: [0.2, .52, 1],
      ))),
      Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 19), child: Column(
        mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FEATURED PREMIERE', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 11)),
          const SizedBox(height: 8),
          Text(movie.title, maxLines: 2, style: TextStyle(fontSize: wide ? 38 : 26, fontWeight: FontWeight.w900, shadows: const [Shadow(blurRadius: 10, color: Colors.black)])),
          const SizedBox(height: 9),
          Text('${movie.releaseYear}   ★ ${movie.rating.toStringAsFixed(1)}   ${movie.quality}',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(children: [FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.black),
            onPressed: () => onTap(movie), icon: const Icon(Icons.play_arrow), label: const Text('Watch Now')),
            const SizedBox(width: 10), OutlinedButton.icon(onPressed: () => onTap(movie),
              icon: const Icon(Icons.info_outline), label: const Text('More Info'))]),
        ],
      )),
    ]));
  }
}

class _SavedContent extends StatelessWidget {
  final ValueChanged<MediaItem> onSelect;
  final VoidCallback onLogin;
  const _SavedContent({required this.onSelect, required this.onLogin});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.loggedIn && !demoMode) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
      children: [const Icon(Icons.bookmark_border, size: 55, color: AppColors.teal),
        const SizedBox(height: 12), const Text('Sign in to manage My List'),
        const SizedBox(height: 15), FilledButton(onPressed: onLogin, child: const Text('Sign In'))]));
    if (app.watchlist.isEmpty) return const Center(child: Text('No saved movies yet.\nTap the + button on a movie.',
      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)));
    return CustomScrollView(slivers: [
      const SliverPadding(padding: EdgeInsets.all(20), sliver: SliverToBoxAdapter(child:
        Text('My List', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 18), sliver: SliverLayoutBuilder(builder: (context, constraints) {
        final cols = (constraints.crossAxisExtent / 160).floor().clamp(2, 7).toInt();
        return SliverGrid.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, childAspectRatio: .55, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: app.watchlist.length,
          itemBuilder: (_, i) => MediaPoster(item: app.watchlist[i], onTap: () => onSelect(app.watchlist[i]), width: double.infinity));
      })),
    ]);
  }
}
