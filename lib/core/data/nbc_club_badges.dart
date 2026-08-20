/// Club, league and national badges stored on Supabase Storage.
const _base =
    'https://fffqjbrethogesgghjsn.supabase.co/storage/v1/object/public/media';

class NbcClubBadges {
  NbcClubBadges._();

  static const simba = '$_base/teams/simba-sc.png';
  static const yanga = '$_base/teams/young-africans.png';
  static const azam = '$_base/teams/azam-fc.png';
  static const singidaBlackStars = '$_base/teams/singida-black-stars.png';
  static const mbeyaCity = '$_base/teams/mbeya-city.png';
  static const geitaGold = '$_base/teams/geita-gold.png';
  static const mashujaa = '$_base/teams/mashujaa-fc.png';
  static const namungo = '$_base/teams/namungo-fc.png';
  static const fountainGate = '$_base/teams/fountain-gate.png';
  static const polisi = '$_base/teams/polisi-tanzania.png';
  static const jkt = '$_base/teams/jkt-tanzania.png';
  static const traUnited = '$_base/teams/tra-united.png';
  static const pamba = '$_base/teams/pamba-jiji.png';
  static const kageraSugar = '$_base/teams/kagera-sugar.png';
  static const dodomaJiji = '$_base/teams/dodoma-jiji.png';
  static const coastalUnion = '$_base/teams/coastal-union.png';
  static const tanzaniaNational = '$_base/teams/tanzania-national.png';

  static const nbcPremierLeague = '$_base/leagues/nbc-premier-league.png';
  static const ligiKuuBara = nbcPremierLeague;
  static const federationCup = '$_base/leagues/crdb-federation-cup.png';
  static const pbzPremierLeague = '$_base/leagues/pbz-premier-league.png';

  static const Map<String, String> byKey = {
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
    'nbc premier league': nbcPremierLeague,
    'ligi kuu bara': ligiKuuBara,
    'tanzania premier league': nbcPremierLeague,
    'federation cup': federationCup,
    'crdb federation cup': federationCup,
    'pbz premier league': pbzPremierLeague,
    'zanzibar premier league': pbzPremierLeague,
  };

  static String? forName(String name) {
    final key = name.trim().toLowerCase();
    if (byKey.containsKey(key)) return byKey[key];
    for (final entry in byKey.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }
}
