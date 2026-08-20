import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SHOP MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum ShopCategory { kits, tickets, membership, merchandise }

extension ShopCategoryLabel on ShopCategory {
  String get label {
    switch (this) {
      case ShopCategory.kits:        return 'Kits';
      case ShopCategory.tickets:     return 'Tickets';
      case ShopCategory.membership:  return 'Membership';
      case ShopCategory.merchandise: return 'Merch';
    }
  }

  IconData get icon {
    switch (this) {
      case ShopCategory.kits:        return Icons.checkroom_rounded;
      case ShopCategory.tickets:     return Icons.confirmation_number_rounded;
      case ShopCategory.membership:  return Icons.card_membership_rounded;
      case ShopCategory.merchandise: return Icons.shopping_bag_rounded;
    }
  }
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.category,
    required this.description,
    this.badgeLabel,
    this.isAvailable = true,
    this.originalPrice,
    this.matchDate,
    this.matchOpponent,
    this.seatSection,
    this.membershipDuration,
    this.accentColor,
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final ShopCategory category;
  final String description;
  final String? badgeLabel;        // e.g. 'NEW', 'SOLD OUT', 'LIMITED'
  final bool isAvailable;
  final double? originalPrice;     // if on sale
  final String? matchDate;         // tickets
  final String? matchOpponent;     // tickets
  final String? seatSection;       // tickets
  final String? membershipDuration; // e.g. 'Monthly', 'Annual', 'Lifetime'
  final Color? accentColor;

  String get priceLabel => '$currency ${price.toStringAsFixed(0)}';
  String? get originalPriceLabel =>
      originalPrice != null ? '$currency ${originalPrice!.toStringAsFixed(0)}' : null;
  bool get isOnSale => originalPrice != null && originalPrice! > price;
}

class CartItem {
  CartItem({required this.item, this.quantity = 1});
  final ShopItem item;
  int quantity;
}

// ── Mock Simba SC shop ─────────────────────────────────────────────────────────

List<ShopItem> buildTeamShop(String teamName, Color accent) => [
  // Tickets
  ShopItem(
    id: 't1',
    name: 'Match Ticket — $teamName vs Yanga',
    price: 5000,
    currency: 'TZS',
    category: ShopCategory.tickets,
    description: 'Kariakoo Derby · Benjamin Mkapa Stadium',
    badgeLabel: 'HOT',
    matchDate: 'Sun 24 Aug · 16:00',
    matchOpponent: 'Young Africans SC',
    seatSection: 'Main Stand',
    accentColor: accent,
  ),
  ShopItem(
    id: 't2',
    name: 'VIP Match Ticket',
    price: 25000,
    currency: 'TZS',
    category: ShopCategory.tickets,
    description: 'VIP Lounge access · All home matches',
    badgeLabel: 'VIP',
    matchDate: 'Sun 24 Aug · 16:00',
    matchOpponent: 'Young Africans SC',
    seatSection: 'VIP Lounge',
    accentColor: accent,
  ),
  // Membership
  ShopItem(
    id: 'm1',
    name: '$teamName Fan Membership',
    price: 10000,
    currency: 'TZS',
    category: ShopCategory.membership,
    description: 'Monthly access · Digital card · Exclusive content',
    membershipDuration: 'Monthly',
    accentColor: accent,
  ),
  ShopItem(
    id: 'm2',
    name: '$teamName Season Membership',
    price: 80000,
    currency: 'TZS',
    category: ShopCategory.membership,
    description: '12 months · Priority ticketing · Member kit discount',
    originalPrice: 120000,
    membershipDuration: 'Annual',
    badgeLabel: 'SAVE 33%',
    accentColor: accent,
  ),
  ShopItem(
    id: 'm3',
    name: 'Lifetime Membership',
    price: 500000,
    currency: 'TZS',
    category: ShopCategory.membership,
    description: 'Forever · Hall of Fans name plate · All benefits',
    membershipDuration: 'Lifetime',
    badgeLabel: 'EXCLUSIVE',
    accentColor: accent,
  ),
  // Kits
  ShopItem(
    id: 'k1',
    name: 'Home Kit 2026/27',
    price: 45000,
    currency: 'TZS',
    category: ShopCategory.kits,
    description: 'Official home jersey · All sizes · Customisable name & number',
    badgeLabel: 'NEW',
    accentColor: accent,
  ),
  ShopItem(
    id: 'k2',
    name: 'Away Kit 2026/27',
    price: 45000,
    currency: 'TZS',
    category: ShopCategory.kits,
    description: 'Official away jersey · White with red trim',
    accentColor: accent,
  ),
  ShopItem(
    id: 'k3',
    name: 'Training Kit',
    price: 28000,
    currency: 'TZS',
    category: ShopCategory.kits,
    description: 'Lightweight training shirt · Moisture-wicking fabric',
    originalPrice: 35000,
    accentColor: accent,
  ),
  // Merch
  ShopItem(
    id: 'mr1',
    name: 'Club Scarf',
    price: 8000,
    currency: 'TZS',
    category: ShopCategory.merchandise,
    description: 'Classic woven scarf · Red & white · One size',
    accentColor: accent,
  ),
  ShopItem(
    id: 'mr2',
    name: 'Club Cap',
    price: 12000,
    currency: 'TZS',
    category: ShopCategory.merchandise,
    description: 'Embroidered crest · Adjustable strap',
    accentColor: accent,
  ),
  ShopItem(
    id: 'mr3',
    name: 'Mug — Lion Edition',
    price: 6000,
    currency: 'TZS',
    category: ShopCategory.merchandise,
    description: '350ml ceramic mug · Dishwasher safe',
    badgeLabel: 'LIMITED',
    isAvailable: true,
    accentColor: accent,
  ),
];

// ── Mock Business shop ─────────────────────────────────────────────────────────

List<ShopItem> buildBusinessShop(String bizName, Color accent) => [
  ShopItem(
    id: 'b1',
    name: 'Premium Subscription',
    price: 29900,
    currency: 'TZS',
    category: ShopCategory.membership,
    description: 'Full access · Priority support · Exclusive content',
    originalPrice: 49900,
    membershipDuration: 'Monthly',
    badgeLabel: 'POPULAR',
    accentColor: accent,
  ),
  ShopItem(
    id: 'b2',
    name: 'Annual Plan',
    price: 249000,
    currency: 'TZS',
    category: ShopCategory.membership,
    description: '12 months · Save 30% vs monthly · All features',
    membershipDuration: 'Annual',
    badgeLabel: 'BEST VALUE',
    accentColor: accent,
  ),
  ShopItem(
    id: 'b3',
    name: 'SportSphere Live Package',
    price: 15000,
    currency: 'TZS',
    category: ShopCategory.tickets,
    description: 'Live match stream access · HD quality · Multi-device',
    accentColor: accent,
  ),
  ShopItem(
    id: 'b4',
    name: 'Sports Merchandise Bundle',
    price: 55000,
    currency: 'TZS',
    category: ShopCategory.merchandise,
    description: 'Exclusive branded gear · Limited edition collection',
    badgeLabel: 'LIMITED',
    accentColor: accent,
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// SHOP TAB WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class ShopTab extends StatefulWidget {
  final List<ShopItem> items;
  final Color accent;
  final String sellerName;

  const ShopTab({
    super.key,
    required this.items,
    required this.accent,
    required this.sellerName,
  });

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  ShopCategory? _filter;          // null = All
  final List<CartItem> _cart = [];

  int get _cartCount => _cart.fold(0, (sum, ci) => sum + ci.quantity);

  List<ShopItem> get _filtered => _filter == null
      ? widget.items
      : widget.items.where((i) => i.category == _filter).toList();

  void _addToCart(ShopItem item) {
    HapticFeedback.lightImpact();
    setState(() {
      final existing = _cart.where((c) => c.item.id == item.id).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _cart.add(CartItem(item: item));
      }
    });
  }

  void _showCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        cart: _cart,
        accent: widget.accent,
        onRemove: (id) => setState(() => _cart.removeWhere((c) => c.item.id == id)),
        onCheckout: () {
          Navigator.pop(context);
          _showCheckoutConfirmation();
        },
      ),
    );
  }

  void _showCheckoutConfirmation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(accent: widget.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ShopCategory.values
        .where((c) => widget.items.any((i) => i.category == c))
        .toList();

    return Column(
      children: [
        // ── Category filters + cart ────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // "All" chip
                      _CategoryChip(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        active: _filter == null,
                        accent: widget.accent,
                        onTap: () => setState(() => _filter = null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryChip(
                              label: c.label,
                              icon: c.icon,
                              active: _filter == c,
                              accent: widget.accent,
                              onTap: () =>
                                  setState(() => _filter = _filter == c ? null : c),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              // Cart button
              const SizedBox(width: 10),
              Semantics(
                label: 'View cart, $_cartCount items',
                button: true,
                child: GestureDetector(
                  onTap: _cartCount > 0 ? _showCart : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _cartCount > 0
                              ? widget.accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: _cartCount > 0
                                ? widget.accent.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: _cartCount > 0
                              ? widget.accent
                              : SportSphereColors.muted,
                          size: 18,
                        ),
                      ),
                      if (_cartCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.accent,
                              border: Border.all(
                                color: SportSphereColors.background,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$_cartCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Product grid ───────────────────────────────────
        Expanded(
          child: _filtered.isEmpty
              ? const _EmptyShop()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ShopCard(
                    item: _filtered[i],
                    accent: widget.accent,
                    onAddToCart: () => _addToCart(_filtered[i]),
                    onBuyNow: () {
                      _addToCart(_filtered[i]);
                      _showCart();
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Category chip ──────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label category filter',
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: active
                ? accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: active ? accent : SportSphereColors.muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? accent : SportSphereColors.muted,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shop card ──────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final ShopItem item;
  final Color accent;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  const _ShopCard({
    required this.item,
    required this.accent,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  Widget build(BuildContext context) {
    final ia = item.accentColor ?? accent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: const [
          BoxShadow(color: Color(0x30000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image area ─────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _ProductImage(item: item, accent: ia),
          ),

          // ── Content ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category + badge row
                Row(
                  children: [
                    _CatLabel(category: item.category, accent: ia),
                    if (item.badgeLabel != null) ...[
                      const SizedBox(width: 8),
                      _ItemBadge(label: item.badgeLabel!, accent: ia),
                    ],
                    const Spacer(),
                    if (!item.isAvailable)
                      _ItemBadge(label: 'SOLD OUT', accent: SportSphereColors.muted),
                  ],
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  item.name,
                  style: const TextStyle(
                    color: SportSphereColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  item.description,
                  style: TextStyle(
                    color: SportSphereColors.muted.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),

                // Match details (tickets)
                if (item.matchDate != null) ...[
                  const SizedBox(height: 8),
                  _TicketDetails(item: item, accent: ia),
                ],

                // Membership duration badge
                if (item.membershipDuration != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: ia.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Text(item.membershipDuration!,
                          style: TextStyle(
                            color: ia.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Price + action buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isOnSale)
                          Text(
                            item.originalPriceLabel!,
                            style: TextStyle(
                              color: SportSphereColors.muted.withValues(alpha: 0.6),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          item.priceLabel,
                          style: TextStyle(
                            color: ia,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (item.isAvailable) ...[
                      // Add to cart
                      Semantics(
                        label: 'Add ${item.name} to cart',
                        button: true,
                        child: GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14)),
                            ),
                            child: Icon(Icons.add_shopping_cart_rounded,
                                color: SportSphereColors.muted, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Buy Now
                      Semantics(
                        label: 'Buy ${item.name} now',
                        button: true,
                        child: GestureDetector(
                          onTap: onBuyNow,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [ia, ia.withValues(alpha: 0.75)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ia.withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Buy Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: const Center(
                          child: Text(
                            'Sold Out',
                            style: TextStyle(
                              color: SportSphereColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Product image placeholder ──────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final ShopItem item;
  final Color accent;
  const _ProductImage({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF07111E),
            accent.withValues(alpha: 0.35),
            const Color(0xFF020810),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              item.category.icon,
              size: 72,
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          // Watermark text
          Positioned(
            bottom: 12,
            left: 14,
            child: Text(
              item.category.label.toUpperCase(),
              style: TextStyle(
                color: accent.withValues(alpha: 0.30),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ticket details strip ───────────────────────────────────────────────────────

class _TicketDetails extends StatelessWidget {
  final ShopItem item;
  final Color accent;
  const _TicketDetails({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _TicketInfo(
            icon: Icons.sports_soccer_rounded,
            value: item.matchOpponent ?? '',
            accent: accent,
          ),
          Container(width: 1, height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.white.withValues(alpha: 0.08)),
          _TicketInfo(
            icon: Icons.schedule_rounded,
            value: item.matchDate ?? '',
            accent: accent,
          ),
          if (item.seatSection != null) ...[
            Container(width: 1, height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white.withValues(alpha: 0.08)),
            _TicketInfo(
              icon: Icons.event_seat_rounded,
              value: item.seatSection!,
              accent: accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color accent;
  const _TicketInfo({required this.icon, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent.withValues(alpha: 0.7), size: 13),
        const SizedBox(width: 5),
        Flexible(
          child: Text(value,
              style: TextStyle(
                color: SportSphereColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ),
      ],
    );
  }
}

// ── Small label widgets ────────────────────────────────────────────────────────

class _CatLabel extends StatelessWidget {
  final ShopCategory category;
  final Color accent;
  const _CatLabel({required this.category, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(category.icon, size: 12, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(category.label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            )),
      ],
    );
  }
}

class _ItemBadge extends StatelessWidget {
  final String label;
  final Color accent;
  const _ItemBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
            color: accent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          )),
    );
  }
}

// ── Cart sheet ─────────────────────────────────────────────────────────────────

class _CartSheet extends StatefulWidget {
  final List<CartItem> cart;
  final Color accent;
  final ValueChanged<String> onRemove;
  final VoidCallback onCheckout;

  const _CartSheet({
    required this.cart,
    required this.accent,
    required this.onRemove,
    required this.onCheckout,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  @override
  Widget build(BuildContext context) {
    final total = widget.cart.fold(
      0.0,
      (sum, ci) => sum + ci.item.price * ci.quantity,
    );
    final currency = widget.cart.isNotEmpty
        ? widget.cart.first.item.currency
        : 'TZS';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: const BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                const Text('Your Cart',
                    style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                Text('${widget.cart.length} item${widget.cart.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: SportSphereColors.muted, fontSize: 13)),
              ],
            ),
          ),

          if (widget.cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Your cart is empty',
                  style: TextStyle(color: SportSphereColors.muted)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                itemCount: widget.cart.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ci = widget.cart[i];
                  return _CartRow(
                    cartItem: ci,
                    accent: widget.accent,
                    onRemove: () {
                      widget.onRemove(ci.item.id);
                      setState(() {});
                    },
                    onIncrement: () => setState(() => ci.quantity++),
                    onDecrement: () {
                      setState(() {
                        if (ci.quantity > 1) {
                          ci.quantity--;
                        } else {
                          widget.onRemove(ci.item.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),

          // Total + checkout
          if (widget.cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                children: [
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Total',
                          style: TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 14,
                          )),
                      const Spacer(),
                      Text(
                        '$currency ${total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label: 'Proceed to payment',
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onCheckout,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [widget.accent, widget.accent.withValues(alpha: 0.75)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.32),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Proceed to Payment',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem cartItem;
  final Color accent;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartRow({
    required this.cartItem,
    required this.accent,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(cartItem.item.category.icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
                Text(cartItem.item.priceLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          // Quantity stepper
          _QtyBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${cartItem.quantity}',
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                )),
          ),
          _QtyBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 14, color: SportSphereColors.muted),
      ),
    );
  }
}

// ── Checkout confirmation sheet ────────────────────────────────────────────────

class _CheckoutSheet extends StatelessWidget {
  final Color accent;
  const _CheckoutSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SportSphereColors.sportGreen.withValues(alpha: 0.12),
              border: Border.all(
                  color: SportSphereColors.sportGreen.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.check_rounded,
                color: SportSphereColors.sportGreen, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Payment Coming Soon',
              style: TextStyle(
                color: SportSphereColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          Text(
            'Secure payments will be powered by SportSphere Pay.\nYour order has been noted.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Center(
                child: Text('Close',
                    style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty shop ─────────────────────────────────────────────────────────────────

class _EmptyShop extends StatelessWidget {
  const _EmptyShop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined,
              size: 48, color: SportSphereColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('No items available',
              style: TextStyle(color: SportSphereColors.muted)),
        ],
      ),
    );
  }
}
