import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/admin/app_admin.dart';
import '../../../../core/taxonomy/sport_catalog.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../data/scores_repository.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/match_status.dart';
import '../../domain/models/standing_model.dart';
import '../admin_live_control.dart';
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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // The realtime channel is owned by [matchRealtimeTickProvider] in
    // scores_provider.dart — this page no longer subscribes on its own
    // (previously both this page and the provider opened duplicate
    // `public."Match"` channels).
    _mainTabController = TabController(length: 2, vsync: this);
    _matchesTabController = TabController(length: 4, vsync: this);
    AppAdmin.resolveIsAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => openAdminLiveControl(context, ref),
              backgroundColor: const Color(0xFFE31B23),
              icon: const Icon(Icons.sensors),
              label: const Text('Live control'),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/playify_icon.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            const Text(
              'Scores',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ],
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
              _LiveMatchList(provider: liveMatchesProvider),
              _TodayMatchList(provider: todayMatchesProvider),
              _DatedMatchList(
                provider: upcomingMatchesProvider,
                dateProvider: upcomingDateProvider,
                future: true,
                emptyTitle: 'No upcoming matches',
                emptyHint: 'Check back later — new fixtures appear here.',
              ),
              _DatedMatchList(
                provider: resultsProvider,
                dateProvider: resultsDateProvider,
                future: false,
                emptyTitle: 'No results for this date',
                emptyHint: 'Pick another date or check back once matches end.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Skeleton loader (no shimmer package; uses pulsing opacity) ──────────────

class _MatchListSkeleton extends StatefulWidget {
  const _MatchListSkeleton();

  @override
  State<_MatchListSkeleton> createState() => _MatchListSkeletonState();
}

class _MatchListSkeletonState extends State<_MatchListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: 0.4 + 0.4 * _ctrl.value,
          child: child,
        ),
        child: GlassContainer(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 12,
                decoration: BoxDecoration(
                  color: SportSphereColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _SkeletonAvatar(),
                  _SkeletonScore(),
                  _SkeletonAvatar(),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _SkeletonAction(),
                  _SkeletonAction(),
                  _SkeletonAction(),
                  _SkeletonAction(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonAvatar extends StatelessWidget {
  const _SkeletonAvatar();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SportSphereColors.surface2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 10,
            color: SportSphereColors.surface2,
          ),
        ],
      );
}

class _SkeletonScore extends StatelessWidget {
  const _SkeletonScore();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 50,
            height: 22,
            color: SportSphereColors.surface2,
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 10,
            color: SportSphereColors.surface2,
          ),
        ],
      );
}

class _SkeletonAction extends StatelessWidget {
  const _SkeletonAction();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: SportSphereColors.surface2,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 32,
            height: 10,
            color: SportSphereColors.surface2,
          ),
        ],
      );
}

// ── Live list (no date strip — by definition "in play now") ────────────────

class _LiveMatchList extends ConsumerWidget {
  final FutureProvider<List<MatchModel>> provider;
  const _LiveMatchList({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SportSphereColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live now',
                style: TextStyle(
                  color: SportSphereColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Updates in real time',
                style: TextStyle(
                  color: SportSphereColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _MatchListBody(provider: provider, emptyTitle: 'No live matches', emptyHint: 'Matches will appear here as soon as they kick off.')),
      ],
    );
  }
}

// ── Today list (shows today's date — no picker; today = today) ─────────────

class _TodayMatchList extends ConsumerWidget {
  final FutureProvider<List<MatchModel>> provider;
  const _TodayMatchList({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the day-rollover notifier so the list refreshes at local midnight.
    final today = ref.watch(todayDayProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.today_rounded,
                  color: SportSphereColors.electricBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                'Today · ${DateFormat('EEE, d MMM').format(today)}',
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _MatchListBody(
            provider: provider,
            emptyTitle: 'No matches today',
            emptyHint: 'Pick another date from the Upcoming or Results tabs.',
          ),
        ),
      ],
    );
  }
}

// ── Match list body (handles loading / error / data + refresh) ─────────────

class _MatchListBody extends ConsumerWidget {
  final FutureProvider<List<MatchModel>> provider;
  final String emptyTitle;
  final String emptyHint;
  const _MatchListBody({
    required this.provider,
    required this.emptyTitle,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const _MatchListSkeleton(),
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
              onPressed: () => ref.invalidate(provider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (matches) => matches.isEmpty
          ? _EmptyMatches(title: emptyTitle, hint: emptyHint)
          : RefreshIndicator(
              color: SportSphereColors.electricBlue,
              onRefresh: () async {
                ref.invalidate(provider);
                // Wait for the new future to settle so the indicator stays
                // visible until the refresh is done.
                await ref.read(provider.future);
              },
              child: ListView.separated(
                // Even when empty we want the RefreshIndicator to be
                // draggable — `alwaysScrollableScrollPhysics` ensures that.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => MatchCard(
                  match: matches[i],
                  // Match detail / team profile pages are not implemented in
                  // this feature yet — surface a clear message instead of
                  // being a silent no-op.
                  onCardTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Match details coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  ),
                  onTeamTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Team profiles coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  final String title;
  final String hint;
  const _EmptyMatches({required this.title, required this.hint});

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
          Text(
            title,
            style: const TextStyle(
              color: SportSphereColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SportSphereColors.muted,
                fontSize: 12,
              ),
            ),
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
  /// Default to football (most common sport in the dataset).
  String _sport = 'football';
  String _league = '';
  // Forward-compatible: the FutureBuilder is keyed by (_sport|_league|_season)
  // so when season filtering lands, just wiring this field to a UI control
  // will trigger re-queries automatically. Currently always '' (no season
  // filter in the schema yet).
  String _season = '';
  List<String> _leagues = const [];
  bool _loadingLeagues = true;

  /// Sports shown in the dropdown — sourced from [kAllSports] (no hardcoded
  /// list here). We pre-filter to the sports that typically have standings
  /// tables; the catalog itself is the single source of truth.
  List<String> get _sports => kAllSports;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _loadingLeagues = true);
    try {
      final names = await const ScoresRepository().listLeagues(sportSlug: _sport);
      if (!mounted) return;
      setState(() {
        _leagues = names;
        if (_leagues.isEmpty) {
          _league = '';
        } else if (!_leagues.contains(_league)) {
          _league = _leagues.first;
        }
        _loadingLeagues = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLeagues = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

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
                  items: _sports,
                  // Show pretty labels but keep the slug as the value.
                  labelOf: sportLabel,
                  onChanged: (v) {
                    if (v == null || v == _sport) return;
                    setState(() {
                      _sport = v;
                      _loadingLeagues = true;
                      _league = '';
                    });
                    _loadLeagues();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _leagues.isEmpty && !_loadingLeagues
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No leagues yet — create one in Admin',
                          style:
                              TextStyle(color: Color(0xFF8FA3B8), fontSize: 12),
                        ),
                      )
                    : _Dropdown(
                        label: 'League',
                        value: _leagues.contains(_league)
                            ? _league
                            : (_leagues.isNotEmpty ? _leagues.first : ''),
                        items: _loadingLeagues
                            ? (_league.isEmpty ? const ['Loading…'] : [_league])
                            : _leagues,
                        onChanged: (v) {
                          if (v == null || v == 'Loading…') return;
                          setState(() => _league = v);
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<StandingRow>>(
              future: const ScoresRepository()
                  .getStandings(league: _league, sportSlug: _sport),
              // Key by sport + league + season so the FutureBuilder properly
              // re-runs when any of them changes (previously keyed by league
              // only — switching sport didn't re-query).
              key: ValueKey('$_sport|$_league|$_season'),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _StandingsSkeleton();
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load standings',
                      style: const TextStyle(color: SportSphereColors.muted),
                    ),
                  );
                }
                final rows = snap.data ?? const <StandingRow>[];
                if (rows.isEmpty) {
                  return GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No finished matches yet for ${_league.isEmpty ? 'this league' : _league}.\nAdmin: update scores in Match Updates to fill the table.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: SportSphereColors.muted, height: 1.4),
                      ),
                    ),
                  );
                }
                final showDraws = sportHasDraws(_sport);
                return GlassContainer(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _StandingsHeader(showDraws: showDraws),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) => _StandingRow(
                            data: rows[i],
                            rank: i + 1,
                            showDraws: showDraws,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  final bool showDraws;
  const _StandingsHeader({required this.showDraws});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
            width: 28,
            child: Text('#',
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const Expanded(
            child: Text('Team',
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const SizedBox(
            width: 28,
            child: Text('P',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const SizedBox(
            width: 28,
            child: Text('W',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        if (showDraws)
          const SizedBox(
              width: 28,
              child: Text('D',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: SportSphereColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        const SizedBox(
            width: 28,
            child: Text('L',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const SizedBox(
            width: 36,
            child: Text('GD',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const SizedBox(
            width: 36,
            child: Text('Pts',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  final StandingRow data;
  final int rank;
  final bool showDraws;
  const _StandingRow({
    required this.data,
    required this.rank,
    required this.showDraws,
  });

  @override
  Widget build(BuildContext context) {
    final isTop4 = rank <= 4;
    final isTop6 = rank <= 6;
    final gd = data.goalDifference;
    final gdText = gd > 0 ? '+$gd' : '$gd';

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
              data.teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _cell('${data.played}'),
          _cell('${data.won}'),
          if (showDraws) _cell('${data.drawn}'),
          _cell('${data.lost}'),
          _cell(gdText),
          SizedBox(
            width: 36,
            child: Text(
              '${data.points}',
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

  Widget _cell(String v) => SizedBox(
        width: 28,
        child: Text(
          v,
          textAlign: TextAlign.center,
          style: const TextStyle(color: SportSphereColors.muted, fontSize: 12),
        ),
      );
}

// ── Standings skeleton ────────────────────────────────────────────────────────

class _StandingsSkeleton extends StatefulWidget {
  const _StandingsSkeleton();

  @override
  State<_StandingsSkeleton> createState() => _StandingsSkeletonState();
}

class _StandingsSkeletonState extends State<_StandingsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: 0.4 + 0.4 * _ctrl.value,
          child: child,
        ),
        child: Column(
          children: [
            for (var i = 0; i < 8; i++) ...[
              Row(
                children: [
                  Container(
                      width: 28,
                      height: 12,
                      color: SportSphereColors.surface2),
                  const SizedBox(width: 8),
                  Container(
                      width: 100,
                      height: 12,
                      color: SportSphereColors.surface2),
                  const Spacer(),
                  Container(
                      width: 28,
                      height: 12,
                      color: SportSphereColors.surface2),
                  const SizedBox(width: 6),
                  Container(
                      width: 28,
                      height: 12,
                      color: SportSphereColors.surface2),
                  const SizedBox(width: 6),
                  Container(
                      width: 28,
                      height: 12,
                      color: SportSphereColors.surface2),
                  const SizedBox(width: 6),
                  Container(
                      width: 36,
                      height: 12,
                      color: SportSphereColors.surface2),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String)? labelOf;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
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
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(labelOf != null ? labelOf!(e) : e),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dated match list (Upcoming / Results) ──────────────────────────────────

class _DatedMatchList extends ConsumerWidget {
  final FutureProvider<List<MatchModel>> provider;
  final NotifierProvider<Notifier<DateTime>, DateTime> dateProvider;
  final bool future;
  final String emptyTitle;
  final String emptyHint;
  const _DatedMatchList({
    required this.provider,
    required this.dateProvider,
    required this.future,
    required this.emptyTitle,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dateProvider);
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final days = future
        ? [for (var i = 1; i <= 10; i++) base.add(Duration(days: i))]
        : [for (var i = 10; i >= 1; i--) base.subtract(Duration(days: i))];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(DateFormat('EEE, d MMM').format(selected),
                    style: const TextStyle(
                        color: SportSphereColors.white,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: future
                        ? base.add(const Duration(days: 1))
                        : base.subtract(const Duration(days: 30)),
                    lastDate: future
                        ? base.add(const Duration(days: 30))
                        : base.subtract(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    ref.read(dateProvider.notifier).state =
                        DateTime(picked.year, picked.month, picked.day);
                  }
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('Pick date'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = d.year == selected.year &&
                  d.month == selected.month &&
                  d.day == selected.day;
              return GestureDetector(
                onTap: () =>
                    ref.read(dateProvider.notifier).state = d,
                child: Container(
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: on
                        ? SportSphereColors.electricBlue.withValues(alpha: 0.2)
                        : SportSphereColors.surface2,
                    border: Border.all(
                        color: on
                            ? SportSphereColors.electricBlue
                            : Colors.white24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('E').format(d),
                          style: TextStyle(
                              color: on
                                  ? SportSphereColors.electricBlue
                                  : SportSphereColors.muted,
                              fontSize: 11)),
                      Text('${d.day}',
                          style: TextStyle(
                              color: SportSphereColors.white,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _MatchListBody(
            provider: provider,
            emptyTitle: emptyTitle,
            emptyHint: emptyHint,
          ),
        ),
      ],
    );
  }
}
