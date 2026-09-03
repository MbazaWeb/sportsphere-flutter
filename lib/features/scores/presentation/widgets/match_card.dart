import '../../../../core/data/vps_supabase_compat.dart';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/vps_repository.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/rate_limiter.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../domain/models/match_model.dart';
import '../../domain/models/match_status.dart';

/// Storage key prefix for locally-persisted match alerts (one JSON blob per
/// match id). We use [FlutterSecureStorage] because `shared_preferences` is
/// not in pubspec.yaml and adding a new dep is forbidden by the task brief.
const String _kAlertStoragePrefix = 'match_alert_';

class MatchCard extends StatefulWidget {

  const MatchCard({
    super.key,
    required this.match,
    this.onTeamTap,
    this.onCardTap,
    this.onLongPress,
  });
  final MatchModel match;
  final VoidCallback? onTeamTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onLongPress;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _liked = false;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _seedLikedState();
  }

  Future<void> _seedLikedState() async {
    final postId = widget.match.postId;
    if (postId == null || postId.isEmpty) return;
    if (VpsSupabaseCompat.client.auth.currentUser == null) return;
    try {
      final liked = await const VpsRepository().isPostLiked(postId);
      if (mounted && liked) setState(() => _liked = true);
    } catch (_) {
      // best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final statusColor = _statusBadgeColor(m);
    return Semantics(
      label:
          '${m.homeTeamName} vs ${m.awayTeamName}, ${m.leagueName}, score ${m.score}, status ${m.status}',
      button: true,
      child: GestureDetector(
        onTap: widget.onCardTap,
        onLongPress: widget.onLongPress,
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
                    backgroundColor: PlayifyColors.surface2,
                    child: Icon(sportIconFor(m.sportSlug),
                        size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.leagueName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayifyColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Set match alerts',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: PlayifyColors.muted, size: 20),
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
                      label: 'View ${m.homeTeamName} profile',
                      button: true,
                      child: GestureDetector(
                        onTap: widget.onTeamTap,
                        child: Column(
                          children: [
                            _TeamAvatar(logo: m.homeTeamLogo),
                            const SizedBox(height: 8),
                            Text(
                              m.homeTeamName,
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
                        m.score,
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
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'View ${m.awayTeamName} profile',
                      button: true,
                      child: GestureDetector(
                        onTap: widget.onTeamTap,
                        child: Column(
                          children: [
                            _TeamAvatar(logo: m.awayTeamLogo),
                            const SizedBox(height: 8),
                            Text(
                              m.awayTeamName,
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

              const SizedBox(height: 8),
              _KickoffVenueRow(match: m),

              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MatchAction(
                    icon: _liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: 'Like',
                    iconColor:
                        _liked ? PlayifyColors.danger : PlayifyColors.muted,
                    onTap: _onLike,
                  ),
                  _MatchAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                    onTap: _onComment,
                  ),
                  _MatchAction(
                    icon: Icons.insights_rounded,
                    label: 'Predict',
                    onTap: _onPredict,
                  ),
                  _MatchAction(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: _onShare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────────

  Future<void> _onLike() async {
    if (_likeBusy) return;
    if (!likeLimiter.allow('match-${widget.match.id}')) {
      _toast('Too many actions — wait a moment.');
      return;
    }
    final m = widget.match;
    if (m.postId == null || m.postId!.isEmpty) {
      setState(() => _liked = !_liked);
      _toast(_liked ? 'Liked' : 'Like removed');
      return;
    }
    if (VpsSupabaseCompat.client.auth.currentUser == null) {
      _toast('Sign in to like');
      return;
    }
    setState(() { _liked = !_liked; _likeBusy = true; });
    try {
      if (_liked) {
        await const VpsRepository().likePost(m.postId!);
      } else {
        await const VpsRepository().unlikePost(m.postId!);
      }
      _toast(_liked ? 'Liked' : 'Like removed');
    } catch (e) {
      if (mounted) setState(() => _liked = !_liked);
      _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _onComment() {
    final m = widget.match;
    if (!commentLimiter.allow('match-${m.id}')) {
      _toast('Too many actions — wait a moment.');
      return;
    }
    // No dedicated comment sheet exists for matches yet — surface a clear,
    // actionable message rather than being a no-op.
    _toast('Comments coming soon for this match');
  }

  void _onPredict() {
    final m = widget.match;
    if (!voteLimiter.allow('match-${m.id}')) {
      _toast('Too many actions — wait a moment.');
      return;
    }
    // No dedicated prediction screen exists yet — surface a clear, actionable
    // message rather than being a no-op.
    _toast('Predictions coming soon for ${m.homeTeamName} vs ${m.awayTeamName}');
  }

  Future<void> _onShare() async {
    final m = widget.match;
    if (!shareLimiter.allow('match-${m.id}')) {
      _toast('Too many actions — wait a moment.');
      return;
    }
    final text = _shareSummary(m);
    try {
      await Share.share(text, subject: 'Playify · Match');
      // Record the share if there's a linked post (best-effort).
      final postId = m.postId;
      if (postId != null && postId.isNotEmpty &&
          VpsSupabaseCompat.client.auth.currentUser != null) {
        try {
          await const VpsRepository().sharePost(postId);
        } catch (_) {
          // best-effort
        }
      }
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  String _shareSummary(MatchModel m) {
    final df = DateFormat('d MMM, h:mm a');
    final lines = <String>[
      '${m.homeTeamName} ${m.score} ${m.awayTeamName}',
      m.leagueName,
    ];
    if (m.venue.isNotEmpty) lines.add('📍 ${m.venue}');
    lines.add('Kickoff ${df.format(m.startTime)}');
    lines.add('On Playify');
    return lines.join('\n');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showReminderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PlayifyColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AlertSheet(matchId: widget.match.id),
    );
  }

  Color _statusBadgeColor(MatchModel m) {
    final s = m.parsedStatus;
    if (s.isLive) return PlayifyColors.sportGreen;
    if (s.isFinished) return PlayifyColors.muted;
    if (s.isPostponedOrCancelled) return PlayifyColors.sportOrange;
    if (s == MatchStatus.scheduled) return PlayifyColors.electricBlue;
    return PlayifyColors.muted;
  }
}

// ── Kickoff / venue subtitle ───────────────────────────────────────────────

class _KickoffVenueRow extends StatelessWidget {
  const _KickoffVenueRow({required this.match});
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('h:mm a');
    final parts = <String>[];
    parts.add('Kickoff ${df.format(match.startTime)}');
    if (match.venue.isNotEmpty) parts.add(match.venue);
    return Row(
      children: [
        Icon(Icons.access_time_rounded,
            size: 12, color: PlayifyColors.muted.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PlayifyColors.muted.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Alert sheet (stateful toggles, persisted to FlutterSecureStorage) ──────

class _AlertSheet extends StatefulWidget {
  const _AlertSheet({required this.matchId});
  final String matchId;

  @override
  State<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<_AlertSheet> {
  static const _storage = FlutterSecureStorage();

  bool _matchStart = true;
  bool _goals = true;
  bool _redCards = false;
  bool _halfFullTime = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final raw = await _storage.read(key: '$_kAlertStoragePrefix${widget.matchId}');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        setState(() {
          _matchStart = decoded['matchStart'] as bool? ?? _matchStart;
          _goals = decoded['goals'] as bool? ?? _goals;
          _redCards = decoded['redCards'] as bool? ?? _redCards;
          _halfFullTime = decoded['halfFullTime'] as bool? ?? _halfFullTime;
        });
      }
    } catch (_) {
      // Best-effort — leave defaults.
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = jsonEncode({
      'matchId': widget.matchId,
      'matchStart': _matchStart,
      'goals': _goals,
      'redCards': _redCards,
      'halfFullTime': _halfFullTime,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    try {
      await _storage.write(
        key: '$_kAlertStoragePrefix${widget.matchId}',
        value: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert saved')),
      );
      Navigator.pop(context);
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          const SizedBox(height: 4),
          const Text(
            'Stored locally on this device.',
            style: TextStyle(
              color: PlayifyColors.muted,
              fontSize: 12,
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
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: PlayifyColors.electricBlue,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Settings'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

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
        activeColor: PlayifyColors.electricBlue,
      ),
    );
  }
}

// ── Team avatar (uses cached_network_image when available) ─────────────────

class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({required this.logo});
  final String logo;

  @override
  Widget build(BuildContext context) {
    final hasUrl = logo.startsWith('http://') || logo.startsWith('https://');
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PlayifyColors.surface2,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: logo,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Icon(
                Icons.shield,
                color: PlayifyColors.muted,
                size: 30,
              ),
              errorWidget: (_, __, ___) => const Icon(
                Icons.shield,
                color: PlayifyColors.muted,
                size: 30,
              ),
            )
          : const Icon(Icons.shield, color: PlayifyColors.muted, size: 30),
    );
  }
}

// ── Match action ───────────────────────────────────────────────────────────

class _MatchAction extends StatelessWidget {
  const _MatchAction({
    required this.icon,
    required this.label,
    this.iconColor = PlayifyColors.muted,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: PlayifyColors.muted,
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
