part of '../app_shell.dart';

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _tab = 0;

  final tabs = const ['Spotlights', 'Trending', 'Community', 'E-Shop'];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _Header()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: GlassContainer(
              height: 52,
              radius: 26,
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final active = _tab == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tab = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: active
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF082C4A),
                                    Color(0xFF06304F),
                                  ],
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              color: active
                                  ? SportSphereColors.white
                                  : SportSphereColors.muted,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(child: _Stories()),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _PostCard(
                username: 'SportSphere',
                handle: '@sportsphere',
                time: '2h',
                title: 'What. A. Game!',
                description:
                    'The latest football action, stories and moments from around the world.',
                imageAsset: null,
                likes: '2.4K',
                comments: '184',
                reposts: '268',
                featured: true,
              ),
              const SizedBox(height: 14),
              _PostCard(
                username: 'Man City',
                handle: '@mancity',
                time: '3h',
                title: 'Three points away from home.',
                description:
                    'Follow the latest updates from the football community.',
                imageAsset: null,
                likes: '1.8K',
                comments: '132',
                reposts: '99',
              ),
              const SizedBox(height: 14),
              _PostCard(
                username: 'SportSphere Community',
                handle: '@community',
                time: '5h',
                title: 'Who wins tonight?',
                description: 'Join the conversation and share your prediction.',
                imageAsset: null,
                likes: '924',
                comments: '87',
                reposts: '51',
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
