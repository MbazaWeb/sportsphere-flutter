import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/nbc_club_badges.dart';
import '../domain/models/match_model.dart';

MatchModel matchFromRow(Map<String, dynamic> row) {
  final kick = DateTime.tryParse(row['kickoffAt']?.toString() ?? '') ?? DateTime.now();
  final hs = row['homeScore'];
  final ascore = row['awayScore'];
  final status = (row['status'] as String?) ?? 'scheduled';
  final home = row['homeTeam'] as String? ?? '';
  final away = row['awayTeam'] as String? ?? '';
  final score = (hs == null && ascore == null)
      ? '-'
      : '${hs ?? 0} - ${ascore ?? 0}';
  final now = DateTime.now();
  final live = status.toLowerCase() == 'live' ||
      (!now.isBefore(kick) &&
          now.isBefore(kick.add(const Duration(minutes: 110))) &&
          status != 'FT' &&
          status != 'postponed');
  return MatchModel(
    id: row['id'] as String,
    homeTeamName: home,
    awayTeamName: away,
    homeTeamLogo: (row['homeBadge'] as String?) ?? NbcClubBadges.forName(home) ?? '',
    awayTeamLogo: (row['awayBadge'] as String?) ?? NbcClubBadges.forName(away) ?? '',
    leagueName: row['league'] as String? ?? 'Ligi Kuu Bara',
    leagueLogo: NbcClubBadges.forName(row['league'] as String? ?? '') ??
        NbcClubBadges.ligiKuuBara,
    score: status == 'scheduled' ? '-' : score,
    status: status,
    startTime: kick.toLocal(),
    isLive: live,
  );
}

Future<List<MatchModel>> fetchLiveMatches() async {
  final rows = await Supabase.instance.client
      .from('Match')
      .select()
      .order('kickoffAt')
      .limit(400);
  return [for (final r in rows as List) matchFromRow(Map<String, dynamic>.from(r))];
}

List<MatchModel> filterLive(List<MatchModel> all) =>
    all.where((m) => m.isLive).toList();

List<MatchModel> filterDay(List<MatchModel> all, DateTime day) => all
    .where((m) =>
        m.startTime.year == day.year &&
        m.startTime.month == day.month &&
        m.startTime.day == day.day)
    .toList();

List<MatchModel> filterUpcoming(List<MatchModel> all, DateTime? day) {
  final now = DateTime.now();
  final list = all.where((m) => m.startTime.isAfter(now) && m.status != 'FT').toList();
  if (day == null) return list;
  return filterDay(list, day);
}

List<MatchModel> filterResults(List<MatchModel> all, DateTime? day) {
  final list = all.where((m) => m.status == 'FT' || m.status == 'postponed').toList();
  if (day == null) return list;
  return filterDay(list, day);
}
