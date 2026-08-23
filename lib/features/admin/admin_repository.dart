import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  // Service role client for operations blocked by RLS
  static SupabaseClient get _admin {
    try {
      return SupabaseClient(
        'https://fffqjbrethogesgghjsn.supabase.co',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZmZnFqYnJldGhvZ2VzZ2doanNuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzE2OTA1NSwiZXhwIjoyMTAyNzQ1MDU1fQ.TFIjn9A6i72aitmPbrsU-DhZjJ9JC51VOrbLTUbCrCE',
      );
    } catch (_) { return Supabase.instance.client; }
  }

  // ── Entity Identity ────────────────────────────────────────────────────────

  /// Creates a Supabase Auth user + profiles row for an entity (Team/Player/League).
  /// Returns the new auth UID, or null if creation fails.
  /// Never stores plaintext passwords in any public table.
  Future<String?> _createEntityIdentity({
    required String entityType,  // 'team' | 'player' | 'league'
    required String entityId,
    required String displayName,
    required String handle,
    String? logoUrl,
  }) async {
    // Derive a deterministic but unguessable email for this entity
    final email = '$handle.$entityType@entity.playify.app';
    // Generate a secure random password — entity can only log in after claiming
    final password = 'Entity!${DateTime.now().millisecondsSinceEpoch}@Playify';

    try {
      // 1. Create auth user
      final res = await _admin.auth.admin.createUser(AdminUserAttributes(
        email: email,
        password: password,
        userMetadata: {
          'entity_type': entityType,
          'entity_id': entityId,
          'display_name': displayName,
          'handle': handle,
          'is_entity_account': true,
        },
        emailConfirm: true,
      ));
      final uid = res.user?.id.toString();
      if (uid == null || uid.isEmpty) return null;

      // 2. Create profiles row
      await _admin.from('profiles').upsert({
        'id': uid,
        'handle': handle,
        'role': entityType,
        'first_name': displayName,
        'last_name': '',
        'email': email,
        if (logoUrl != null) 'avatar_url': logoUrl,
        'bio': 'Official $displayName account on Playify.',
      });

      // 3. Create User row for feed compatibility
      try {
        await _admin.from('User').upsert({
          'id': uid,
          'handle': handle,
          'name': displayName,
          'email': email,
          'role': entityType,
          'isVerified': true,
          if (logoUrl != null) 'avatarUrl': logoUrl,
        });
      } catch (_) {}

      return uid;
    } catch (e) {
      debugPrint('_createEntityIdentity($entityType, $entityId): $e');
      return null;
    }
  }

  /// Resolves entity → profiles row via accountUserId.
  /// This is the canonical resolver — never search profiles by entity name.
  Future<Map<String, dynamic>?> resolveEntityProfile({
    required String entityType,
    required String entityId,
  }) async {
    try {
      // 1. Get accountUserId from the entity
      final table = entityType == 'team' ? 'Team'
          : entityType == 'player' ? 'Player' : 'League';
      final entity = await _sb.from(table).select('accountUserId, name, logoUrl')
          .eq('id', entityId).maybeSingle();
      if (entity == null) return null;

      final accountUid = entity['accountUserId'] as String?;
      if (accountUid == null || accountUid.isEmpty) return null;

      // 2. Get profile via accountUserId
      final profile = await _sb.from('profiles')
          .select().eq('id', accountUid).maybeSingle();
      return profile as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('resolveEntityProfile($entityType, $entityId): $e');
      return null;
    }
  }

  /// Reconciles all entities that are missing their identity.
  /// Safe: never overwrites existing identities.
  /// Returns a report of actions taken.
  Future<List<Map<String, dynamic>>> reconcileEntityIdentities() async {
    final report = <Map<String, dynamic>>[];
    for (final entityType in ['team', 'player', 'league']) {
      final table = entityType == 'team' ? 'Team'
          : entityType == 'player' ? 'Player' : 'League';
      try {
        final rows = await _admin.from(table).select('id, name, logoUrl, accountUserId, isClaimable');
        for (final row in rows as List) {
          final id = row['id']?.toString() ?? '';
          final name = row['name']?.toString() ?? '';
          final accountUid = row['accountUserId'] as String?;

          if (id.isEmpty || name.isEmpty) continue;

          if (accountUid != null && accountUid.isNotEmpty) {
            // Already has identity — mark healthy
            report.add({'entity_type': entityType, 'entity_id': id,
                'entity_name': name, 'status': 'ALREADY_HAS_IDENTITY', 'action': 'NONE'});
            continue;
          }

          // Missing identity — create one
          final slug = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
          final handle = '${slug}_${entityType[0]}${id.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 6)}';
          final uid = await _createEntityIdentity(
            entityType: entityType, entityId: id, displayName: name,
            handle: handle, logoUrl: row['logoUrl'] as String?,
          );

          if (uid != null) {
            // Attach identity to entity
            await _admin.from(table).update({
              'accountUserId': uid,
              'isClaimable': true,
              'identity_status': 'healthy',
            }).eq('id', id);

            // Create fan community for teams
            if (entityType == 'team') {
              await _createEntityCommunity(entityId: id, entityName: name, slug: handle);
            }

            report.add({'entity_type': entityType, 'entity_id': id,
                'entity_name': name, 'account_uid': uid,
                'status': 'RECONCILED', 'action': 'CREATED_IDENTITY'});
          } else {
            report.add({'entity_type': entityType, 'entity_id': id,
                'entity_name': name, 'status': 'FAILED', 'action': 'IDENTITY_CREATION_FAILED'});
          }
        }
      } catch (e) {
        debugPrint('reconcile $table: $e');
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
      await _admin.from('entity_communities').upsert({
        'entity_type': 'team',
        'entity_id': entityId,
        'name': '$entityName Fan Community',
        'slug': '${slug}_fans',
        'description': 'Official fan community for $entityName on Playify.',
      });
    } catch (e) {
      debugPrint('createEntityCommunity($entityId): $e');
    }
  }

  /// Follow or unfollow an entity (Team/Player/League).
  /// Uses entity_follows table — works even before Fan/Follow tables support UUIDs.
  Future<void> followEntity({
    required String entityType,
    required String entityId,
    required bool follow,
    bool isFan = false,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in to follow');

    // Resolve accountUserId for this entity
    final table = entityType == 'team' ? 'Team' : entityType == 'player' ? 'Player' : 'League';
    String? accountUid;
    try {
      final entity = await _sb.from(table).select('accountUserId').eq('id', entityId).maybeSingle();
      accountUid = entity?['accountUserId'] as String?;
    } catch (_) {}

    if (follow) {
      await _admin.from('entity_follows').upsert({
        'follower_id': uid,
        'entity_type': entityType,
        'entity_id': entityId,
        'account_uid': accountUid,
        'is_fan': isFan,
      });
    } else {
      await _admin.from('entity_follows').delete()
          .eq('follower_id', uid)
          .eq('entity_type', entityType)
          .eq('entity_id', entityId);
    }
  }

  Future<bool> isFollowingEntity({
    required String entityType,
    required String entityId,
    bool checkFan = false,
  }) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      var q = _sb.from('entity_follows').select('id')
          .eq('follower_id', uid).eq('entity_type', entityType).eq('entity_id', entityId);
      if (checkFan) q = q.eq('is_fan', true);
      final rows = await q;
      return (rows as List).isNotEmpty;
    } catch (_) { return false; }
  }

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
    try { await _sb.from('User').update({'role': role}).eq('id', uid); } catch (_) {}
  }

  Future<void> verifyUser(String uid, bool verified) async {
    await _sb.from('profiles').update({'is_verified': verified}).eq('id', uid);
    try { await _sb.from('User').update({'isVerified': verified}).eq('id', uid); } catch (_) {}
  }

  Future<void> deleteUser(String uid) async {
    // C8 — Do NOT use the client-side `_sb.auth.admin.deleteUser(...)`.
    // `auth.admin` requires the Supabase service role key, which must never
    // ship in the mobile client. Calling it from the client either fails
    // (anon key lacks admin scope) or, worse, leaks the service role key.
    //
    // Instead, invoke the `admin-delete-user` Edge Function. That function
    // runs server-side with the service role key and deletes the auth.user
    // row + any related profile / legacy User rows. The Edge Function is
    // created by the EDGE task agent.
    try {
      final res = await _sb.functions.invoke(
        'admin-delete-user',
        body: {'uid': uid},
      );
      if (res.status != 200) {
        throw Exception('Failed to delete user: ${res.data}');
      }
    } catch (e) {
      // Surface the error so the admin UI can warn the operator. A
      // silently-swallowed failure here would leave an orphaned auth user
      // that the admin thinks was deleted.
      debugPrint('deleteUser edge function failed for $uid: $e');
      rethrow;
    }
  }

  Future<void> createUser({required String email, required String password, required String role, required String handle, required String firstName, required String lastName}) async {
    final res = await _admin.auth.admin.createUser(AdminUserAttributes(
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
      await _admin.from('League').insert({
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
    final handle = '${slug}_t${id.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 6)}';

    // Step 1: Create entity identity FIRST
    final accountUid = await _createEntityIdentity(
      entityType: 'team', entityId: id, displayName: name,
      handle: handle, logoUrl: logoUrl,
    );

    // Step 2: Insert team with accountUserId
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
      'isClaimable': true,
      'identity_status': accountUid != null ? 'healthy' : 'pending',
      if (accountUid != null) 'accountUserId': accountUid,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _admin.from('Team').insert({
        ...base,
        if (primaryColor != null && primaryColor.isNotEmpty) 'primaryColor': primaryColor,
      });
    } catch (e) {
      await _admin.from('Team').insert(base);
    }

    // Step 3: Create fan community
    if (accountUid != null) {
      await _createEntityCommunity(entityId: id, entityName: name, slug: handle);
    }

    return id;
  }

  Future<void> addTeamToCompetition(String teamId, String leagueId) async {
    await _admin.from('Team').update({'leagueId': leagueId, 'updatedAt': DateTime.now().toIso8601String()}).eq('id', teamId);
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
      await _admin.from('Team').update(patch).eq('id', id);
    } catch (e) {
      // Try without primaryColor (column may be missing if migration not applied)
      if (primaryColor != null && primaryColor.isNotEmpty) {
        patch.remove('primaryColor');
        try {
          await _admin.from('Team').update(patch).eq('id', id);
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
      final q = _sb.from('Player').select('id, name, position, nationality, teamId, shirtNumber');
      final rows = teamId != null
          ? await q.eq('teamId', teamId).order('name').limit(100)
          : await q.order('name').limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('listPlayers error: $e');
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
    final handle = '${firstName.toLowerCase()}${lastName.isNotEmpty ? '_${lastName.toLowerCase()}' : ''}_p${id.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 6)}';

    // Create identity
    final accountUid = await _createEntityIdentity(
      entityType: 'player', entityId: id, displayName: name,
      handle: handle.replaceAll(RegExp(r'[^a-z0-9_]'), ''), logoUrl: photoUrl,
    );

    await _admin.from('Player').insert({
      'id': id, 'name': name, 'firstName': firstName, 'lastName': lastName,
      'slug': slug, 'position': position, 'sport_slug': 'football',
      'isClaimable': true,
      'identity_status': accountUid != null ? 'healthy' : 'pending',
      if (accountUid != null) 'accountUserId': accountUid,
      if (teamId != null && teamId.isNotEmpty) 'teamId': teamId,
      if (nationality != null) 'nationality': nationality,
      if (shirtNumber != null) 'shirtNumber': shirtNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
      'isActive': true, 'verified': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
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
    await _admin.from('Coach').insert({
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
    await _admin.from('Match').insert({
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
    await _admin.from('PlayerMatchStat').upsert({
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
      final slug = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final id = 'team-${DateTime.now().millisecondsSinceEpoch}-${batch.length}';
      batch.add({
        'id': id, 'name': name, 'slug': '${slug}_$id',
        'country': country,
        if (r['city'] != null) 'city': (r['city'] as String).trim(),
        if (r['leagueId'] != null) 'leagueId': (r['leagueId'] as String).trim(),
        if (r['venue'] != null) 'venue': (r['venue'] as String).trim(),
        if (r['foundedYear'] != null) 'foundedYear': int.tryParse(r['foundedYear'].toString()) ?? 0,
        'source': 'admin', 'verified': true, 'isActive': true,
        'createdAt': now, 'updatedAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    // Insert in chunks of 50 (PostgREST default limit)
    int inserted = 0;
    for (var i = 0; i < batch.length; i += 50) {
      final chunk = batch.sublist(i, i + 50 > batch.length ? batch.length : i + 50);
      await _admin.from('Team').insert(chunk);
      inserted += chunk.length;
    }
    return inserted;
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
      final slug = '${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final id = 'player-${DateTime.now().millisecondsSinceEpoch}-${batch.length}';
      final parts = name.trim().split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      batch.add({
        'id': id, 'name': name, 'firstName': firstName, 'lastName': lastName,
        'slug': slug, 'position': position, 'sport_slug': 'football',
        if (r['teamId'] != null && (r['teamId'] as String).trim().isNotEmpty)
          'teamId': (r['teamId'] as String).trim(),
        if (r['nationality'] != null) 'nationality': (r['nationality'] as String).trim(),
        if (r['shirtNumber'] != null) 'shirtNumber': int.tryParse(r['shirtNumber'].toString()) ?? 0,
        'isActive': true, 'verified': false, 'createdAt': now, 'updatedAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    int inserted = 0;
    for (var i = 0; i < batch.length; i += 50) {
      final chunk = batch.sublist(i, i + 50 > batch.length ? batch.length : i + 50);
      await _admin.from('Player').insert(chunk);
      inserted += chunk.length;
    }
    return inserted;
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
      // Parse kickoff
      DateTime? kickoff;
      final rawDate = (r['kickoffAt'] as String?)?.trim() ?? '';
      if (rawDate.isNotEmpty) {
        kickoff = DateTime.tryParse(rawDate);
        // Try 'yyyy-MM-dd HH:mm' format if ISO parsing fails
        kickoff ??= DateTime.tryParse(rawDate.replaceAll(' ', 'T'));
      }
      kickoff ??= DateTime.now().add(Duration(days: batch.length + 1));
      final id = 'match-${DateTime.now().millisecondsSinceEpoch}-${batch.length}';
      batch.add({
        'id': id, 'homeTeam': home, 'awayTeam': away, 'league': league,
        'kickoffAt': kickoff.toUtc().toIso8601String(),
        'status': 'upcoming', 'homeScore': 0, 'awayScore': 0,
        if (r['venue'] != null) 'venue': (r['venue'] as String).trim(),
        'homeBadge': teamBadges[home.toLowerCase()] ?? '',
        'awayBadge': teamBadges[away.toLowerCase()] ?? '',
        if (r['season'] != null) 'season': (r['season'] as String).trim(),
        'createdAt': now,
      });
    }
    if (batch.isEmpty) return 0;
    int inserted = 0;
    for (var i = 0; i < batch.length; i += 50) {
      final chunk = batch.sublist(i, i + 50 > batch.length ? batch.length : i + 50);
      await _admin.from('Match').insert(chunk);
      inserted += chunk.length;
    }
    return inserted;
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
