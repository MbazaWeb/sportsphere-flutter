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
    final ref = 'SS-${id.substring(4)}';
    await _sb.from('ShopOrder').insert({
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
      'createdAt': DateTime.now().toIso8601String(),
    });
    // Optional metadata table-free: store method in itemName suffix if columns missing
    try {
      await _sb.from('ShopOrder').update({
        'status': status,
      }).eq('id', id);
    } catch (e) {
      debugPrint('order meta: $e');
    }
    return id;
  }

  Future<void> confirmOrderPaid(String orderId, {String? providerRef}) async {
    await _sb.from('ShopOrder').update({
      'status': 'paid',
      if (providerRef != null) 'paymentRef': providerRef,
    }).eq('id', orderId);
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

  Future<void> joinCommunity(String communityId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to join');
    await _sb.from('CommunityMember').upsert({
      'communityId': communityId,
      'userId': uid,
      'role': 'member',
      'joinedAt': DateTime.now().toIso8601String(),
    });
    try {
      final row = await _sb
          .from('Community')
          .select('memberCount')
          .eq('id', communityId)
          .maybeSingle();
      final n = ((row?['memberCount'] as int?) ?? 0) + 1;
      await _sb.from('Community').update({'memberCount': n}).eq('id', communityId);
    } catch (_) {}
  }

  Future<void> leaveCommunity(String communityId) async {
    final uid = _uid;
    if (uid == null) return;
    await _sb
        .from('CommunityMember')
        .delete()
        .eq('communityId', communityId)
        .eq('userId', uid);
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
}
