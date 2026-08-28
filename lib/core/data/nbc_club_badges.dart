import '../../app/config/env.dart';

/// Club, league and national badges stored on VPS media storage.
class NbcClubBadges {
  NbcClubBadges._();

  // ─── STORAGE CONFIGURATION ────────────────────────────────
  static String get _base {
    // Use VPS API base URL for media storage (MinIO/CDN)
    return '${AppEnv.apiBaseUrl}/media';
  }

  // ─── TEAMS ──────────────────────────────────────────────────
  static String get simba => '$_base/teams/simba-sc.png';
  static String get yanga => '$_base/teams/young-africans.png';
  static String get azam => '$_base/teams/azam-fc.png';
  static String get singidaBlackStars => '$_base/teams/singida-black-stars.png';
  static String get mbeyaCity => '$_base/teams/mbeya-city.png';
  static String get geitaGold => '$_base/teams/geita-gold.png';
  static String get mashujaa => '$_base/teams/mashujaa-fc.png';
  static String get namungo => '$_base/teams/namungo-fc.png';
  static String get fountainGate => '$_base/teams/fountain-gate.png';
  static String get polisi => '$_base/teams/polisi-tanzania.png';
  static String get jkt => '$_base/teams/jkt-tanzania.png';
  static String get traUnited => '$_base/teams/tra-united.png';
  static String get pamba => '$_base/teams/pamba-jiji.png';
  static String get kageraSugar => '$_base/teams/kagera-sugar.png';
  static String get dodomaJiji => '$_base/teams/dodoma-jiji.png';
  static String get coastalUnion => '$_base/teams/coastal-union.png';
  static String get tanzaniaNational => '$_base/teams/tanzania-national.png';

  // ─── LEAGUES ─────────────────────────────────────────────────
  static String get nbcPremierLeague => '$_base/leagues/nbc-premier-league.png';
  static String get ligiKuuBara => nbcPremierLeague;
  /// Fallback when a club has no uploaded badge.
  static String get defaultTeam => '$_base/teams/default-team.png';
  static String get federationCup => '$_base/leagues/crdb-federation-cup.png';
  static String get pbzPremierLeague => '$_base/leagues/pbz-premier-league.png';

  // ─── LOOKUP MAP ─────────────────────────────────────────────
  static final Map<String, String> byKey = {
    // Teams
    'simba': simba,
    'simba sc': simba,
    'simba-sc': simba,
    'yanga': yanga,
    'young africans': yanga,
    'young africans sc': yanga,
    'azam': azam,
    'azam fc': azam,
    'singida black stars': singidaBlackStars,
    'singida': singidaBlackStars,
    'mbeya city': mbeyaCity,
    'geita gold': geitaGold,
    'mashujaa': mashujaa,
    'mashujaa fc': mashujaa,
    'namungo': namungo,
    'namungo fc': namungo,
    'fountain gate': fountainGate,
    'polisi tanzania': polisi,
    'polisi': polisi,
    'jkt tanzania': jkt,
    'jkt': jkt,
    'tra united': traUnited,
    'tra': traUnited,
    'pamba': pamba,
    'pamba jiji': pamba,
    'pamba jiji fc': pamba,
    'kagera sugar': kageraSugar,
    'kagera': kageraSugar,
    'dodoma jiji': dodomaJiji,
    'dodoma': dodomaJiji,
    'coastal union': coastalUnion,
    'coastal': coastalUnion,
    'tanzania': tanzaniaNational,
    'tanzania national team': tanzaniaNational,
    'taifa stars': tanzaniaNational,

    // Leagues
    'nbc premier league': nbcPremierLeague,
    'ligi kuu bara': ligiKuuBara,
    'tanzania premier league': nbcPremierLeague,
    'federation cup': federationCup,
    'crdb federation cup': federationCup,
    'pbz premier league': pbzPremierLeague,
    'zanzibar premier league': pbzPremierLeague,
  };

  // ─── LOOKUP METHOD ──────────────────────────────────────────
  static String forName(String name) {
    final key = name.trim().toLowerCase();

    // Exact match first
    if (byKey.containsKey(key)) return byKey[key]!;

    // Partial match
    String? bestMatch;
    int bestScore = 0;
    for (final entry in byKey.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        final score = entry.key.length;
        if (score > bestScore) {
          bestScore = score;
          bestMatch = entry.value;
        }
      }
    }
    return bestMatch ?? defaultTeam;
  }

  static Map<String, String> forNames(List<String> names) {
    return {for (final name in names) name: forName(name)};
  }
}