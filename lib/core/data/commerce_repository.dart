// lib/core/data/commerce_repository.dart
// All commerce operations via VPS API — no Supabase dependency.

import 'package:flutter/foundation.dart';

import 'vps_repository.dart';

class CommerceRepository {
  CommerceRepository() : _vps = const VpsRepository();

  final VpsRepository _vps;

  // ── Place order ────────────────────────────────────────────────────────────
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
    final res = await _vps.post<Map<String, dynamic>>(
      '/v1/shop/orders',
      data: {
        'itemId':        itemId,
        'itemName':      itemName,
        'kind':          kind,
        'unitPriceTzs':  unitPriceTzs,
        'quantity':      quantity,
        if (sellerHandle != null) 'sellerHandle': sellerHandle,
        if (sellerName   != null) 'sellerName':   sellerName,
        'paymentMethod': paymentMethod,
      },
    );
    return res.data?['orderId'] as String? ?? '';
  }

  // ── Confirm order paid ─────────────────────────────────────────────────────
  Future<void> confirmOrderPaid(String orderId, {String? providerRef}) async {
    await _vps.patch<void>(
      '/v1/shop/orders/$orderId/confirm',
      data: {'providerRef': providerRef},
    );
  }

  // ── M-Pesa STK Push ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> initiateMpesaStk({
    required String orderId,
    required String phone,
    required int amountTzs, // UI display only — server reads from DB
  }) async {
    return _vps.initiateMpesa(orderId: orderId, phone: phone);
  }

  // ── Order history ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> myOrders({int limit = 50}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/shop/orders/mine', query: {'limit': limit},
      );
      return ((res.data?['orders']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('myOrders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> sellerOrders({int limit = 50}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/shop/orders/seller', query: {'limit': limit},
      );
      return ((res.data?['orders']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('sellerOrders: $e');
      return [];
    }
  }

  // ── Seller ticket stats ────────────────────────────────────────────────────
  Future<Map<String, int>> sellerTicketStats(String sellerHandle) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/shop/tickets/$sellerHandle/stats',
      );
      return {
        'sold':      res.data?['sold']      as int? ?? 0,
        'amountTzs': res.data?['amountTzs'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('sellerTicketStats: $e');
      return {'sold': 0, 'amountTzs': 0};
    }
  }

  // ── Community membership ───────────────────────────────────────────────────
  Future<void> joinCommunity(String communityId) async {
    await _vps.post<void>('/v1/social/communities/$communityId/join');
  }

  Future<void> leaveCommunity(String communityId) async {
    await _vps.delete<void>('/v1/social/communities/$communityId/leave');
  }

  Future<bool> isMember(String communityId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/communities/$communityId/member',
      );
      return res.data?['isMember'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Player match stats ─────────────────────────────────────────────────────
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
    await _vps.post<void>('/v1/admin/players/$playerId/stats', data: {
      if (matchId     != null) 'matchId':     matchId,
      'season':       season,
      if (competition != null) 'competition': competition,
      'minutes':      minutes,
      'goals':        goals,
      'assists':      assists,
      'saves':        saves,
      'yellowCards':  yellowCards,
      'redCards':     redCards,
    });
  }

  Future<Map<String, int>> aggregatePlayerStats(String playerId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/players/$playerId/stats',
      );
      final d = res.data ?? {};
      return {
        'played':      d['played']      as int? ?? 0,
        'goals':       d['goals']       as int? ?? 0,
        'assists':     d['assists']     as int? ?? 0,
        'saves':       d['saves']       as int? ?? 0,
        'minutes':     d['minutes']     as int? ?? 0,
        'yellowCards': d['yellowCards'] as int? ?? 0,
        'redCards':    d['redCards']    as int? ?? 0,
      };
    } catch (e) {
      debugPrint('aggregatePlayerStats: $e');
      return {'played': 0, 'goals': 0, 'assists': 0, 'saves': 0,
              'minutes': 0, 'yellowCards': 0, 'redCards': 0};
    }
  }
}
