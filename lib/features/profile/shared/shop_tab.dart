import 'package:flutter/material.dart';

class ShopTab extends StatelessWidget {
  final String userId;
  final String? teamId;
  
  const ShopTab({
    super.key,
    required this.userId,
    this.teamId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 64,
            color: const Color(0xFF8A9BB0).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Shop Coming Soon',
            style: TextStyle(
              color: Color(0xFF8A9BB0),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Merchandise and tickets will be available here',
            style: TextStyle(
              color: Color(0xFF8A9BB0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}