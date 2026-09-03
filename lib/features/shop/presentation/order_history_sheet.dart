import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/data/commerce_repository.dart';

/// Shows buyer's/seller's order history as a bottom sheet.
Future<void> showOrderHistory(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OrderHistorySheet(),
  );
}

class _OrderHistorySheet extends StatefulWidget {
  const _OrderHistorySheet();

  @override
  State<_OrderHistorySheet> createState() => _OrderHistorySheetState();
}

class _OrderHistorySheetState extends State<_OrderHistorySheet> {
  int _tab = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final commerce = CommerceRepository();
      final orders = _tab == 0
          ? await commerce.myOrders()
          : await commerce.sellerOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusEmoji(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'paid':
        return '\u2705';
      case 'pending_confirm':
      case 'stk_sent':
        return '\u23F3';
      case 'failed':
      case 'stk_failed':
        return '\u274C';
      default:
        return '\u{1F4E6}';
    }
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'pending_confirm':
        return 'Pending';
      case 'stk_sent':
        return 'STK Sent';
      case 'failed':
      case 'stk_failed':
        return 'Failed';
      default:
        return status ?? 'Unknown';
    }
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return 'TZS $buf';
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF071422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'My Orders',
            style: TextStyle(
              color: PlayifyColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_tab != 0) {
                        setState(() {
                        _tab = 0;
                        _load();
                      });
                      }
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: _tab == 0
                            ? PlayifyColors.electricBlue
                                .withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: _tab == 0
                              ? PlayifyColors.electricBlue
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        'Purchases',
                        style: TextStyle(
                          color: _tab == 0
                              ? PlayifyColors.electricBlue
                              : PlayifyColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_tab != 1) {
                        setState(() {
                        _tab = 1;
                        _load();
                      });
                      }
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: _tab == 1
                            ? PlayifyColors.electricBlue
                                .withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: _tab == 1
                              ? PlayifyColors.electricBlue
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        'Sales',
                        style: TextStyle(
                          color: _tab == 1
                              ? PlayifyColors.electricBlue
                              : PlayifyColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _orders.isEmpty
                    ? Center(
                        child: Text(
                          'No orders yet',
                          style: TextStyle(
                            color:
                                PlayifyColors.muted.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassContainer(
                              radius: 16,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _statusEmoji(o['status']),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${o['itemName'] ?? 'Order'}',
                                          style: const TextStyle(
                                            color: PlayifyColors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (o['status'] ==
                                                  'paid'
                                              ? PlayifyColors
                                                  .sportGreen
                                              : PlayifyColors.muted)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _statusLabel(o['status']),
                                          style: TextStyle(
                                            color: o['status'] == 'paid'
                                                ? PlayifyColors
                                                    .sportGreen
                                                : PlayifyColors.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _fmt(
                                            (o['amountTzs'] as int?) ??
                                                0),
                                        style: TextStyle(
                                          color: PlayifyColors.white
                                              .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _ago(o['createdAt']
                                            ?.toString()),
                                        style: const TextStyle(
                                          color: PlayifyColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_tab == 1) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ref: ${o['id']?.toString().substring(0, 16) ?? ''}',
                                      style: const TextStyle(
                                        color: PlayifyColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
