import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommerceRepository {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  Future<String> placeOrder({
    required String itemId,
    required String itemName,
    required String kind,
    required int unitPriceTzs,
    int quantity = 1,
    String? sellerHandle,
    String? sellerName,
    String paymentMethod = 'mpesa',
    String? phone,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to purchase');
    final id = 'ord-${DateTime.now().millisecondsSinceEpoch}';
    final amount = unitPriceTzs * quantity;
    // Real PSP (M-Pesa STK / card) plugs in here via Edge Function.
    // Until STK credentials are set, we record a payable order as pending_confirm.
    final status = paymentMethod == 'demo' ? 'paid' : 'pending_confirm';
    await _sb.from('ShopOrder').insert({
      'ref': 'SS-${id.substring(4)}',
      'id': id,
      'userId': uid,
      'sellerHandle': sellerHandle,
      'sellerName': sellerName,
      'itemId': itemId,
      'itemName': itemName,
      'kind': kind,
      'quantity': quantity,
      'unitPriceTzs': unitPriceTzs,
      'amountTzs': amount,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// Mark an order as paid.
  ///
  /// Delegates to the `confirm_order_paid` RPC, which verifies that the
  /// caller is the order's owner (or an admin) before flipping the status.
  /// Replaces the previous unconditional `update` that let any user mark
  /// any order paid (H3).
  Future<void> confirmOrderPaid(String orderId, {String? providerRef}) async {
    try {
      await _sb.rpc('confirm_order_paid', params: {
        'p_order_id': orderId,
        'p_provider_ref': providerRef,
      });
    } catch (e) {
      debugPrint('confirmOrderPaid($orderId) RPC failed: $e');
      rethrow;
    }
  }

  /// Calls Edge Function mpesa-stk-push (Daraja STK).
  Future<Map<String, dynamic>> initiateMpesaStk({
    required String orderId,
    required String phone,
    required int amountTzs,
  }) async {
    final res = await _sb.functions.invoke(
      'mpesa-stk-push',
      body: {
        'order_id': orderId,
        'phone': phone,
        'amount': amountTzs,
      },
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'raw': data};
  }

  Future<Map<String, int>> sellerTicketStats(String sellerHandle) async {
    final rows = await _sb
        .from('ShopOrder')
        .select('quantity,amountTzs,kind')
        .eq('sellerHandle', sellerHandle)
        .eq('kind', 'ticket');
    var sold = 0;
    var amount = 0;
    for (final r in rows as List) {
      final m = Map<String, dynamic>.from(r as Map);
      sold += (m['quantity'] as int?) ?? 0;
      amount += (m['amountTzs'] as int?) ?? 0;
    }
    return {'sold': sold, 'amountTzs': amount};
  }

  /// Join a community.
  ///
  /// Atomic: delegates to the `join_community_atomic` RPC, which inserts the
  /// `CommunityMember` row and increments `Community.memberCount` in a single
  /// SQL transaction. Replaces the previous read-then-write pattern that lost
  /// updates under concurrent joins (H2).
  Future<void> joinCommunity(String communityId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to join');
    try {
      await _sb.rpc('join_community_atomic', params: {
        'p_community_id': communityId,
        'p_user_id': uid,
      });
    } catch (e) {
      debugPrint('joinCommunity($communityId) RPC failed: $e');
      rethrow;
    }
  }

  /// Leave a community.
  ///
  /// Atomic: delegates to the `leave_community_atomic` RPC, which deletes the
  /// `CommunityMember` row and decrements `Community.memberCount` in a single
  /// SQL transaction. Replaces the previous delete-only path that left
  /// `memberCount` stale (H8).
  Future<void> leaveCommunity(String communityId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _sb.rpc('leave_community_atomic', params: {
        'p_community_id': communityId,
        'p_user_id': uid,
      });
    } catch (e) {
      debugPrint('leaveCommunity($communityId) RPC failed: $e');
      rethrow;
    }
  }

  Future<bool> isMember(String communityId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _sb
        .from('CommunityMember')
        .select()
        .eq('communityId', communityId)
        .eq('userId', uid)
        .maybeSingle();
    return row != null;
  }

  /// Admin: upsert player match line.
  Future<void> upsertPlayerMatchStat({
    required String playerId,
    String? matchId,
    String season = '2026/2027',
    String? competition,
    int minutes = 0,
    int goals = 0,
    int assists = 0,
    int saves = 0,
    int yellowCards = 0,
    int redCards = 0,
  }) async {
    final id = matchId != null
        ? 'pms-$playerId-$matchId'
        : 'pms-$playerId-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('PlayerMatchStat').upsert({
      'id': id,
      'playerId': playerId,
      'matchId': matchId,
      'season': season,
      'competition': competition,
      'played': true,
      'minutes': minutes,
      'goals': goals,
      'assists': assists,
      'saves': saves,
      'yellowCards': yellowCards,
      'redCards': redCards,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, int>> aggregatePlayerStats(String playerId) async {
    final rows =
        await _sb.from('PlayerMatchStat').select().eq('playerId', playerId);
    var played = 0, goals = 0, assists = 0, saves = 0, minutes = 0, y = 0, r = 0;
    for (final raw in rows as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['played'] == true) played++;
      goals += (m['goals'] as int?) ?? 0;
      assists += (m['assists'] as int?) ?? 0;
      saves += (m['saves'] as int?) ?? 0;
      minutes += (m['minutes'] as int?) ?? 0;
      y += (m['yellowCards'] as int?) ?? 0;
      r += (m['redCards'] as int?) ?? 0;
    }
    return {
      'played': played,
      'goals': goals,
      'assists': assists,
      'saves': saves,
      'minutes': minutes,
      'yellowCards': y,
      'redCards': r,
    };
  }

  // ─── Order History ──────────────────────────────────────

  /// Buyer's order history
  Future<List<Map<String, dynamic>>> myOrders({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _sb
          .from('ShopOrder')
          .select()
          .eq('userId', uid)
          .order('createdAt', ascending: false)
          .limit(limit);
      return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
    } catch (e) {
      debugPrint('myOrders: $e');
      return [];
    }
  }

  /// Seller's received orders
  Future<List<Map<String, dynamic>>> sellerOrders({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      // Find seller handle from User table
      final user = await _sb
          .from('User')
          .select('handle')
          .eq('id', uid)
          .maybeSingle();
      final handle = user?['handle'] as String?;
      if (handle == null || handle.isEmpty) return [];
      final rows = await _sb
          .from('ShopOrder')
          .select()
          .eq('sellerHandle', handle)
          .order('createdAt', ascending: false)
          .limit(limit);
      return [for (final r in rows as List) Map<String, dynamic>.from(r as Map)];
    } catch (e) {
      debugPrint('sellerOrders: $e');
      return [];
    }
  }
}
