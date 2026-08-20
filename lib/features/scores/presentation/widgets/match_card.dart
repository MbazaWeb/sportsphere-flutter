import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/match_model.dart';

class MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTeamTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onLongPress;

  const MatchCard({
    super.key,
    required this.match,
    this.onTeamTap,
    this.onCardTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${match.homeTeamName} vs ${match.awayTeamName}, ${match.leagueName}, score ${match.score}, status ${match.status}',
      button: true,
      child: GestureDetector(
        onTap: onCardTap,
        onLongPress: onLongPress,
        child: GlassContainer(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League + alert
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: SportSphereColors.surface2,
                    child: const Icon(Icons.sports_soccer,
                        size: 14, color: Colors.white),
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
                  Semantics(
                    label: 'Set match alerts',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: SportSphereColors.muted, size: 20),
                      onPressed: () => _showReminderSheet(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Teams + score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'View ${match.homeTeamName} profile',
                      button: true,
                      child: GestureDetector(
                        onTap: onTeamTap,
                        child: Column(
                          children: [
                            _TeamAvatar(logo: match.homeTeamLogo),
                            const SizedBox(height: 8),
                            Text(
                              match.homeTeamName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: match.isLive
                              ? SportSphereColors.danger.withValues(alpha: 0.2)
                              : SportSphereColors.surface2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          match.status,
                          style: TextStyle(
                            color: match.isLive
                                ? SportSphereColors.danger
                                : SportSphereColors.sportGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'View ${match.awayTeamName} profile',
                      button: true,
                      child: GestureDetector(
                        onTap: onTeamTap,
                        child: Column(
                          children: [
                            _TeamAvatar(logo: match.awayTeamLogo),
                            const SizedBox(height: 8),
                            Text(
                              match.awayTeamName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MatchAction(
                    icon: Icons.favorite_border_rounded,
                    label: 'Like',
                  ),
                  _MatchAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                  ),
                  _MatchAction(
                    icon: Icons.insights_rounded,
                    label: 'Predict',
                  ),
                  _MatchAction(
                    icon: Icons.share_outlined,
                    label: 'Share',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReminderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SportSphereColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AlertSheet(),
    );
  }
}

// ── Alert sheet (stateful toggles) ────────────────────────────────────────────

class _AlertSheet extends StatefulWidget {
  const _AlertSheet();

  @override
  State<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<_AlertSheet> {
  bool _matchStart = true;
  bool _goals = true;
  bool _redCards = false;
  bool _halfFullTime = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Match Alerts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _Toggle(
            label: 'Match Start',
            value: _matchStart,
            onChanged: (v) => setState(() => _matchStart = v),
          ),
          _Toggle(
            label: 'Goals',
            value: _goals,
            onChanged: (v) => setState(() => _goals = v),
          ),
          _Toggle(
            label: 'Red Cards',
            value: _redCards,
            onChanged: (v) => setState(() => _redCards = v),
          ),
          _Toggle(
            label: 'Half / Full Time',
            value: _halfFullTime,
            onChanged: (v) => setState(() => _halfFullTime = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'Save alert settings',
              button: true,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: SportSphereColors.electricBlue,
                ),
                child: const Text('Save Settings'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label alert toggle',
      toggled: value,
      child: SwitchListTile(
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: SportSphereColors.electricBlue,
      ),
    );
  }
}

// ── Team avatar ────────────────────────────────────────────────────────────────

class _TeamAvatar extends StatelessWidget {
  final String logo;
  const _TeamAvatar({required this.logo});

  @override
  Widget build(BuildContext context) {
    final hasUrl = logo.startsWith('http');
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SportSphereColors.surface2,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shield,
                color: SportSphereColors.muted,
                size: 30,
              ),
            )
          : const Icon(Icons.shield, color: SportSphereColors.muted, size: 30),
    );
  }
}

// ── Match action ───────────────────────────────────────────────────────────────

class _MatchAction extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MatchAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: SportSphereColors.muted, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: SportSphereColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
