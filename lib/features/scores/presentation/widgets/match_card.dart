import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/match_model.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTeamTap;
  final VoidCallback? onCardTap;

  const MatchCard({
    super.key,
    required this.match,
    this.onTeamTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      child: GlassContainer(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // League Info & Alert Button
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: SportSphereColors.surface2,
                  child: const Icon(Icons.sports_soccer, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  match.leagueName,
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: SportSphereColors.muted, size: 20),
                  onPressed: () {
                    _showReminderOptions(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Teams & Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTeamTap,
                    child: Column(
                      children: [
                        _TeamAvatar(logo: match.homeTeamLogo),
                        const SizedBox(height: 8),
                        Text(
                          match.homeTeamName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      match.score,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: match.isLive ? SportSphereColors.danger.withValues(alpha: 0.2) : SportSphereColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        match.status,
                        style: TextStyle(
                          color: match.isLive ? SportSphereColors.danger : SportSphereColors.sportGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onTeamTap,
                    child: Column(
                      children: [
                        _TeamAvatar(logo: match.awayTeamLogo),
                        const SizedBox(height: 8),
                        Text(
                          match.awayTeamName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Divider
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            
            const SizedBox(height: 12),
            
            // Feed-like Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MatchAction(icon: Icons.favorite_border_rounded, label: 'Like'),
                _MatchAction(icon: Icons.chat_bubble_outline_rounded, label: 'Comment'),
                _MatchAction(icon: Icons.insights_rounded, label: 'Predict'),
                _MatchAction(icon: Icons.share_outlined, label: 'Share'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SportSphereColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set Match Alerts',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _AlertToggle(label: 'Match Start', value: true),
              _AlertToggle(label: 'Goals', value: true),
              _AlertToggle(label: 'Red Cards', value: false),
              _AlertToggle(label: 'Half/Full Time', value: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(backgroundColor: SportSphereColors.electricBlue),
                  child: const Text('Save Settings'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  final String logo;
  const _TeamAvatar({required this.logo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SportSphereColors.surface2,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Icon(Icons.shield, color: SportSphereColors.muted, size: 30),
    );
  }
}

class _MatchAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MatchAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, color: SportSphereColors.muted, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: SportSphereColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  final String label;
  final bool value;

  const _AlertToggle({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      value: value,
      onChanged: (v) {},
      activeColor: SportSphereColors.electricBlue,
    );
  }
}
