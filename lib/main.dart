import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_state.dart';
import 'models/models.dart';
import 'ui/home_page.dart';
import 'ui/library_page.dart';
import 'ui/player_page.dart';
import 'ui/search_page.dart';
import 'ui/sources_page.dart';
import 'ui/widgets/cover_image.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppState app = AppState();
  await app.init();
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: const LxMusicApp(),
    ),
  );
}

class LxMusicApp extends StatelessWidget {
  const LxMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '椰子音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    return Scaffold(
      body: HostOverlay(
        child: IndexedStack(
          index: _index,
          children: const <Widget>[
            HomePage(),
            SearchPage(),
            LibraryPage(),
            SourcesPage(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (app.player.current != null) const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (int i) => setState(() => _index = i),
            destinations: const <NavigationDestination>[
              NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
              NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: '收藏'),
              NavigationDestination(icon: Icon(Icons.extension), label: '音源'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 把隐藏的 WebView（LX 音源宿主）挂在界面最底层
class HostOverlay extends StatelessWidget {
  const HostOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final WebViewController controller = app.host.ensureController();
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          left: 0,
          top: 0,
          width: 2,
          height: 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ),
      ],
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final Song? song = app.player.current;
    if (song == null) return const SizedBox.shrink();

    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlayerPage()),
          );
        },
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 12),
              CoverImage(url: song.cover, size: 40, radius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    Text(
                      '${song.singer} · ${app.quality}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (app.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                icon: Icon(app.player.playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => app.player.toggle(),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
