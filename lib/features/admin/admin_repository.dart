// lib/features/admin/admin_repository.dart
//
// Admin operations for the Playify admin console.
//
// SECURITY: This file used to construct a `SupabaseClient` with the
// service-role JWT hardcoded inline. That key grants full read/write
// access to every table and bypasses RLS — shipping it in the mobile
// client bundle was a critical vulnerability.
//
// All admin mutations now go through the VPS API (see
// `lib/core/data/vps_repository.dart`). The VPS enforces admin role
// checks server-side (see `vps/api/src/middleware/admin.ts`) and never
// trusts the client to assert privileges. Where a VPS route doesn't
// exist yet, the method calls the would-be endpoint and the VPS returns
// 404 — surfacing a friendly error in the UI. Each such method has a
// `TODO(VPS)` comment so the backend team knows what to add.
//
// No `SupabaseClient` type annotations, no `import 'package:supabase_flutter/...'`,
// no service-role credentials. JWT is attached automatically by ApiClient.

import 'package:flutter/foundation.dart';

import '../../core/data/vps_repository.dart';

class AdminRepository {
  const AdminRepository();

  static final _vps = const VpsRepository();

  // ── Entity Identity ────────────────────────────────────────────────────────

  /// Creates an auth user + profiles row for an entity (Team/Player/League).
  /// Returns the new auth UID, or null if creation fails.
  ///
  /// Delegates to `POST /v1/admin/entities/identity` on the VPS. The VPS uses
  /// its server-side service role key to create the auth user — never exposed
  /// to the client.
  Future<String?> _createEntityIdentity({
    required String entityType, // 'team' | 'player' | 'league'
    required String entityId,
    required String displayName,
    required String handle,
    String? logoUrl,
  }) async {
    try {
      return await _vps.createEntityIdentity({
        'entityType':   entityType,
        'entityId':     entityId,
        'displayName':  displayName,
        'handle':       handle,
        if (logoUrl != null) 'logoUrl': logoUrl,
      });
    } catch (e) {
      debugPrint('_createEntityIdentity($entityType, $entityId): $e');
      return null;
    }
  }

  /// Reconciles all entities that are missing their identity.
  /// Safe: never overwrites existing identities.
  /// Returns a report of actions taken.
  ///
  /// NOTE: This is a coarse client-side scan. The VPS exposes per-entity
  /// CRUD endpoints but no dedicated reconciliation route yet. Each missing
  /// entity triggers a separate identity-creation call (rate-limited by the
  /// VPS). A future `POST /v1/admin/reconcile` route could do this in one
  /// server-side transaction — TODO(VPS).
  Future<List<Map<String, dynamic>>> reconcileEntityIdentities() async {
    final report = <Map<String, dynamic>>[];
    for (final entityType in ['team', 'player', 'league']) {
      try {
        // Load all rows of this entity type from the VPS.
        List<Map<String, dynamic>> rows;
        if (entityType == 'team') {
          rows = await _vps.getAdminTeams(limit: 500);
        } else if (entityType == 'player') {
          // Player list endpoint is a search — empty q returns all.
          rows = await _vps.searchPlayers('', limit: 500);
        } else {
          rows = await _vps.getAdminLeagues(limit: 500);
        }
        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString() ?? '';
          final accountUid = row['accountUserId'] as String?;

          if (id.isEmpty || name.isEmpty) continue;

          if (accountUid != null && accountUid.isNotEmpty) {
            report.add({
              'entity_type': entityType,
              'entity_id': id,
              'entity_name': name,
              'status': 'ALREADY_HAS_IDENTITY',
              'action': 'NONE',
            });
            continue;
          }

          // Missing identity — create one
          final slug = name
              .toLowerCase()
              .replaceAll(' ', '_')
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
          final handle =
              '${slug}_${entityType[0]}${id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0').substring(0, 6.clamp(0, 6))}';
          final uid = await _createEntityIdentity(
            entityType: entityType,
            entityId: id,
            displayName: name,
            handle: handle,
            logoUrl: row['logoUrl'] as String?,
          );

          if (uid != null) {
            // Attach identity to entity via PATCH
            try {
              if (entityType == 'team') {
                await _vps.updateAdminTeam(id, {
                  'accountUserId': uid,
                  'isClaimable': true,
                  'identity_status': 'healthy',
                });
              } else if (entityType == 'player') {
                await _vps.updateAdminPlayer(id, {
                  'accountUserId': uid,
                  'isClaimable': true,
                  'identity_status': 'healthy',
                });
              } else {
                await _vps.updateAdminLeague(id, {
                  'accountUserId': uid,
                  'isClaimable': true,
                  'identity_status': 'healthy',
                });
              }
            } catch (e) {
              debugPrint('reconcile attach $entityType $id: $e');
            }

            // Create fan community for teams
            if (entityType == 'team') {
              await _createEntityCommunity(
                entityId: id,
                entityName: name,
                slug: handle,
              );
            }

            report.add({
              'entity_type': entityType,
              'entity_id': id,
              'entity_name': name,
              'account_uid': uid,
              'status': 'RECONCILED',
              'action': 'CREATED_IDENTITY',
            });
          } else {
            report.add({
              'entity_type': entityType,
              'entity_id': id,
              'entity_name': name,
              'status': 'FAILED',
              'action': 'IDENTITY_CREATION_FAILED',
            });
          }
        }
      } catch (e) {
        debugPrint('reconcile $entityType: $e');
      }
    }
    return report;
  }

  Future<void> _createEntityCommunity({
    required String entityId,
    required String entityName,
    required String slug,
  }) async {
    try {
      await _vps.createEntityCommunity({
        'entityType': 'team',
        'entityId': entityId,
        'name': '$entityName Fan Community',
        'slug': '${slug}_fans',
        'description': 'Official fan community for $entityName on Playify.',
      });
    } catch (e) {
      debugPrint('createEntityCommunity($entityId): $e');
    }
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listUsers({
    String q = '',
    int limit = 50,
  }) async {
    try {
      return await _vps.getAdminUsers(search: q.isEmpty ? null : q, limit: limit);
    } catch (e) {
      debugPrint('listUsers: $e');
      return [];
    }
  }

  Future<void> updateUserRole(String uid, String role) async {
    // VPS handles the cascade update to profiles + User tables.
    await _vps.setUserRole(uid, role);
  }

  Future<void> verifyUser(String uid, bool verified) async {
    // TODO(VPS): the `/v1/admin/users/:id/verify` route is not yet on the VPS.
    // The VpsRepository.verifyUser method issues the PATCH and the VPS will
    // return 404 until the route is added. Until then, this will throw —
    // callers should surface a friendly error.
    await _vps.verifyUser(uid, verified);
  }

  Future<void> deleteUser(String uid) async {
    // C8 — Do NOT use the client-side `_sb.auth.admin.deleteUser(...)`.
    // The VPS DELETE /v1/admin/users/:id route handles Supabase Auth user
    // deletion server-side using the service role key (never shipped to the
    // client). It also cascade-cleans profiles + User rows.
    //
    // The caller in admin_dashboard.dart wraps this in try/catch + SnackBar
    // so a server-side failure surfaces as a friendly error rather than
    // crashing the admin UI.
    await _vps.deleteUser(uid);
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String role,
    required String handle,
    required String firstName,
    required String lastName,
  }) async {
    // TODO(VPS): the `POST /v1/admin/users` route is not yet on the VPS.
    // VpsRepository.createAdminUser issues the request and returns null on
    // failure (it doesn't throw — best-effort).
    final uid = await _vps.createAdminUser({
      'email': email,
      'password': password,
      'role': role,
      'handle': handle,
      'firstName': firstName,
      'lastName': lastName,
    });
    if (uid == null) {
      throw Exception('Failed to create user — the VPS route may not exist yet.');
    }
  }

  // ── Competitions (Leagues) ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCompetitions() async {
    try {
      return await _vps.getAdminLeagues(limit: 100);
    } catch (e) {
      debugPrint('listCompetitions: $e');
      return [];
    }
  }

  Future<String> createCompetition({
    required String name,
    required String country,
    String? season,
    String type = 'league',
  }) async {
    final slug = name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final id = 'league-${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _vps.createAdminLeague({
        'id': id,
        'name': name,
        'slug': '${slug}_$id',
        'country': country,
        'type': type,
        if (season != null) 'season': season,
        'source': 'admin',
        'verified': true,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('createCompetition: $e');
      rethrow;
    }
    return id;
  }

  Future<void> deleteCompetition(String id) async {
    // The VPS should cascade-clean both League + Competition mirror tables.
    await _vps.deleteAdminLeague(id);
  }

  /// Partial update for an existing Competition row. Only non-null fields are
  /// written. The VPS handles dual-write to League + Competition mirror
  /// tables (TODO: confirm VPS dual-write behavior).
  Future<void> updateCompetition({
    required String id,
    String? name,
    String? logoUrl,
    String? season,
    String? sportSlug,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (name != null) patch['name'] = name;
    if (logoUrl != null) patch['logoUrl'] = logoUrl;
    if (season != null) patch['season'] = season;
    if (sportSlug != null) patch['sport_slug'] = sportSlug;
    if (patch.length <= 1) {
      debugPrint('updateCompetition: no fields to update for $id');
      return;
    }
    try {
      await _vps.updateAdminLeague(id, patch);
    } catch (e) {
      debugPrint('updateCompetition($id): $e');
      rethrow;
    }
  }

  // ── Teams ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listTeams({String? leagueId}) async {
    try {
      final rows = await _vps.getAdminTeams(limit: 200);
      if (leagueId == null) return rows;
      return rows
          .where((t) => t['leagueId']?.toString() == leagueId)
          .toList();
    } catch (e) {
      debugPrint('listTeams: $e');
      return [];
    }
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
    final slug = name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final id = 'team-${DateTime.now().millisecondsSinceEpoch}';
    final handle =
        '${slug}_t${id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0').substring(0, 6.clamp(0, 6))}';

    // Step 1: Create entity identity FIRST (auth user + profile + User row).
    final accountUid = await _createEntityIdentity(
      entityType: 'team',
      entityId: id,
      displayName: name,
      handle: handle,
      logoUrl: logoUrl,
    );

    // Step 2: Insert team with accountUserId via VPS.
    final body = <String, dynamic>{
      'id': id,
      'name': name,
      'slug': '${slug}_$id',
      'country': country,
      if (city != null) 'city': city,
      if (leagueId != null) 'leagueId': leagueId,
      if (venue != null) 'venue': venue,
      if (foundedYear != null) 'foundedYear': foundedYear,
      if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      if (primaryColor != null && primaryColor.isNotEmpty)
        'primaryColor': primaryColor,
      'source': 'admin',
      'verified': true,
      'isActive': true,
      'isClaimable': true,
      'identity_status': accountUid != null ? 'healthy' : 'pending',
      if (accountUid != null) 'accountUserId': accountUid,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _vps.createAdminTeam(body);
    } catch (e) {
      debugPrint('createTeam: $e');
      rethrow;
    }

    // Step 3: Create fan community (best-effort).
    if (accountUid != null) {
      await _createEntityCommunity(entityId: id, entityName: name, slug: handle);
    }

    return id;
  }

  Future<void> addTeamToCompetition(String teamId, String leagueId) async {
    await _vps.updateAdminTeam(teamId, {
      'leagueId': leagueId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Partial update for an existing Team row. Only non-null fields are
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
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
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
      await _vps.updateAdminTeam(id, patch);
    } catch (e) {
      debugPrint('updateTeam($id): $e');
      rethrow;
    }
  }

  Future<void> deleteTeam(String id) async {
    await _vps.deleteAdminTeam(id);
  }

  // ── Players ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPlayers({String? teamId}) async {
    try {
      final rows = await _vps.searchPlayers('', limit: 200);
      if (teamId == null) return rows;
      return rows.where((p) => p['teamId']?.toString() == teamId).toList();
    } catch (e) {
      debugPrint('listPlayers: $e');
      return [];
    }
  }

  Future<void> createPlayer({
    required String name,
    required String position,
    String? teamId,
    String? nationality,
    int? shirtNumber,
    String? photoUrl,
    DateTime? dateOfBirth,
    int? heightCm,
    int? weightKg,
  }) async {
    final id = 'player-${DateTime.now().millisecondsSinceEpoch}';
    final slug = '${name.toLowerCase().replaceAll(' ', '_')}_$id';
    final parts = name.trim().split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final handle =
        '${firstName.toLowerCase()}${lastName.isNotEmpty ? '_${lastName.toLowerCase()}' : ''}_p${id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0').substring(0, 6.clamp(0, 6))}';

    // Create identity (best-effort — the VPS may not yet expose this route).
    final accountUid = await _createEntityIdentity(
      entityType: 'player',
      entityId: id,
      displayName: name,
      handle: handle.replaceAll(RegExp(r'[^a-z0-9_]'), ''),
      logoUrl: photoUrl,
    );

    final body = <String, dynamic>{
      'id': id,
      'name': name,
      'firstName': firstName,
      'lastName': lastName,
      'slug': slug,
      'position': position,
      'sport_slug': 'football',
      'isClaimable': true,
      'identity_status': accountUid != null ? 'healthy' : 'pending',
      if (accountUid != null) 'accountUserId': accountUid,
      if (teamId != null && teamId.isNotEmpty) 'teamId': teamId,
      if (nationality != null) 'nationality': nationality,
      if (shirtNumber != null) 'shirtNumber': shirtNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (dateOfBirth != null)
        'dateOfBirth': dateOfBirth.toIso8601String(),
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
      'isActive': true,
      'verified': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _vps.createAdminPlayer(body);
    } catch (e) {
      debugPrint('createPlayer: $e');
      rethrow;
    }
  }

  Future<void> deletePlayer(String id) async {
    await _vps.deleteAdminPlayer(id);
  }

  /// Partial update for an existing Player row.
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
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
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
      await _vps.updateAdminPlayer(id, patch);
    } catch (e) {
      debugPrint('updatePlayer($id): $e');
      rethrow;
    }
  }

  // ── Coaches ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCoaches({String? teamId}) async {
    try {
      final rows = await _vps.getAdminCoaches(limit: 200);
      if (teamId == null) return rows;
      return rows.where((c) => c['teamId']?.toString() == teamId).toList();
    } catch (e) {
      debugPrint('listCoaches: $e');
      return [];
    }
  }

  Future<void> createCoach({
    required String name,
    String role = 'head_coach',
    String? teamId,
    String? nationality,
  }) async {
    final slug =
        '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
    final id = 'coach-${DateTime.now().millisecondsSinceEpoch}';
    final body = <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'role': role,
      if (teamId != null) 'teamId': teamId,
      if (nationality != null) 'nationality': nationality,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    try {
      await _vps.createAdminCoach(body);
    } catch (e) {
      debugPrint('createCoach: $e');
      rethrow;
    }
  }

  Future<void> deleteCoach(String id) async {
    await _vps.deleteAdminCoach(id);
  }

  /// Partial update for an existing Coach row.
  Future<void> updateCoach({
    required String id,
    String? name,
    String? nationality,
    String? role,
    String? teamId,
    String? photoUrl,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
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
      await _vps.updateAdminCoach(id, patch);
    } catch (e) {
      debugPrint('updateCoach($id): $e');
      rethrow;
    }
  }

  // ── Matches ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listMatches({int limit = 50}) async {
    try {
      return await _vps.getAdminMatches(limit: limit);
    } catch (e) {
      debugPrint('listMatches: $e');
      return [];
    }
  }

  Future<String> createMatch({
    required String homeTeam,
    required String awayTeam,
    required String league,
    required DateTime kickoffAt,
    String? venue,
    String? homeBadge,
    String? awayBadge,
    String? season,
  }) async {
    final body = <String, dynamic>{
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'league': league,
      'kickoffAt': kickoffAt.toUtc().toIso8601String(),
      'status': 'upcoming',
      if (venue != null) 'venue': venue,
      if (homeBadge != null) 'homeBadge': homeBadge,
      if (awayBadge != null) 'awayBadge': awayBadge,
      if (season != null) 'season': season,
    };
    final match = await _vps.createAdminMatch(body);
    return match['id']?.toString() ??
        'match-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updateMatch({
    required String id,
    int? homeScore,
    int? awayScore,
    String? status,
    int? minute,
  }) async {
    final patch = <String, dynamic>{};
    if (homeScore != null) patch['homeScore'] = homeScore;
    if (awayScore != null) patch['awayScore'] = awayScore;
    if (status != null) patch['status'] = status;
    if (minute != null) patch['minute'] = minute;
    if (patch.isEmpty) return;
    await _vps.updateAdminMatch(id, patch);
  }

  Future<void> deleteMatch(String id) async {
    await _vps.deleteAdminMatch(id);
  }

  // ── Player match stats ─────────────────────────────────────────────────────

  Future<void> upsertPlayerStat({
    required String playerId,
    String? matchId,
    int goals = 0,
    int assists = 0,
    int minutes = 90,
    int yellowCards = 0,
    int redCards = 0,
  }) async {
    final body = <String, dynamic>{
      'playerId': playerId,
      if (matchId != null) 'matchId': matchId,
      'goals': goals,
      'assists': assists,
      'minutesPlayed': minutes,
      'yellowCards': yellowCards,
      'redCards': redCards,
      'createdAt': DateTime.now().toIso8601String(),
    };
    try {
      await _vps.upsertPlayerStat(playerId, body);
    } catch (e) {
      debugPrint('upsertPlayerStat($playerId): $e');
      rethrow;
    }
  }

  // ── News ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listNews({int limit = 50}) async {
    try {
      return await _vps.getAdminNews(limit: limit);
    } catch (e) {
      debugPrint('listNews: $e');
      return [];
    }
  }

  Future<String> createNews({
    required String title,
    required String summary,
    required String body,
    required String category,
    String source = 'Playify',
    bool isBreaking = false,
    String? imageUrl,
    String? pdfUrl,
  }) async {
    final id = 'news-${DateTime.now().millisecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'id': id,
      'title': title,
      'summary': summary,
      'body': body,
      'category': category,
      'source': source,
      'status': 'published',
      'is_breaking': isBreaking,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      'publishedAt': DateTime.now().toIso8601String(),
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
    };
    try {
      // Try the admin news endpoint first; fall back to the public news
      // endpoint if the admin route doesn't exist yet (TODO VPS).
      try {
        await _vps.createAdminNews(payload);
      } catch (_) {
        await _vps.createNewsPost(payload);
      }
    } catch (e) {
      debugPrint('createNews: $e');
      rethrow;
    }
    return id;
  }

  Future<void> deleteNews(String id) async {
    await _vps.deleteAdminNews(id);
  }

  // ── Posts ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPosts({int limit = 50}) async {
    try {
      return await _vps.getAdminPosts(limit: limit);
    } catch (e) {
      debugPrint('listPosts: $e');
      return [];
    }
  }

  Future<void> deletePostAdmin(String id) async {
    // The VPS cascade-deletes PostLike / Comment / post_likes server-side.
    // If the admin route isn't deployed yet, fall back to the public
    // /v1/social/posts/:id DELETE route (which still deletes the Post row
    // but may leave orphaned likes/comments — TODO VPS: deploy admin route).
    try {
      await _vps.deleteAdminPost(id);
    } catch (e) {
      debugPrint('deletePostAdmin fallback to /v1/social/posts: $e');
      await _vps.deletePost(id);
    }
  }

  // ── Bulk Upload ──────────────────────────────────────────────────────────

  /// Bulk-create teams from a list of row maps.
  /// Each row must contain: `name` (String), `country` (String).
  /// Optional: `city`, `leagueId`, `venue`, `foundedYear`, `primaryColor`.
  /// Returns the number of rows successfully inserted.
  Future<int> bulkCreateTeams(List<Map<String, dynamic>> rows) async {
    final now = DateTime.now().toIso8601String();
    final batch = <Map<String, dynamic>>[];
    for (final r in rows) {
      final name = (r['name'] as String?)?.trim() ?? '';
      final country = (r['country'] as String?)?.trim() ?? '';
      if (name.isEmpty || country.isEmpty) continue;
      final slug = name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final id = 'team-${DateTime.now().millisecondsSinceEpoch}-${batch.length}';
      batch.add({
        'id': id,
        'name': name,
        'slug': '${slug}_$id',
        'country': country,
        if (r['city'] != null) 'city': (r['city'] as String).trim(),
        if (r['leagueId'] != null) 'leagueId': (r['leagueId'] as String).trim(),
        if (r['venue'] != null) 'venue': (r['venue'] as String).trim(),
        if (r['foundedYear'] != null)
          'foundedYear': int.tryParse(r['foundedYear'].toString()) ?? 0,
        'source': 'admin',
        'verified': true,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    try {
      return await _vps.bulkCreateTeams(batch);
    } catch (e) {
      debugPrint('bulkCreateTeams: $e — falling back to per-row insert');
      // Fallback: insert one at a time.
      int inserted = 0;
      for (final row in batch) {
        try {
          await _vps.createAdminTeam(row);
          inserted++;
        } catch (e2) {
          debugPrint('bulkCreateTeams per-row $inserted: $e2');
        }
      }
      return inserted;
    }
  }

  /// Bulk-create players from a list of row maps.
  /// Each row must contain: `name` (String), `position` (String).
  /// Optional: `teamId`, `nationality`, `shirtNumber`.
  /// Returns the number of rows successfully inserted.
  Future<int> bulkCreatePlayers(List<Map<String, dynamic>> rows) async {
    final now = DateTime.now().toIso8601String();
    final batch = <Map<String, dynamic>>[];
    for (final r in rows) {
      final name = (r['name'] as String?)?.trim() ?? '';
      final position = (r['position'] as String?)?.trim() ?? '';
      if (name.isEmpty || position.isEmpty) continue;
      final slug =
          '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final id =
          'player-${DateTime.now().millisecondsSinceEpoch}-${batch.length}';
      final parts = name.trim().split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      batch.add({
        'id': id,
        'name': name,
        'firstName': firstName,
        'lastName': lastName,
        'slug': slug,
        'position': position,
        'sport_slug': 'football',
        if (r['teamId'] != null && (r['teamId'] as String).trim().isNotEmpty)
          'teamId': (r['teamId'] as String).trim(),
        if (r['nationality'] != null)
          'nationality': (r['nationality'] as String).trim(),
        if (r['shirtNumber'] != null)
          'shirtNumber': int.tryParse(r['shirtNumber'].toString()) ?? 0,
        'isActive': true,
        'verified': false,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    try {
      return await _vps.bulkCreatePlayers(batch);
    } catch (e) {
      debugPrint('bulkCreatePlayers: $e — falling back to per-row insert');
      int inserted = 0;
      for (final row in batch) {
        try {
          await _vps.createAdminPlayer(row);
          inserted++;
        } catch (e2) {
          debugPrint('bulkCreatePlayers per-row $inserted: $e2');
        }
      }
      return inserted;
    }
  }

  /// Bulk-create fixtures from a list of row maps.
  /// Each row must contain: `homeTeam` (String), `awayTeam` (String),
  ///   `league` (String), `kickoffAt` (String, ISO 8601 or 'yyyy-MM-dd HH:mm').
  /// Optional: `venue`, `season`.
  /// Returns the number of rows successfully inserted.
  Future<int> bulkCreateFixtures(List<Map<String, dynamic>> rows) async {
    final now = DateTime.now().toIso8601String();
    final batch = <Map<String, dynamic>>[];
    // Look up team badges for logo enrichment
    final allTeams = await listTeams();
    final teamBadges = <String, String>{};
    for (final t in allTeams) {
      final n = (t['name'] as String?)?.trim().toLowerCase() ?? '';
      final logo = (t['logoUrl'] as String?) ?? '';
      if (n.isNotEmpty && logo.isNotEmpty) teamBadges[n] = logo;
    }
    for (final r in rows) {
      final home = (r['homeTeam'] as String?)?.trim() ?? '';
      final away = (r['awayTeam'] as String?)?.trim() ?? '';
      final league = (r['league'] as String?)?.trim() ?? '';
      if (home.isEmpty || away.isEmpty || league.isEmpty) continue;
      DateTime? kickoff;
      final rawDate = (r['kickoffAt'] as String?)?.trim() ?? '';
      if (rawDate.isNotEmpty) {
        kickoff = DateTime.tryParse(rawDate);
        kickoff ??= DateTime.tryParse(rawDate.replaceAll(' ', 'T'));
      }
      kickoff ??= DateTime.now().add(Duration(days: batch.length + 1));
      batch.add({
        'homeTeam': home,
        'awayTeam': away,
        'league': league,
        'kickoffAt': kickoff.toUtc().toIso8601String(),
        'status': 'upcoming',
        'homeScore': 0,
        'awayScore': 0,
        if (r['venue'] != null) 'venue': (r['venue'] as String).trim(),
        'homeBadge': teamBadges[home.toLowerCase()] ?? '',
        'awayBadge': teamBadges[away.toLowerCase()] ?? '',
        if (r['season'] != null) 'season': (r['season'] as String).trim(),
        'createdAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    try {
      return await _vps.bulkCreateFixtures(batch);
    } catch (e) {
      debugPrint('bulkCreateFixtures: $e — falling back to per-row insert');
      int inserted = 0;
      for (final row in batch) {
        try {
          await _vps.createAdminMatch(row);
          inserted++;
        } catch (e2) {
          debugPrint('bulkCreateFixtures per-row $inserted: $e2');
        }
      }
      return inserted;
    }
  }

  // ── Stats ───────────────────────────────────────────────────────────────────

  Future<Map<String, int>> platformStats() async {
    try {
      // getAdminStats returns {users, posts, players, news, matches} as ints.
      final stats = await _vps.getAdminStats();
      return {
        'users':    (stats['users']    as num?)?.toInt() ?? 0,
        'posts':    (stats['posts']    as num?)?.toInt() ?? 0,
        'matches':  (stats['matches']  as num?)?.toInt() ?? 0,
        'players':  (stats['players']  as num?)?.toInt() ?? 0,
        'news':     (stats['news']     as num?)?.toInt() ?? 0,
        // The VPS /stats route doesn't return teams/coaches/competitions
        // counts yet — TODO(VPS): extend the stats route. For now we
        // best-effort count them via the list endpoints.
        'teams':         await _safeListCount(_vps.getAdminTeams(limit: 500)),
        'coaches':       await _safeListCount(_vps.getAdminCoaches(limit: 500)),
        'competitions':  await _safeListCount(_vps.getAdminLeagues(limit: 500)),
      };
    } catch (e) {
      debugPrint('platformStats: $e');
      return {
        'users': 0,
        'posts': 0,
        'matches': 0,
        'teams': 0,
        'news': 0,
        'players': 0,
        'coaches': 0,
        'competitions': 0,
      };
    }
  }

  Future<int> _safeListCount(Future<List<Map<String, dynamic>>> future) async {
    try {
      final list = await future;
      return list.length;
    } catch (_) {
      return 0;
    }
  }
}
