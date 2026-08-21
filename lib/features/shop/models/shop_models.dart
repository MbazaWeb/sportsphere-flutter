import 'package:flutter/material.dart';

enum ShopItemKind { merch, ticket, membership, donation }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.priceTzs,
    required this.kind,
    this.icon = Icons.shopping_bag_outlined,
    this.accent,
    this.badge,
  });

  final String id;
  final String name;
  final String subtitle;
  final int priceTzs;
  final ShopItemKind kind;
  final IconData icon;
  final Color? accent;
  final String? badge;

  String get formattedPrice {
    if (kind == ShopItemKind.donation && priceTzs == 0) return 'Any amount';
    final s = priceTzs.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return 'TZS $buf';
  }
}

class CartLine {
  const CartLine({required this.item, this.qty = 1, this.customAmount});
  final ShopItem item;
  final int qty;
  final int? customAmount;
  int get lineTotal => (customAmount ?? item.priceTzs) * qty;
}

class ShopCatalog {
  const ShopCatalog({
    required this.sellerName,
    required this.sellerHandle,
    required this.accent,
    this.merch = const [],
    this.tickets = const [],
    this.memberships = const [],
    this.donations = const [],
  });

  final String sellerName;
  final String sellerHandle;
  final Color accent;
  final List<ShopItem> merch;
  final List<ShopItem> tickets;
  final List<ShopItem> memberships;
  final List<ShopItem> donations;

  bool get isEmpty =>
      merch.isEmpty && tickets.isEmpty && memberships.isEmpty && donations.isEmpty;
}

// ── Catalog builders ───────────────────────────────────────────────────────
// Shop items are created by team/business admins via the admin panel.
// These functions return empty catalogs until admin populates the DB.

ShopCatalog emptyShopCatalog({
  required String sellerName,
  required String sellerHandle,
  required Color accent,
}) =>
    ShopCatalog(
      sellerName: sellerName,
      sellerHandle: sellerHandle,
      accent: accent,
      merch: const [],
      tickets: const [],
      memberships: const [],
      donations: const [],
    );

// Keep these as aliases so existing call sites compile without changes.
ShopCatalog simbaShopCatalog() => emptyShopCatalog(
      sellerName: 'Simba SC',
      sellerHandle: 'simbasc',
      accent: const Color(0xFFE31B23),
    );

ShopCatalog teamShopCatalog({
  required String name,
  required String handle,
  required Color accent,
}) =>
    emptyShopCatalog(
      sellerName: name,
      sellerHandle: handle,
      accent: accent,
    );

ShopCatalog businessShopCatalog({
  required String name,
  required String handle,
  required Color accent,
}) =>
    emptyShopCatalog(
      sellerName: name,
      sellerHandle: handle,
      accent: accent,
    );

ShopCatalog marketplaceCatalog() => emptyShopCatalog(
      sellerName: 'SportSphere Marketplace',
      sellerHandle: 'marketplace',
      accent: const Color(0xFF009DFF),
    );
