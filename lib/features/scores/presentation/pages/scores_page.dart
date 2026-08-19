import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../widgets/match_card.dart';
import '../../domain/models/match_model.dart';

class ScoresPage extends StatefulWidget {
  const ScoresPage({super.key});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> with TickerProviderStateMixin {
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
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

class _MatchesView extends StatelessWidget {
  final TabController tabController;

  const _MatchesView({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tabController,
          isScrollable: true,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
              _MatchList(type: 'Live'),
              _MatchList(type: 'Today'),
              _MatchList(type: 'Upcoming'),
              _MatchList(type: 'Results'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchList extends StatelessWidget {
  final String type;

  const _MatchList({required this.type});

  @override
  Widget build(BuildContext context) {
    final matches = [
      MatchModel(
        id: '1',
        homeTeamName: 'Man City',
        awayTeamName: 'Arsenal',
        homeTeamLogo: '',
        awayTeamLogo: '',
        leagueName: 'Premier League',
        leagueLogo: '',
        score: '2 - 1',
        status: '85\'',
        startTime: DateTime.now(),
        isLive: true,
      ),
      MatchModel(
        id: '2',
        homeTeamName: 'Real Madrid',
        awayTeamName: 'Barcelona',
        homeTeamLogo: '',
        awayTeamLogo: '',
        leagueName: 'La Liga',
        leagueLogo: '',
        score: '0 - 0',
        status: '21:00',
        startTime: DateTime.now().add(const Duration(hours: 5)),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return MatchCard(
          match: matches[index],
          onCardTap: () {
            // TODO: Open match stats, lineups, formation
          },
          onTeamTap: () {
            // TODO: Open team profile
          },
        );
      },
    );
  }
}

class _StandingsView extends StatefulWidget {
  const _StandingsView();

  @override
  State<_StandingsView> createState() => _StandingsViewState();
}

class _StandingsViewState extends State<_StandingsView> {
  String selectedSport = 'Football';
  String selectedLeague = 'Premier League';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DropdownSelector(
                  label: 'Sport',
                  value: selectedSport,
                  items: const ['Football', 'Basketball', 'Tennis'],
                  onChanged: (v) => setState(() => selectedSport = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DropdownSelector(
                  label: 'League',
                  value: selectedLeague,
                  items: const ['Premier League', 'La Liga', 'Champions League'],
                  onChanged: (v) => setState(() => selectedLeague = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 30, child: Text('#', style: TextStyle(color: SportSphereColors.muted))),
                      Expanded(child: Text('Team', style: TextStyle(color: SportSphereColors.muted))),
                      SizedBox(width: 30, child: Text('PL', style: TextStyle(color: SportSphereColors.muted))),
                      SizedBox(width: 30, child: Text('GD', style: TextStyle(color: SportSphereColors.muted))),
                      SizedBox(width: 30, child: Text('PTS', style: TextStyle(color: SportSphereColors.muted))),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  // Mock Standings
                  ...List.generate(10, (index) => _StandingRow(index: index + 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownSelector({
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
        Text(label, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
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
              style: const TextStyle(color: Colors.white),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int index;
  const _StandingRow({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$index', style: const TextStyle(color: Colors.white))),
          Expanded(child: Text(index == 1 ? 'Man City' : 'Team $index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 30, child: Text('20', style: TextStyle(color: Colors.white))),
          const SizedBox(width: 30, child: Text('32', style: TextStyle(color: Colors.white))),
          const SizedBox(width: 30, child: Text('50', style: TextStyle(color: SportSphereColors.sportGreen, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
