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

ShopCatalog simbaShopCatalog() => const ShopCatalog(
      sellerName: 'Simba SC',
      sellerHandle: 'simbasc',
      accent: Color(0xFFE31B23),
      merch: [
        ShopItem(id: 'kit-home', name: 'Home Kit 25/26', subtitle: 'Official replica jersey', priceTzs: 65000, kind: ShopItemKind.merch, icon: Icons.checkroom_rounded, badge: 'New'),
        ShopItem(id: 'kit-away', name: 'Away Kit 25/26', subtitle: 'Official replica jersey', priceTzs: 65000, kind: ShopItemKind.merch, icon: Icons.checkroom_outlined),
        ShopItem(id: 'scarf', name: 'Club Scarf', subtitle: 'Red & white knit', priceTzs: 18000, kind: ShopItemKind.merch, icon: Icons.volunteer_activism_outlined),
        ShopItem(id: 'cap', name: 'Training Cap', subtitle: 'Adjustable', priceTzs: 15000, kind: ShopItemKind.merch, icon: Icons.sports_outlined),
      ],
      tickets: [
        ShopItem(id: 'tix-league', name: 'League Match Ticket', subtitle: 'Simba vs Yanga · Mkapa Stadium', priceTzs: 10000, kind: ShopItemKind.ticket, icon: Icons.confirmation_number_rounded, badge: 'Matchday'),
        ShopItem(id: 'tix-vip', name: 'VIP Box Seat', subtitle: 'Includes hospitality', priceTzs: 85000, kind: ShopItemKind.ticket, icon: Icons.event_seat_rounded),
      ],
      memberships: [
        ShopItem(id: 'mem-fan', name: 'Official Fan Membership', subtitle: 'Season 25/26 · voting + discount', priceTzs: 25000, kind: ShopItemKind.membership, icon: Icons.card_membership_rounded, badge: 'Season'),
        ShopItem(id: 'mem-gold', name: 'Gold Supporter', subtitle: 'Priority tickets + kit discount', priceTzs: 120000, kind: ShopItemKind.membership, icon: Icons.workspace_premium_rounded),
      ],
      donations: [
        ShopItem(id: 'donate-academy', name: 'Academy Fund', subtitle: 'Youth development', priceTzs: 10000, kind: ShopItemKind.donation, icon: Icons.favorite_rounded),
        ShopItem(id: 'donate-any', name: 'Club Donation', subtitle: 'Choose any amount', priceTzs: 0, kind: ShopItemKind.donation, icon: Icons.volunteer_activism_rounded),
      ],
    );

ShopCatalog businessShopCatalog({
  required String name,
  required String handle,
  required Color accent,
}) =>
    ShopCatalog(
      sellerName: name,
      sellerHandle: handle,
      accent: accent,
      merch: [
        ShopItem(id: 'svc-consult', name: 'Brand Partnership Pack', subtitle: 'Activation + social kit', priceTzs: 450000, kind: ShopItemKind.merch, icon: Icons.handshake_rounded),
        ShopItem(id: 'svc-kit', name: 'Kit Sponsorship Slot', subtitle: 'Sleeve or training wear', priceTzs: 2500000, kind: ShopItemKind.merch, icon: Icons.sell_rounded, badge: 'B2B'),
      ],
      tickets: const [
        ShopItem(id: 'tix-event', name: 'Hospitality Ticket', subtitle: 'Corporate box · next home match', priceTzs: 95000, kind: ShopItemKind.ticket, icon: Icons.confirmation_number_rounded),
      ],
      memberships: const [
        ShopItem(id: 'mem-partner', name: 'Partner Membership', subtitle: 'Annual commercial access', priceTzs: 350000, kind: ShopItemKind.membership, icon: Icons.card_membership_rounded),
      ],
      donations: const [
        ShopItem(id: 'donate-csr', name: 'Community CSR Fund', subtitle: 'Grassroots programmes', priceTzs: 20000, kind: ShopItemKind.donation, icon: Icons.favorite_rounded),
      ],
    );
