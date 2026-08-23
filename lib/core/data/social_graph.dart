import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a person in the social graph
class GraphPerson {
  final String id;
  final String handle;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool youFollow;
  final bool youFan;

  const GraphPerson({
    required this.id,
    required this.handle,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.youFollow = false,
    this.youFan = false,
  });

  /// Creates a copy with updated follow/fan status
  GraphPerson copyWith({
    bool? youFollow,
    bool? youFan,
  }) {
    return GraphPerson(
      id: id,
      handle: handle,
      name: name,
      avatarUrl: avatarUrl,
      role: role,
      youFollow: youFollow ?? this.youFollow,
      youFan: youFan ?? this.youFan,
    );
  }
}

/// Social graph service for follow/fan relationships
class SocialGraph {
  const SocialGraph();

  SupabaseClient get _sb => Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;
  String? get currentUid => _uid;

  /// Resolve an ID or handle to a user ID.
  ///
  /// Returns `null` when no User row (and no entity-backed account) can
  /// be resolved for the given handle, so callers can bail out gracefully
  /// instead of attempting to follow/fan a raw handle string.
  Future<String?> resolveId(String idOrHandle) => _resolve(idOrHandle);

  /// Check if user [me] is following [targetId]
  Future<bool> isFollowing(String me, String targetId) async {
    try {
      final rows = await _sb
          .from('Follow')
          .select('followerId')
          .eq('followerId', me)
          .eq('followingId', targetId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('isFollowing($me -> $targetId) error: $e');
      return false;
    }
  }

  /// Check if user [me] is a fan of [targetId]
  Future<bool> isFan(String me, String targetId) async {
    try {
      final rows = await _sb
          .from('fans')
          .select('fan_id')
          .eq('fan_id', me)
          .eq('target_id', targetId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('isFan($me -> $targetId) error: $e');
      return false;
    }
  }

  /// Returns the live fan count for [targetId] via the `count_fans_of`
  /// RPC. Use this when freshness matters (e.g. right after a fan
  /// toggle) instead of reading the cached `User.fanCount` column.
  Future<int> fanCount(String targetId) async {
    try {
      final result =
          await _sb.rpc('count_fans_of', params: {'p_id': targetId});
      if (result is int) return result;
      if (result is num) return result.toInt();
      return 0;
    } catch (e) {
      debugPrint('fanCount($targetId) error: $e');
      return 0;
    }
  }

  /// Refresh counts for a user.
  ///
  /// The underlying `refresh_user_counts` RPC was revoked from `anon`
  /// in migration `20260824000000_fix_top3_critical_security.sql`, so
  /// this must be called from an authenticated session. We short-circuit
  /// when there is no current user rather than throwing.
  Future<void> refreshCounts(String id) async {
    if (_uid == null) {
      debugPrint('refreshCounts($id) skipped: no authenticated session');
      return;
    }
    try {
      await _sb.rpc('refresh_user_counts', params: {'p_id': id});
    } catch (e) {
      // Log but don't throw — counts will catch up on the next refresh.
      debugPrint('Failed to refresh counts for $id: $e');
    }
  }

  /// Resolve a handle or ID to a user ID.
  ///
  /// 1. If [idOrHandle] looks like a UUID, return it as-is.
  /// 2. Try the `User` table by exact then case-insensitive handle.
  /// 3. Fall back to org-role entity tables (`Team`, `Player`, `Coach`,
  ///    `League`, `Competition`, `Community`) — each may carry an
  ///    `accountUserId` column pointing back to the User that owns the
  ///    entity account. We try the slug in both `_` and `-` forms because
  ///    the User handle convention uses underscores while entity slugs
  ///    use dashes.
  /// 4. If nothing matches, return `null` so callers don't try to
  ///    follow/fan a raw handle string.
  Future<String?> _resolve(String idOrHandle) async {
    try {
      final raw = idOrHandle.replaceAll('@', '').trim();
      if (raw.isEmpty) return null;

      // If it looks like a UUID, return as-is.
      if (raw.contains('-') && raw.length > 20) return raw;

      // 1) Try User table by exact handle.
      final user = await _sb
          .from('User')
          .select('id')
          .eq('handle', raw)
          .maybeSingle();
      if (user?['id'] != null) return user!['id'].toString();

      // 2) Try case-insensitive handle match.
      final userCi = await _sb
          .from('User')
          .select('id')
          .ilike('handle', raw)
          .maybeSingle();
      if (userCi?['id'] != null) return userCi!['id'].toString();

      // 3) Org-role fallback — resolve through entity `accountUserId`.
      final slugDash = raw.replaceAll('_', '-');
      final accountUserId = await _resolveEntityAccount(raw, slugDash);
      if (accountUserId != null && accountUserId.isNotEmpty) {
        return accountUserId;
      }

      // 4) Nothing matched — return null so callers bail out gracefully.
      return null;
    } catch (e) {
      debugPrint('Error resolving ID for $idOrHandle: $e');
      return null;
    }
  }

  /// Walks the org-role entity tables looking for a row whose
  /// `accountUserId` column points back to a real User account.
  ///
  /// `Team`, `Player` and `Coach` are guaranteed to have the column
  /// (see migrations 20260820084300 and 20260820084800). `League`,
  /// `Competition` and `Community` may or may not have it depending on
  /// claim-workflow state — we attempt the lookup defensively and skip
  /// any table that rejects the query.
  Future<String?> _resolveEntityAccount(String raw, String slugDash) async {
    const tables = <String>[
      'Team',
      'Player',
      'Coach',
      'League',
      'Competition',
      'Community',
    ];

    for (final table in tables) {
      try {
        // Try the dash-form slug first (entity_taxonomy uses dashes).
        final bySlugDash = await _sb
            .from(table)
            .select('accountUserId')
            .eq('slug', slugDash)
            .maybeSingle();
        final id1 = bySlugDash?['accountUserId']?.toString();
        if (id1 != null && id1.isNotEmpty) return id1;

        // Then the underscore-form slug (User-handle convention).
        final bySlugUnder = await _sb
            .from(table)
            .select('accountUserId')
            .eq('slug', raw)
            .maybeSingle();
        final id2 = bySlugUnder?['accountUserId']?.toString();
        if (id2 != null && id2.isNotEmpty) return id2;

        // Then a case-insensitive slug match.
        final bySlugIlike = await _sb
            .from(table)
            .select('accountUserId')
            .ilike('slug', raw)
            .maybeSingle();
        final id3 = bySlugIlike?['accountUserId']?.toString();
        if (id3 != null && id3.isNotEmpty) return id3;
      } catch (e) {
        // Schema drift between entity tables is expected — keep walking.
        debugPrint('_resolveEntityAccount($table) error: $e');
      }
    }
    return null;
  }

  /// Get followers of a user
  Future<List<GraphPerson>> followers(String userId) async {
    final id = await _resolve(userId);
    if (id == null) return [];
    final rows = await _sb
        .from('Follow')
        .select('followerId')
        .eq('followingId', id);
    final ids = [for (final r in rows as List) (r as Map)['followerId']?.toString()];
    return _people(ids);
  }

  /// Get users that a user is following
  Future<List<GraphPerson>> following(String userId) async {
    final id = await _resolve(userId);
    if (id == null) return [];
    final rows = await _sb
        .from('Follow')
        .select('followingId')
        .eq('followerId', id);
    final ids = [for (final r in rows as List) (r as Map)['followingId']?.toString()];
    return _people(ids);
  }

  /// Get fans of a user
  Future<List<GraphPerson>> fans(String userId) async {
    final id = await _resolve(userId);
    if (id == null) return [];
    final rows = await _sb
        .from('fans')
        .select('fan_id')
        .eq('target_id', id);
    final ids = [for (final r in rows as List) (r as Map)['fan_id']?.toString()];
    return _people(ids);
  }

  /// Fetch people by IDs with follow/fan status
  Future<List<GraphPerson>> _people(List<String?> ids) async {
    try {
      final clean = ids.whereType<String>().toSet().toList();
      if (clean.isEmpty) return [];

      // Fetch user details
      final rows = await _sb
          .from('User')
          .select('id,handle,name,avatarUrl,role')
          .inFilter('id', clean);

      final me = _uid;
      var followed = <String>{};
      var fanned = <String>{};

      // Only fetch relationships if logged in
      if (me != null) {
        // Batch fetch follows
        final followRows = await _sb
            .from('Follow')
            .select('followingId')
            .eq('followerId', me)
            .inFilter('followingId', clean);
        followed = {
          for (final r in followRows as List)
            (r as Map)['followingId'].toString()
        };

        // Batch fetch fans
        final fanRows = await _sb
            .from('fans')
            .select('target_id')
            .eq('fan_id', me)
            .inFilter('target_id', clean);
        fanned = {
          for (final r in fanRows as List)
            (r as Map)['target_id'].toString()
        };
      }

      return [
        for (final r in rows as List)
          GraphPerson(
            id: (r as Map)['id'].toString(),
            handle: r['handle']?.toString() ?? '',
            name: r['name']?.toString() ?? r['handle']?.toString() ?? '',
            avatarUrl: r['avatarUrl'] as String?,
            role: r['role']?.toString() ?? 'fan',
            youFollow: followed.contains(r['id'].toString()),
            youFan: fanned.contains(r['id'].toString()),
          )
      ];
    } catch (e) {
      debugPrint('Error fetching people: $e');
      return [];
    }
  }

  /// Check if a role can be fanned
  bool canFan(String role) {
    const ok = {'team', 'player', 'coach', 'academy'};
    return ok.contains(role.toLowerCase());
  }

  /// Follow or unfollow a target
  Future<void> follow(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to follow');
    if (targetId == uid) {
      throw StateError('You cannot follow yourself');
    }

    try {
      if (on) {
        await _sb.from('Follow').upsert({
          'followerId': uid,
          'followingId': targetId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _sb
            .from('Follow')
            .delete()
            .eq('followerId', uid)
            .eq('followingId', targetId);
      }

      // Refresh counts for both users.
      await refreshCounts(targetId);
      await refreshCounts(uid);
    } catch (e) {
      debugPrint('Failed to ${on ? 'follow' : 'unfollow'}: $e');
      rethrow;
    }
  }

  /// Unfollow a target user.
  ///
  /// Convenience wrapper around `follow(targetId, on: false)` so callers
  /// don't need to thread a boolean for the common "stop following" path.
  Future<void> unfollow(String targetId) => follow(targetId, on: false);

  /// Fan or unfan a target
  Future<void> fan(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to fan');
    if (targetId == uid) {
      throw StateError('You cannot fan yourself');
    }
    if (targetId.isEmpty) {
      throw StateError('Cannot fan — target id is empty');
    }

    try {
      // PART D: fans table is the canonical user→team fan relationship.
      // target_id is the team's accountUserId (a User/profile id), NOT a
      // Team.id. The previous code had a broken fallback that inserted a row
      // with a non-existent `id` column into the Follow table — that path
      // always failed silently and hid the real error (wrong target id, RLS
      // denial, or missing accountUserId on the team). Removed.
      if (on) {
        await _sb.from('fans').upsert({
          'fan_id': uid,
          'target_id': targetId,
        });
      } else {
        await _sb.from('fans').delete()
            .eq('fan_id', uid).eq('target_id', targetId);
      }

      await refreshCounts(targetId);
      await refreshCounts(uid);
    } catch (e) {
      debugPrint('Failed to ${on ? 'fan' : 'unfan'}: $e');
      rethrow;
    }
  }

  /// Unfan a target.
  ///
  /// Convenience wrapper around `fan(targetId, on: false)` so callers
  /// don't need to thread a boolean for the common "stop fanning" path.
  Future<void> unfan(String targetId) => fan(targetId, on: false);
}
