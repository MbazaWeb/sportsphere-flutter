import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/match_model.dart';
import '../providers/scores_provider.dart';
import '../widgets/match_card.dart';

class ScoresPage extends ConsumerStatefulWidget {
  const ScoresPage({super.key});

  @override
  ConsumerState<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends ConsumerState<ScoresPage>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _matchesTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _matchesTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _matchesTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: SportSphereColors.electricBlue,
          labelColor: SportSphereColors.electricBlue,
          unselectedLabelColor: SportSphereColors.muted,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Standings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: [
          _MatchesView(tabController: _matchesTabController),
          const _StandingsView(),
        ],
      ),
    );
  }
}

// ── Matches view ───────────────────────────────────────────────────────────────

class _MatchesView extends ConsumerWidget {
  final TabController tabController;
  const _MatchesView({required this.tabController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: SportSphereColors.electricBlue,
          unselectedLabelColor: SportSphereColors.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Results'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _MatchList(provider: liveMatchesProvider),
              _MatchList(provider: todayMatchesProvider),
              _MatchList(provider: upcomingMatchesProvider),
              _MatchList(provider: resultsProvider),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchList extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<MatchModel>>> provider;
  const _MatchList({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: SportSphereColors.electricBlue,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: SportSphereColors.muted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load matches',
              style: const TextStyle(color: SportSphereColors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(liveMatchesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (matches) => matches.isEmpty
          ? const _EmptyMatches()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => MatchCard(
                match: matches[i],
                onCardTap: () {},
                onTeamTap: () {},
              ),
            ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_score_rounded,
            color: SportSphereColors.muted.withValues(alpha: 0.5),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'No matches here',
            style: TextStyle(color: SportSphereColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Standings view ─────────────────────────────────────────────────────────────

class _StandingsView extends StatefulWidget {
  const _StandingsView();

  @override
  State<_StandingsView> createState() => _StandingsViewState();
}

class _StandingsViewState extends State<_StandingsView> {
  String _sport = 'Football';
  String _league = 'Premier League';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  label: 'Sport',
                  value: _sport,
                  items: const ['Football', 'Basketball', 'Tennis'],
                  onChanged: (v) => setState(() => _sport = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dropdown(
                  label: 'League',
                  value: _league,
                  items: const [
                    'Premier League',
                    'La Liga',
                    'Champions League',
                    'Tanzania PL',
                  ],
                  onChanged: (v) => setState(() => _league = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: const [
                      SizedBox(
                        width: 28,
                        child: Text('#',
                            style: TextStyle(
                                color: SportSphereColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text('Team',
                            style: TextStyle(
                                color: SportSphereColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text('PL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: SportSphereColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text('GD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: SportSphereColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text('PTS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: SportSphereColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _mockStandings.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 2),
                      itemBuilder: (_, i) =>
                          _StandingRow(data: _mockStandings[i], rank: i + 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _mockStandings = [
  ('Man City', 28, 34, 67),
  ('Arsenal', 28, 29, 64),
  ('Liverpool', 28, 31, 61),
  ('Aston Villa', 28, 18, 55),
  ('Tottenham', 28, 9, 50),
  ('Chelsea', 28, 11, 48),
  ('Man United', 28, -4, 38),
  ('Newcastle', 28, 7, 36),
  ('West Ham', 28, -6, 34),
  ('Brighton', 28, 5, 32),
];

class _StandingRow extends StatelessWidget {
  final (String, int, int, int) data;
  final int rank;
  const _StandingRow({required this.data, required this.rank});

  @override
  Widget build(BuildContext context) {
    final (name, played, gd, pts) = data;
    final isTop4 = rank <= 4;
    final isTop6 = rank <= 6;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isTop4
                ? SportSphereColors.electricBlue
                : isTop6
                    ? SportSphereColors.sportOrange.withValues(alpha: 0.5)
                    : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isTop4
                    ? SportSphereColors.electricBlue
                    : SportSphereColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$played',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SportSphereColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              gd >= 0 ? '+$gd' : '$gd',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gd > 0
                    ? SportSphereColors.sportGreen
                    : gd < 0
                        ? SportSphereColors.danger
                        : SportSphereColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$pts',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: SportSphereColors.muted, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SportSphereColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: SportSphereColors.surface2,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
