import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listUsers({String q = '', int limit = 50}) async {
    try {
      final query = _sb.from('profiles')
          .select('id, handle, first_name, last_name, role, is_verified, email, created_at, avatar_url');
      final rows = q.isEmpty
          ? await query.order('created_at', ascending: false).limit(limit)
          : await query.or('handle.ilike.%$q%,first_name.ilike.%$q%,last_name.ilike.%$q%,email.ilike.%$q%').limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { debugPrint('listUsers: $e'); return []; }
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _sb.from('profiles').update({'role': role}).eq('id', uid);
    try { await _sb.from('User').update({"role": role}).eq("id", uid); } catch (_) {}
  }

  Future<void> verifyUser(String uid, bool verified) async {
    await _sb.from('profiles').update({'is_verified': verified}).eq('id', uid);
    try { await _sb.from('User').update({"isVerified": verified}).eq("id", uid); } catch (_) {}
  }

  Future<void> deleteUser(String uid) async {
    try { await _sb.from('User').delete().eq('id', uid); } catch (_) {}
    try { await _sb.from('profiles').delete().eq('id', uid); } catch (_) {}
    try { await _sb.auth.admin.deleteUser(uid); } catch (_) {}
  }

  Future<void> createUser({required String email, required String password, required String role, required String handle, required String firstName, required String lastName}) async {
    final res = await _sb.auth.admin.createUser(AdminUserAttributes(
      email: email, password: password,
      userMetadata: {'first_name': firstName, 'last_name': lastName, 'handle': handle, 'role': role},
      emailConfirm: true,
    ));
    final uid = res.user?.id.toString() ?? '';
    if (uid.isEmpty) return;
    try {
      await _sb.from('profiles').upsert({
        'id': uid, 'handle': handle, 'role': role,
        'first_name': firstName, 'last_name': lastName, 'email': email,
      });
    } catch (e) { debugPrint('createUser profile: $e'); }
  }

  // ── Competitions (Leagues) ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCompetitions() async {
    try {
      final rows = await _sb.from('League').select().order('name').limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('listCompetitions: $e');
      try {
        final rows = await _sb.from('Competition').select().order('name').limit(100);
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (e2) {
        debugPrint('listCompetitions Competition: $e2');
        return [];
      }
    }
  }

  Future<String> createCompetition({required String name, required String country, String? season, String type = 'league'}) async {
    final slug = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final id = 'league-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _sb.from('League').insert({
        'id': id, 'name': name, 'slug': '${slug}_$id',
        'country': country, 'type': type,
        if (season != null) 'season': season,
        'source': 'admin', 'verified': true, 'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('createCompetition: $e');
      rethrow;
    }
    // Mirror into Competition table when present (taxonomy layer).
    try {
      await _sb.from('Competition').upsert({
        'id': id,
        'name': name,
        'slug': '${slug}_$id',
        'country': country,
        'season': season,
        'competition_type': type,
        'sport_slug': 'football',
      });
    } catch (e) {
      debugPrint('createCompetition Competition mirror: $e');
    }
    return id;
  }

  Future<void> deleteCompetition(String id) async {
    await _sb.from('League').delete().eq('id', id);
    try { await _sb.from('Competition').delete().eq('id', id); } catch (_) {}
  }

  /// #5.1 — Partial update for an existing Competition row. Mirrors the dual
  /// write used by [createCompetition]: League (camelCase) + Competition
  /// (snake_case). Only non-null fields are written.
  Future<void> updateCompetition({
    required String id,
    String? name,
    String? logoUrl,
    String? season,
    String? sportSlug,
  }) async {
    final leaguePatch = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (name != null) leaguePatch['name'] = name;
    if (logoUrl != null) leaguePatch['logoUrl'] = logoUrl;
    if (season != null) leaguePatch['season'] = season;

    final compPatch = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (name != null) compPatch['name'] = name;
    if (logoUrl != null) compPatch['logo_url'] = logoUrl;
    if (season != null) compPatch['season'] = season;
    if (sportSlug != null) compPatch['sport_slug'] = sportSlug;

    if (leaguePatch.length > 1) {
      try {
        await _sb.from('League').update(leaguePatch).eq('id', id);
      } catch (e) {
        debugPrint('updateCompetition League($id): $e');
        rethrow;
      }
    }
    if (compPatch.length > 1) {
      try {
        await _sb.from('Competition').update(compPatch).eq('id', id);
      } catch (e) {
        // Competition table is optional; log and continue.
        debugPrint('updateCompetition Competition($id): $e');
      }
    }
  }

  // ── Teams ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listTeams({String? leagueId}) async {
    try {
      final q = _sb.from('Team').select('id, name, slug, city, country, venue, leagueId, verified, logoUrl, primaryColor');
      final rows = leagueId != null
          ? await q.eq('leagueId', leagueId).order('name').limit(100)
          : await q.order('name').limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<String> createTeam({
    required String name,
    required String country,
    String? city,
    String? leagueId,
    String? venue,
    int? foundedYear,
    String? primaryColor,
    String? logoUrl,
  }) async {
    final slug = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final id = 'team-${DateTime.now().millisecondsSinceEpoch}';
    final base = <String, dynamic>{
      'id': id,
      'name': name,
      'slug': '${slug}_$id',
      'country': country,
      if (city != null) 'city': city,
      if (leagueId != null) 'leagueId': leagueId,
      if (venue != null) 'venue': venue,
      if (foundedYear != null) 'foundedYear': foundedYear,
      if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      'source': 'admin',
      'verified': true,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    // Try with primaryColor first; column may be missing if migration not applied
    try {
      await _sb.from('Team').insert({
        ...base,
        if (primaryColor != null && primaryColor.isNotEmpty)
          'primaryColor': primaryColor,
      });
    } catch (e) {
      await _sb.from('Team').insert(base);
    }
    return id;
  }

  Future<void> addTeamToCompetition(String teamId, String leagueId) async {
    await _sb.from('Team').update({'leagueId': leagueId, 'updatedAt': DateTime.now().toIso8601String()}).eq('id', teamId);
  }

  /// #5.1 — Partial update for an existing Team row. Only non-null fields are
  /// written. Mirrors the column naming used by [createTeam] (camelCase).
  Future<void> updateTeam({
    required String id,
    String? name,
    String? shortName,
    String? logoUrl,
    String? primaryColor,
    String? country,
    String? venue,
    String? leagueId,
  }) async {
    final patch = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (name != null) patch['name'] = name;
    if (shortName != null) patch['shortName'] = shortName;
    if (logoUrl != null) patch['logoUrl'] = logoUrl;
    if (country != null) patch['country'] = country;
    if (venue != null) patch['venue'] = venue;
    if (leagueId != null) patch['leagueId'] = leagueId;
    if (primaryColor != null && primaryColor.isNotEmpty) {
      patch['primaryColor'] = primaryColor;
    }
    if (patch.length <= 1) {
      debugPrint('updateTeam: no fields to update for $id');
      return;
    }
    try {
      await _sb.from('Team').update(patch).eq('id', id);
    } catch (e) {
      // Try without primaryColor (column may be missing if migration not applied)
      if (primaryColor != null && primaryColor.isNotEmpty) {
        patch.remove('primaryColor');
        try {
          await _sb.from('Team').update(patch).eq('id', id);
          return;
        } catch (_) {}
      }
      debugPrint('updateTeam($id): $e');
      rethrow;
    }
  }

  Future<void> deleteTeam(String id) async {
    await _sb.from('Team').delete().eq('id', id);
  }

  // ── Players ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPlayers({String? teamId}) async {
    try {
      final q = _sb.from('Player').select('id, name, position, nationality, teamId, shirtNumber, goals, assists');
      final rows = teamId != null
          ? await q.eq('teamId', teamId).order('shirtNumber').limit(100)
          : await q.order('name').limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<void> createPlayer({required String name, required String position, required String teamId, String? nationality, int? shirtNumber}) async {
    if (teamId.trim().isEmpty) {
      throw StateError('Player must belong to an existing club/team');
    }
    final slug = '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    final id = 'player-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Player').insert({
      'id': id, 'name': name, 'slug': slug, 'position': position,
      'teamId': teamId,
      if (nationality != null) 'nationality': nationality,
      if (shirtNumber != null) 'shirtNumber': shirtNumber,
      'goals': 0, 'assists': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deletePlayer(String id) async {
    await _sb.from('Player').delete().eq('id', id);
  }

  /// #5.1 — Partial update for an existing Player row. Only non-null fields
  /// are written. Mirrors the column naming used by [createPlayer]
  /// (camelCase: position, nationality, teamId, shirtNumber, photoUrl, dateOfBirth).
  Future<void> updatePlayer({
    required String id,
    String? name,
    String? position,
    String? nationality,
    DateTime? dateOfBirth,
    String? photoUrl,
    String? teamId,
    int? shirtNumber,
  }) async {
    final patch = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (name != null) patch['name'] = name;
    if (position != null) patch['position'] = position;
    if (nationality != null) patch['nationality'] = nationality;
    if (photoUrl != null) patch['photoUrl'] = photoUrl;
    if (teamId != null) patch['teamId'] = teamId;
    if (shirtNumber != null) patch['shirtNumber'] = shirtNumber;
    if (dateOfBirth != null) {
      patch['dateOfBirth'] = dateOfBirth.toIso8601String();
    }
    if (patch.length <= 1) {
      debugPrint('updatePlayer: no fields to update for $id');
      return;
    }
    try {
      await _sb.from('Player').update(patch).eq('id', id);
    } catch (e) {
      debugPrint('updatePlayer($id): $e');
      rethrow;
    }
  }

  // ── Coaches ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCoaches({String? teamId}) async {
    try {
      final q = _sb.from('Coach').select('id, name, role, nationality, teamId');
      final rows = teamId != null
          ? await q.eq('teamId', teamId).limit(20)
          : await q.order('name').limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<void> createCoach({required String name, String role = 'head_coach', String? teamId, String? nationality}) async {
    final slug = '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    final id = 'coach-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Coach').insert({
      'id': id, 'name': name, 'slug': slug, 'role': role,
      if (teamId != null) 'teamId': teamId,
      if (nationality != null) 'nationality': nationality,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteCoach(String id) async {
    await _sb.from('Coach').delete().eq('id', id);
  }

  /// #5.1 — Partial update for an existing Coach row. Only non-null fields
  /// are written. Mirrors the column naming used by [createCoach]
  /// (camelCase: role, nationality, teamId, photoUrl).
  Future<void> updateCoach({
    required String id,
    String? name,
    String? nationality,
    String? role,
    String? teamId,
    String? photoUrl,
  }) async {
    final patch = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (name != null) patch['name'] = name;
    if (nationality != null) patch['nationality'] = nationality;
    if (role != null) patch['role'] = role;
    if (teamId != null) patch['teamId'] = teamId;
    if (photoUrl != null) patch['photoUrl'] = photoUrl;
    if (patch.length <= 1) {
      debugPrint('updateCoach: no fields to update for $id');
      return;
    }
    try {
      await _sb.from('Coach').update(patch).eq('id', id);
    } catch (e) {
      debugPrint('updateCoach($id): $e');
      rethrow;
    }
  }

  // ── Matches ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listMatches({int limit = 50}) async {
    try {
      final rows = await _sb.from('Match').select().order('kickoffAt', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<String> createMatch({required String homeTeam, required String awayTeam, required String league, required DateTime kickoffAt, String? venue, String? homeBadge, String? awayBadge, String? season}) async {
    final id = 'match-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Match').insert({
      'id': id, 'homeTeam': homeTeam, 'awayTeam': awayTeam, 'league': league,
      'kickoffAt': kickoffAt.toUtc().toIso8601String(),
      'status': 'upcoming', 'homeScore': 0, 'awayScore': 0,
      if (venue != null) 'venue': venue,
      if (homeBadge != null) 'homeBadge': homeBadge,
      if (awayBadge != null) 'awayBadge': awayBadge,
      if (season != null) 'season': season,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<void> updateMatch({required String id, int? homeScore, int? awayScore, String? status, int? minute}) async {
    final patch = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
    if (homeScore != null) patch['homeScore'] = homeScore;
    if (awayScore != null) patch['awayScore'] = awayScore;
    if (status != null) patch['status'] = status;
    if (minute != null) patch['minute'] = minute;
    await _sb.from('Match').update(patch).eq('id', id);
  }

  Future<void> deleteMatch(String id) async {
    await _sb.from('Match').delete().eq('id', id);
  }

  // ── Player match stats ─────────────────────────────────────────────────────

  Future<void> upsertPlayerStat({required String playerId, String? matchId, int goals = 0, int assists = 0, int minutes = 90, int yellowCards = 0, int redCards = 0}) async {
    final id = 'pms-$playerId-${matchId ?? 'overall'}-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('PlayerMatchStat').upsert({
      'id': id, 'playerId': playerId, 'matchId': matchId,
      'goals': goals, 'assists': assists, 'minutesPlayed': minutes,
      'yellowCards': yellowCards, 'redCards': redCards,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ── News ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listNews({int limit = 50}) async {
    try {
      final rows = await _sb.from('NewsItem').select().order('publishedAt', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<String> createNews({required String title, required String summary, required String body, required String category, String source = 'SportSphere', bool isBreaking = false, String? imageUrl, String? pdfUrl}) async {
    final id = 'news-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('NewsItem').insert({
      'id': id, 'title': title, 'summary': summary, 'body': body,
      'category': category, 'source': source, 'status': 'published',
      'is_breaking': isBreaking,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      'publishedAt': DateTime.now().toIso8601String(),
      'likeCount': 0, 'commentCount': 0, 'shareCount': 0,
    });
    return id;
  }

  Future<void> deleteNews(String id) async {
    await _sb.from('NewsItem').delete().eq('id', id);
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPosts({int limit = 50}) async {
    try {
      final rows = await _sb.from('Post').select().order('createdAt', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) { return []; }
  }

  Future<void> deletePostAdmin(String id) async {
    try { await _sb.from('PostLike').delete().eq('postId', id); } catch (_) {}
    try { await _sb.from('Comment').delete().eq('postId', id); } catch (_) {}
    try { await _sb.from('post_likes').delete().eq('post_id', id); } catch (_) {}
    await _sb.from('Post').delete().eq('id', id);
  }

  // ── Stats counts ───────────────────────────────────────────────────────────

  Future<int> _safeCount(String table, {String? role}) async {
    try {
      var q = _sb.from(table).select('id');
      if (role != null) {
        final rows = await q.ilike('role', role);
        return (rows as List).length;
      }
      final rows = await q;
      return (rows as List).length;
    } catch (e) {
      debugPrint('count $table: $e');
      return 0;
    }
  }

  Future<Map<String, int>> platformStats() async {
    // Count each table independently so one missing table does not zero the rest.
    final usersProfiles = await _safeCount('profiles');
    final usersLegacy = await _safeCount('User');
    final posts = await _safeCount('Post');
    final matches = await _safeCount('Match');
    final teams = await _safeCount('Team');
    final news = await _safeCount('NewsItem');
    final players = await _safeCount('Player');
    final coaches = await _safeCount('Coach');
    final competitions = await _safeCount('League');
    // Prefer profiles count when present (matches Users tab).
    final users = usersProfiles > 0 ? usersProfiles : usersLegacy;
    return {
      'users': users,
      'posts': posts,
      'matches': matches,
      'teams': teams,
      'news': news,
      'players': players,
      'coaches': coaches,
      'competitions': competitions,
    };
  }
}
