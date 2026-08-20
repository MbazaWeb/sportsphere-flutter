import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../models/shop_models.dart';
import 'checkout_flow.dart';

class ShopTab extends StatelessWidget {
  final ShopCatalog catalog;
  const ShopTab({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return const Center(
        child: Text('Shop coming soon', style: TextStyle(color: SportSphereColors.muted)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (catalog.tickets.isNotEmpty)
          _Section(title: 'Tickets', icon: Icons.confirmation_number_rounded, items: catalog.tickets, catalog: catalog),
        if (catalog.memberships.isNotEmpty)
          _Section(title: 'Membership', icon: Icons.card_membership_rounded, items: catalog.memberships, catalog: catalog),
        if (catalog.merch.isNotEmpty)
          _Section(title: 'Shop', icon: Icons.storefront_rounded, items: catalog.merch, catalog: catalog),
        if (catalog.donations.isNotEmpty)
          _Section(title: 'Support & donate', icon: Icons.favorite_rounded, items: catalog.donations, catalog: catalog),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ShopItem> items;
  final ShopCatalog catalog;
  const _Section({required this.title, required this.icon, required this.items, required this.catalog});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: catalog.accent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          ...items.map((item) => _ShopCard(item: item, catalog: catalog)),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopItem item;
  final ShopCatalog catalog;
  const _ShopCard({required this.item, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? catalog.accent;
    final cta = switch (item.kind) {
      ShopItemKind.ticket => 'Buy ticket',
      ShopItemKind.membership => 'Join',
      ShopItemKind.donation => 'Donate',
      ShopItemKind.merch => 'Add to bag',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(item.name,
                        style: const TextStyle(color: SportSphereColors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  if (item.badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.badge!,
                          style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                Text(item.subtitle, style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.formattedPrice,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              openCheckout(context, catalog: catalog, line: CartLine(item: item));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: accent),
              child: Text(cta, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
