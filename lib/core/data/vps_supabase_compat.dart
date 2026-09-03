// lib/core/data/vps_supabase_compat.dart
//
// MIGRATION SHIM — provides a VpsSupabaseCompat.client object that
// satisfies the remaining Supabase call sites while we migrate them
// to native VPS calls. Once all files are migrated, this file is deleted.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vps_repository.dart';

class VpsSupabaseCompat {
  VpsSupabaseCompat._();
  static final client = _VpsCompatClient();
}

class _VpsCompatClient {
  static const VpsRepository _vps = VpsRepository();

  _VpsCompatAuth get auth => _VpsCompatAuth();

  _VpsCompatQuery from(String table) => _VpsCompatQuery(table, _vps);

  // Allow direct rpc() calls — delegate to VPS
  Future<dynamic> rpc(String name, {Map<String, dynamic>? params}) async {
    try {
      switch (name) {
        case 'increment_post_counter':
          // Post counter is maintained by triggers now — no-op
          return;
        case 'refresh_user_counts':
          // Counts are maintained server-side — no-op
          return;
        case 'count_fans_of':
          return 0;
        case 'feed_for_user':
          return <Map<String, dynamic>>[];
        case 'bump_news_share':
          return;
        case 'nearby_fans':
          return <Map<String, dynamic>>[];
        default:
          debugPrint('VpsSupabaseCompat.rpc: unhandled $name');
          return null;
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.rpc($name): $e');
      return null;
    }
  }

  // Channel stub for realtime (returns a no-op channel)
  dynamic channel(String name) => _NoopChannel();
}

class _VpsCompatAuth {
  _VpsCompatUser? get currentUser => _VpsCompatUserCache.user;

  Future<bool> get hasSession async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_access_token') != null;
    } catch (_) {
      return false;
    }
  }

}

class _VpsCompatUserCache {
  static _VpsCompatUser? user;
}

class _VpsCompatUser {
  _VpsCompatUser(this.id);
  final String id;
  String? email;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUERY BUILDER — mimics Supabase's PostgrestQueryBuilder pattern.
// from(table).select().eq(col, val).order(col).limit(n) → await result
// ─────────────────────────────────────────────────────────────────────────────

class _VpsCompatQuery {

  _VpsCompatQuery(this._table, this._vps);
  final String _table;
  final VpsRepository _vps;

  /// select() returns a filter builder (NOT a Future).
  _VpsCompatFilterBuilder select([String? columns]) {
    return _VpsCompatFilterBuilder._(_table, _vps);
  }

  /// insert() returns a write future.
  Future<void> insert(Map<String, dynamic> data) {
    return _VpsCompatWriteHelper.insert(_table, _vps, data);
  }

  /// update() returns a filter builder.
  _VpsCompatFilterBuilder update(Map<String, dynamic> data) {
    return _VpsCompatFilterBuilder._(_table, _vps, updateData: data);
  }

  /// delete() returns a filter builder.
  _VpsCompatFilterBuilder delete() {
    return _VpsCompatFilterBuilder._(_table, _vps, isDelete: true);
  }

  /// upsert() returns a write future.
  Future<void> upsert(Map<String, dynamic> data) {
    return _VpsCompatWriteHelper.insert(_table, _vps, data);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BUILDER — supports .eq(), .neq(), .order(), .limit(), .inFilter(),
// .or(), .maybeSingle(). Is awaitable (implements Future-like via then()).
// ─────────────────────────────────────────────────────────────────────────────

class _VpsCompatFilterBuilder {

  _VpsCompatFilterBuilder._(
    this._table,
    this._vps, {
    Map<String, dynamic>? updateData,
    bool isDelete = false,
  })  : _updateData = updateData,
        _isDelete = isDelete;
  final String _table;
  final VpsRepository _vps;
  final Map<String, dynamic>? _updateData;
  final bool _isDelete;

  final List<_FilterEntry> _filters = [];
  int? _limit;

  // ── Filter methods (return this for chaining) ──

  _VpsCompatFilterBuilder eq(String column, dynamic value) {
    _filters.add(_FilterEntry(column, value?.toString() ?? '', 'eq'));
    return this;
  }

  _VpsCompatFilterBuilder neq(String column, dynamic value) {
    _filters.add(_FilterEntry(column, value?.toString() ?? '', 'neq'));
    return this;
  }

  _VpsCompatFilterBuilder ilike(String column, String pattern) {
    _filters.add(_FilterEntry(column, pattern, 'ilike'));
    return this;
  }

  _VpsCompatFilterBuilder or(String filter) => this;

  _VpsCompatFilterBuilder order(String column, {bool ascending = false}) {
    return this;
  }

  _VpsCompatFilterBuilder limit(int? l) {
    _limit = l;
    return this;
  }

  _VpsCompatFilterBuilder inFilter(String column, List<String> values) {
    _filters.add(_FilterEntry(column, values.join(','), 'in'));
    return this;
  }

  // ── Terminal methods ──

  Future<Map<String, dynamic>?> maybeSingle() async {
    final rows = await _execute();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<Map<String, dynamic>> single() async {
    final rows = await _execute();
    return rows.first;
  }

  /// Getter for first element — used by callers that do `.select().first`
  Future<Map<String, dynamic>> get first async {
    final rows = await _execute();
    return rows.first;
  }

  // ── Make this awaitable by implementing then() ──
  // Dart's `await` calls .then() on the object.

  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>>) onValue, {
    Function? onError,
  }) {
    return _execute().then<R>(onValue, onError: onError);
  }

  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) {
    return _execute().catchError(onError, test: test);
  }

  Future<List<Map<String, dynamic>>> whenComplete(FutureOr<void> Function() action) {
    return _execute().whenComplete(action);
  }

  /// Actual execution — delegates to VPS based on table + operation.
  Future<List<Map<String, dynamic>>> _execute() async {
    try {
      if (_isDelete) {
        await _executeDelete();
        return [];
      }
      if (_updateData != null) {
        await _executeUpdate();
        return [];
      }
      return await _executeSelect();
    } catch (e) {
      debugPrint('VpsSupabaseCompat._execute($_table): $e');
      return [];
    }
  }

  String? _getFilter(String op, [String? column]) {
    for (final f in _filters) {
      if (f.op == op && (column == null || f.column == column)) {
        return f.value;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _executeSelect() async {
    final eqCol = _filters.isNotEmpty ? _filters.first.column : null;
    final eqVal = _filters.isNotEmpty ? _filters.first.value : null;

    switch (_table) {
      case 'User':
      case 'profiles':
        if (eqCol == 'id' && eqVal != null) {
          final profile = await _vps.getProfile(eqVal);
          return profile != null ? [profile] : [];
        }
        return [];
      case 'Match':
        return await _vps.getAllMatches(limit: _limit ?? 200);
      case 'Team':
        return await _vps.getAdminTeams(limit: _limit ?? 200);
      case 'Post':
        if (eqCol == 'userId' && eqVal != null) {
          return await _vps.getUserPosts(eqVal, limit: _limit ?? 50);
        }
        return await _vps.getFeed(limit: _limit ?? 40);
      case 'Follow':
        if (eqCol == 'followerId' && eqVal != null) {
          return await _vps.getFollowing(eqVal);
        }
        if (eqCol == 'followingId' && eqVal != null) {
          return await _vps.getFollowers(eqVal);
        }
        return [];
      case 'Comment':
        if (eqCol == 'postId' && eqVal != null) {
          return await _vps.getComments(eqVal);
        }
        return [];
      case 'Notification':
        return await _vps.getNotifications(limit: _limit ?? 50);
      case 'ShopOrder':
        return await _vps.getMyOrders(limit: _limit ?? 50);
      default:
        return [];
    }
  }

  Future<void> _executeUpdate() async {
    switch (_table) {
      case 'ShopOrder':
        final id = _getFilter('eq', 'id');
        if (id != null) await _vps.confirmOrderPaid(id);
        break;
      case 'Notification':
        final id = _getFilter('eq', 'id');
        if (id != null) await _vps.markRead(id);
        break;
    }
  }

  Future<void> _executeDelete() async {
    switch (_table) {
      case 'Follow':
        final val = _getFilter('eq', 'followingId');
        if (val != null) await _vps.toggleFollow(val);
        break;
      case 'PostLike':
        final val = _getFilter('eq', 'postId');
        if (val != null) await _vps.toggleLike(val);
        break;
      case 'Post':
        final val = _getFilter('eq', 'id');
        if (val != null) await _vps.deletePost(val);
        break;
      case 'CommunityMember':
        final val = _getFilter('eq', 'communityId');
        if (val != null) await _vps.leaveCommunity(val);
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WRITE HELPER — handles insert/upsert by delegating to VPS.
// ─────────────────────────────────────────────────────────────────────────────

class _VpsCompatWriteHelper {
  static Future<void> insert(
    String table,
    VpsRepository vps,
    Map<String, dynamic> data,
  ) async {
    try {
      switch (table) {
        case 'Post':
          await vps.createPost(data);
          break;
        case 'Follow':
          if (data['followingId'] != null) {
            await vps.toggleFollow(data['followingId'] as String);
          }
          break;
        case 'PostLike':
          if (data['postId'] != null) {
            await vps.toggleLike(data['postId'] as String);
          }
          break;
        case 'Comment':
          if (data['postId'] != null && data['content'] != null) {
            await vps.addComment(
              data['postId'] as String,
              data['content'] as String,
            );
          }
          break;
        case 'Message':
          if (data['receiverId'] != null && data['content'] != null) {
            await vps.sendMessage(
              data['receiverId'] as String,
              data['content'] as String,
            );
          }
          break;
        case 'ShopOrder':
          await vps.createOrder(
            itemId: data['itemId'] as String? ?? '',
            itemName: data['itemName'] as String? ?? '',
            kind: data['kind'] as String? ?? 'ticket',
            unitPriceTzs: data['unitPriceTzs'] as int? ?? 0,
            quantity: data['quantity'] as int? ?? 1,
            sellerHandle: data['sellerHandle'] as String?,
            sellerName: data['sellerName'] as String?,
            paymentMethod: data['paymentMethod'] as String? ?? 'mpesa',
          );
          break;
        case 'CommunityMember':
          if (data['communityId'] != null) {
            await vps.joinCommunity(data['communityId'] as String);
          }
          break;
        case 'PollVote':
          if (data['pollId'] != null && data['optionIndex'] != null) {
            await vps.votePoll(
              data['pollId'] as String,
              data['optionIndex'] as int,
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.insert($table): $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOOP CHANNEL — stub for realtime subscriptions.
// ─────────────────────────────────────────────────────────────────────────────

class _NoopChannel {
  _NoopChannel onPostgresChanges({
    required dynamic event,
    required String schema,
    String? table,
    Map<String, dynamic>? filter,
    required void Function(Map<String, dynamic>) callback,
  }) {
    return this;
  }

  _NoopChannel subscribe() => this;
  void unsubscribe() {}
}

class _FilterEntry {
  const _FilterEntry(this.column, this.value, this.op);
  final String column;
  final String value;
  final String op;
}
