// lib/core/data/vps_supabase_compat.dart
//
// MIGRATION SHIM — provides a VpsSupabaseCompat.client object that
// satisfies the remaining Supabase call sites while we migrate them
// to native VPS calls. Once all files are migrated, this file is deleted.
//
// This shim keeps the app compiling during the migration.
// It delegates DB reads to VPS /v1/* endpoints and has NO Supabase dependency.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vps_repository.dart';

class VpsSupabaseCompat {
  VpsSupabaseCompat._();
  static final client = _VpsCompatClient();
}

class _VpsCompatClient {
  static final VpsRepository _vps = const VpsRepository();

  _VpsCompatAuth get auth => _VpsCompatAuth();

  _VpsCompatQuery from(String table) => _VpsCompatQuery(table, _vps);
}

class _VpsCompatAuth {
  /// Read the stored JWT from SharedPreferences (set by AuthRepository.login).
  Future<String?> _token() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_access_token');
    } catch (e) {
      debugPrint('VpsSupabaseCompat._token: $e');
      return null;
    }
  }

  /// Check if a session token exists.
  Future<bool> get hasSession async => (await _token()) != null;

  /// Return a minimal user object parsed from the stored JWT payload.
  /// The JWT payload is set by AuthRepository.login() as 'auth_user_id'.
  _VpsCompatUser? get currentUser {
    // Synchronous read from static cache (populated by _loadUserSync)
    return _VpsCompatUserCache.user;
  }

  /// Async refresh of the cached user (call after login).
  static Future<void> refreshUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('auth_user_id');
      if (uid != null && uid.isNotEmpty) {
        _VpsCompatUserCache.user = _VpsCompatUser(uid);
      } else {
        _VpsCompatUserCache.user = null;
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.refreshUser: $e');
    }
  }
}

/// Static cache so auth.currentUser can return synchronously.
class _VpsCompatUserCache {
  static _VpsCompatUser? user;
}

class _VpsCompatUser {
  final String id;
  const _VpsCompatUser(this.id);
}

/// Minimal query builder that delegates common patterns to VPS endpoints.
/// Supports: .select(), .eq(), .order(), .limit(), .maybeSingle(), .insert(),
/// .update(), .delete(), .upsert(), .inFilter(), .or()
class _VpsCompatQuery {
  final String _table;
  final VpsRepository _vps;
  String? _eqColumn;
  String? _eqValue;
  String? _orderColumn;
  bool _ascending = false;
  int? _limit;

  _VpsCompatQuery(this._table, this._vps);

  _VpsCompatQuery eq(String column, String value) {
    _eqColumn = column;
    _eqValue = value;
    return this;
  }

  _VpsCompatQuery neq(String column, String value) {
    _eqColumn = column;
    _eqValue = null; // neq not directly supported; treat as no filter
    return this;
  }

  _VpsCompatQuery order(String column, {bool ascending = false}) {
    _orderColumn = column;
    _ascending = ascending;
    return this;
  }

  _VpsCompatQuery limit(int? l) {
    _limit = l;
    return this;
  }

  _VpsCompatQuery inFilter(String column, List<String> values) {
    _eqColumn = column;
    _eqValue = values.join(',');
    return this;
  }

  _VpsCompatQuery or(String filter) => this;

  Future<List<Map<String, dynamic>>> select([String? columns]) async {
    try {
      // Delegate to VPS based on table name
      switch (_table) {
        case 'User':
        case 'profiles':
          if (_eqColumn == 'id' && _eqValue != null) {
            final profile = await _vps.getProfile(_eqValue!);
            return profile != null ? [profile] : [];
          }
          return [];
        case 'Match':
          return await _vps.getAllMatches(limit: _limit ?? 200);
        case 'Team':
          return await _vps.getAdminTeams(limit: _limit ?? 200);
        case 'Post':
          if (_eqColumn == 'userId' && _eqValue != null) {
            return await _vps.getUserPosts(_eqValue!, limit: _limit ?? 50);
          }
          return await _vps.getFeed(limit: _limit ?? 40);
        case 'Follow':
          if (_eqColumn == 'followerId') {
            return await _vps.getFollowing(_eqValue!);
          }
          if (_eqColumn == 'followingId') {
            return await _vps.getFollowers(_eqValue!);
          }
          return [];
        case 'Comment':
          if (_eqColumn == 'postId' && _eqValue != null) {
            return await _vps.getComments(_eqValue!);
          }
          return [];
        case 'Notification':
          return await _vps.getNotifications(limit: _limit ?? 50);
        case 'ShopOrder':
          return await _vps.getMyOrders(limit: _limit ?? 50);
        case 'CommunityMember':
          return [];
        default:
          debugPrint('VpsSupabaseCompat: unhandled table $_table');
          return [];
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.select($_table): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> get([String? columns]) => select(columns);

  Future<Map<String, dynamic>?> maybeSingle() async {
    final rows = await select();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> insert(Map<String, dynamic> data) async {
    try {
      switch (_table) {
        case 'Post':
          await _vps.createPost(data);
          break;
        case 'Follow':
          if (data['followingId'] != null) {
            await _vps.toggleFollow(data['followingId'] as String);
          }
          break;
        case 'PostLike':
          if (data['postId'] != null) {
            await _vps.toggleLike(data['postId'] as String);
          }
          break;
        case 'Comment':
          if (data['postId'] != null && data['content'] != null) {
            await _vps.addComment(
              data['postId'] as String,
              data['content'] as String,
            );
          }
          break;
        case 'Message':
          if (data['receiverId'] != null && data['content'] != null) {
            await _vps.sendMessage(
              data['receiverId'] as String,
              data['content'] as String,
            );
          }
          break;
        case 'ShopOrder':
          await _vps.createOrder(
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
            await _vps.joinCommunity(data['communityId'] as String);
          }
          break;
        case 'PollVote':
          if (data['pollId'] != null && data['optionIndex'] != null) {
            await _vps.votePoll(
              data['pollId'] as String,
              data['optionIndex'] as int,
            );
          }
          break;
        default:
          debugPrint('VpsSupabaseCompat.insert: unhandled table $_table');
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.insert($_table): $e');
    }
  }

  Future<void> update(Map<String, dynamic> data) async {
    try {
      switch (_table) {
        case 'ShopOrder':
          if (_eqColumn == 'id' && _eqValue != null) {
            await _vps.confirmOrderPaid(_eqValue!);
          }
          break;
        case 'Notification':
          // Mark as read
          if (_eqColumn == 'id' && _eqValue != null) {
            await _vps.markRead(_eqValue!);
          }
          break;
        default:
          debugPrint('VpsSupabaseCompat.update: unhandled table $_table');
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.update($_table): $e');
    }
  }

  Future<void> delete() async {
    try {
      switch (_table) {
        case 'Follow':
          if (_eqColumn == 'followingId' && _eqValue != null) {
            await _vps.toggleFollow(_eqValue!);
          }
          break;
        case 'PostLike':
          if (_eqColumn == 'postId' && _eqValue != null) {
            await _vps.toggleLike(_eqValue!);
          }
          break;
        case 'Post':
          if (_eqColumn == 'id' && _eqValue != null) {
            await _vps.deletePost(_eqValue!);
          }
          break;
        case 'CommunityMember':
          if (_eqColumn == 'communityId' && _eqValue != null) {
            await _vps.leaveCommunity(_eqValue!);
          }
          break;
        default:
          debugPrint('VpsSupabaseCompat.delete: unhandled table $_table');
      }
    } catch (e) {
      debugPrint('VpsSupabaseCompat.delete($_table): $e');
    }
  }

  Future<void> upsert(Map<String, dynamic> data) => insert(data);
}
