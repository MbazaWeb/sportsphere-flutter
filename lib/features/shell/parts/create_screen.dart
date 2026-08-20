part of '../app_shell.dart';

// ══════════════════════════════════════════════════════════════════════════════
// CREATE SCREEN  — full compose experience
// ══════════════════════════════════════════════════════════════════════════════
//
// Layout:
//  • Author row (avatar + name + Fan badge + audience dropdown)
//  • Text area (hint, @mention chips, 280-char counter)
//  • Attachment strip: hidden panels for Poll / Prediction / Location /
//    Disappearing / Tag — revealed one at a time
//  • Media preview strip (up to 4 tiles, removable)
//  • Bottom toolbar: attachment icon → expands chip row, then media/poll/…
//  • Post button with submit animation (scale → check → done)

// ── Post type enum ─────────────────────────────────────────────────────────────
enum _PostType { text, media, poll, prediction, liveCoverage }

// ── Disappearing duration options ──────────────────────────────────────────────
const _disappearOptions = [
  (label: '1 hour', icon: Icons.timer_outlined),
  (label: '6 hours', icon: Icons.timer_outlined),
  (label: '24 hours', icon: Icons.timer_rounded),
  (label: '7 days', icon: Icons.calendar_today_outlined),
];

// ── Mock tag suggestions ───────────────────────────────────────────────────────
const _tagSuggestions = [
  (name: 'Simba SC', handle: '@simbasc', icon: Icons.groups_rounded),
  (name: 'Young Africans', handle: '@yanga', icon: Icons.groups_rounded),
  (name: 'Clatous Chama', handle: '@chama', icon: Icons.person_rounded),
  (name: 'Ali Kingu', handle: '@alikingu', icon: Icons.analytics_rounded),
  (name: 'TFF', handle: '@tff_tz', icon: Icons.emoji_events_rounded),
];

// ── Mock location suggestions ──────────────────────────────────────────────────
const _locationSuggestions = [
  'Dar es Salaam, Tanzania',
  'National Stadium, DSM',
  'Mkapa Stadium, DSM',
  'Benjamin Mkapa Stadium',
  'Nairobi, Kenya',
];

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY WIDGET  (replaces old stub, lives in IndexedStack at index 2)
// ══════════════════════════════════════════════════════════════════════════════

class _CreateScreen extends StatelessWidget {
  const _CreateScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(
        child: _CreateComposer(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPOSER
// ══════════════════════════════════════════════════════════════════════════════

class _CreateComposer extends StatefulWidget {
  const _CreateComposer();
  @override
  State<_CreateComposer> createState() => _CreateComposerState();
}

class _CreateComposerState extends State<_CreateComposer>
    with TickerProviderStateMixin {
  // ── Text ─────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  static const _maxChars = 280;

  // ── Active content panel ──────────────────────────────────────
  _PostType _type = _PostType.text;

  // ── Attachment toolbar ────────────────────────────────────────
  bool _canPredict = true;
  bool _toolbarExpanded = false;

  // ── Active overlay panels ─────────────────────────────────────
  bool _showLocation = false;
  bool _showDisappearing = false;
  bool _showTag = false;

  // ── Media tiles (mock paths / names) ─────────────────────────
  final List<XFile> _mediaFiles = [];
  final List<String> _mediaTiles = [];

  // ── Poll state ────────────────────────────────────────────────
  final List<TextEditingController> _pollOptions = [
    TextEditingController(text: ''),
    TextEditingController(text: ''),
  ];
  Duration _pollDuration = const Duration(days: 1);

  String? _coverageMatchId;
  String? _coverageMatchLabel;


  // ── Prediction state ──────────────────────────────────────────
  String _predHomeTeam = 'Simba SC';
  String _predAwayTeam = 'Young Africans';
  int _predHomeScore = 1;
  int _predAwayScore = 1;

  // ── Extras ────────────────────────────────────────────────────
  String? _location;
  String? _disappearsIn;
  final List<String> _tags = [];

  // ── Audience ─────────────────────────────────────────────────
  String _audience = 'Everyone';

  // ── Submit animation ─────────────────────────────────────────
  late final AnimationController _submitCtrl;
  late final Animation<double> _submitScale;
  bool _submitted = false;
  bool _posting = false;

  // ── Toolbar expand animation ───────────────────────────────────
  late final AnimationController _toolbarCtrl;
  late final Animation<double> _toolbarAnim;

  @override
  void initState() {
    super.initState();
    // _loadRoleGates(); // Removed - not needed
    _submitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _submitScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _submitCtrl, curve: Curves.easeInOut));

    _toolbarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _toolbarAnim = CurvedAnimation(parent: _toolbarCtrl, curve: Curves.easeOutCubic);

    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _submitCtrl.dispose();
    _toolbarCtrl.dispose();
    _textCtrl.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────
  int get _charsLeft => _maxChars - _textCtrl.text.length;
  bool get _canPost =>
      _textCtrl.text.trim().isNotEmpty ||
      _mediaTiles.isNotEmpty ||
      _type == _PostType.poll ||
      _type == _PostType.prediction ||
      (_type == _PostType.liveCoverage && _coverageMatchId != null);

  void _toggleToolbar() {
    setState(() => _toolbarExpanded = !_toolbarExpanded);
    _toolbarExpanded ? _toolbarCtrl.forward() : _toolbarCtrl.reverse();
  }

  void _switchType(_PostType type) {
    setState(() {
      _type = _type == type ? _PostType.text : type;
      _toolbarExpanded = false;
      _showLocation = false;
      _showDisappearing = false;
      _showTag = false;
    });
    _toolbarCtrl.reverse();
  }

  Future<void> _addMockMedia() async {
    if (_mediaFiles.length >= 4) return;
    final files = await pickAndEditMedia(context, remaining: 4 - _mediaFiles.length);
    if (files.isEmpty) return;
    setState(() {
      _mediaFiles.addAll(files);
      _mediaTiles
        ..clear()
        ..addAll(_mediaFiles.map((f) => f.name));
      _type = _PostType.media;
    });
  }

  Future<void> _submit() async {
    if (!_canPost || _posting) return;
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);

    try {
      final social = SocialRepository();
      final urls = <String>[];
      for (final file in _mediaFiles) {
        final url = await social.uploadPickedFile(
          bucket: 'posts',
          folder: 'posts',
          file: file,
        );
        urls.add(url);
      }
      final text = _textCtrl.text.trim();
      final tags = RegExp(r'#\w+').allMatches(text).map((m) => m.group(0)!).toList();
      final type = _type == _PostType.liveCoverage
          ? 'live_coverage'
          : urls.isEmpty
              ? (_type == _PostType.poll
                  ? 'poll'
                  : _type == _PostType.prediction
                      ? 'prediction'
                      : 'text')
              : 'media';
      await social.createPost(
        content: text.isEmpty
            ? (_type == _PostType.liveCoverage
                ? 'LIVE: ${_coverageMatchLabel ?? 'Match'}'
                : ' ')
            : text,
        mediaUrls: urls,
        postType: type,
        hashtags: tags,
        teamTag: _type == _PostType.liveCoverage && _coverageMatchId != null
            ? 'match:${_coverageMatchId}'
            : null,
        isBreaking: _type == _PostType.liveCoverage,
      );
      await _submitCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _submitted = true;
          _posting = false;
        });
      }
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
      return;
    }

    if (mounted) {
      _textCtrl.clear();
      _mediaTiles.clear();
      _mediaFiles.clear();
      for (final c in _pollOptions) {
        c.clear();
      }
      _submitCtrl.reset();
      setState(() {
        _type = _PostType.text;
        _submitted = false;
        _location = null;
        _disappearsIn = null;
        _tags.clear();
        _toolbarExpanded = false;
        _coverageMatchId = null;
        _coverageMatchLabel = null;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────
        _ComposerHeader(
          audience: _audience,
          onAudienceChanged: (v) => setState(() => _audience = v),
        ),

        // ── Scrollable body ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text area
                _TextArea(
                  controller: _textCtrl,
                  charsLeft: _charsLeft,
                  maxChars: _maxChars,
                ),

                // Tag chips (if any tags added)
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _TagChips(
                    tags: _tags,
                    onRemove: (t) => setState(() => _tags.remove(t)),
                  ),
                ],

                // Media strip
                if (_mediaTiles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MediaStrip(
                    tiles: _mediaTiles,
                    onRemove: (i) => setState(() { _mediaTiles.removeAt(i); if (i < _mediaFiles.length) _mediaFiles.removeAt(i); }),
                  ),
                ],

                // Poll panel
                if (_type == _PostType.poll) ...[
                  const SizedBox(height: 14),
                  _PollPanel(
                    options: _pollOptions,
                    duration: _pollDuration,
                    onDurationChanged: (d) =>
                        setState(() => _pollDuration = d),
                    onAddOption: () {
                      if (_pollOptions.length < 4) {
                        setState(() => _pollOptions
                            .add(TextEditingController()));
                      }
                    },
                    onRemoveOption: (i) {
                      if (_pollOptions.length > 2) {
                        setState(() {
                          _pollOptions[i].dispose();
                          _pollOptions.removeAt(i);
                        });
                      }
                    },
                  ),
                ],

                // Prediction panel
                if (_type == _PostType.liveCoverage) ...[
                  const SizedBox(height: 14),
                  _LiveCoveragePanel(
                    matchId: _coverageMatchId,
                    label: _coverageMatchLabel,
                    onPicked: (id, label) => setState(() {
                      _coverageMatchId = id;
                      _coverageMatchLabel = label;
                    }),
                  ),
                ],

                if (_type == _PostType.prediction) ...[
                  const SizedBox(height: 14),
                  _PredictionPanel(
                    homeTeam: _predHomeTeam,
                    awayTeam: _predAwayTeam,
                    homeScore: _predHomeScore,
                    awayScore: _predAwayScore,
                    onHomeTeamChanged: (v) =>
                        setState(() => _predHomeTeam = v),
                    onAwayTeamChanged: (v) =>
                        setState(() => _predAwayTeam = v),
                    onHomeScoreChanged: (v) =>
                        setState(() => _predHomeScore = v),
                    onAwayScoreChanged: (v) =>
                        setState(() => _predAwayScore = v),
                  ),
                ],

                // Location panel
                if (_showLocation) ...[
                  const SizedBox(height: 14),
                  _LocationPanel(
                    selected: _location,
                    onSelect: (l) =>
                        setState(() {
                          _location = l;
                          _showLocation = false;
                        }),
                    onClear: () =>
                        setState(() {
                          _location = null;
                          _showLocation = false;
                        }),
                  ),
                ],

                // Disappearing panel
                if (_showDisappearing) ...[
                  const SizedBox(height: 14),
                  _DisappearingPanel(
                    selected: _disappearsIn,
                    onSelect: (v) =>
                        setState(() {
                          _disappearsIn = v;
                          _showDisappearing = false;
                        }),
                    onClear: () =>
                        setState(() {
                          _disappearsIn = null;
                          _showDisappearing = false;
                        }),
                  ),
                ],

                // Tag panel
                if (_showTag) ...[
                  const SizedBox(height: 14),
                  _TagPanel(
                    added: _tags,
                    onAdd: (t) {
                      if (!_tags.contains(t)) {
                        setState(() {
                          _tags.add(t);
                          _showTag = false;
                        });
                      }
                    },
                  ),
                ],

                // Active meta badges
                if (_location != null ||
                    _disappearsIn != null) ...[
                  const SizedBox(height: 12),
                  _MetaBadges(
                    location: _location,
                    disappearsIn: _disappearsIn,
                    onRemoveLocation: () =>
                        setState(() => _location = null),
                    onRemoveDisappearing: () =>
                        setState(() => _disappearsIn = null),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── Attachment toolbar ────────────────────────────────────
        _AttachmentBar(
          expanded: _toolbarExpanded,
          anim: _toolbarAnim,
          activeType: _type,
          showLocation: _showLocation,
          showDisappearing: _showDisappearing,
          showTag: _showTag,
          onToggle: _toggleToolbar,
          onMedia: _addMockMedia,
          onPoll: () => _switchType(_PostType.poll),
          allowPrediction: _canPredict,
          onPrediction: () => _switchType(_PostType.prediction),
          onLive: () => _switchType(_PostType.liveCoverage),
          onLocation: () => setState(() {
            _showLocation = !_showLocation;
            _showDisappearing = false;
            _showTag = false;
          }),
          onDisappearing: () => setState(() {
            _showDisappearing = !_showDisappearing;
            _showLocation = false;
            _showTag = false;
          }),
          onTag: () => setState(() {
            _showTag = !_showTag;
            _showLocation = false;
            _showDisappearing = false;
          }),
          canPost: _canPost,
          submitted: _submitted,
          posting: _posting,
          submitScale: _submitScale,
          onPost: _submit,
          charsLeft: _charsLeft,
          maxChars: _maxChars,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER — author row + audience selector
// ══════════════════════════════════════════════════════════════════════════════

class _ComposerHeader extends StatelessWidget {
  final String audience;
  final ValueChanged<String> onAudienceChanged;
  const _ComposerHeader({
    required this.audience,
    required this.onAudienceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  SportSphereColors.electricBlue,
                  SportSphereColors.sportGreen,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SportSphereColors.background,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/sport_sphere_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: SportSphereColors.muted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'You',
                      style: TextStyle(
                        color: SportSphereColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Fan badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SportSphereColors.sportGreen
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: SportSphereColors.sportGreen
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Fan',
                        style: TextStyle(
                          color: SportSphereColors.sportGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Audience dropdown pill
                GestureDetector(
                  onTap: () => _showAudiencePicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SportSphereColors.electricBlue
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SportSphereColors.electricBlue
                            .withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _audienceIcon(audience),
                          color: SportSphereColors.electricBlue,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          audience,
                          style: TextStyle(
                            color: SportSphereColors.electricBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.expand_more_rounded,
                          color: SportSphereColors.electricBlue,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Page title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'New Post',
                style: TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _audienceIcon(String audience) {
    switch (audience) {
      case 'Followers':
        return Icons.group_rounded;
      case 'Fans Only':
        return Icons.favorite_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  void _showAudiencePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AudiencePicker(
        selected: audience,
        onSelect: (v) {
          onAudienceChanged(v);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _AudiencePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _AudiencePicker({required this.selected, required this.onSelect});

  static const _options = [
    (label: 'Everyone', icon: Icons.public_rounded, sub: 'Visible to all SportSphere users'),
    (label: 'Followers', icon: Icons.group_rounded, sub: 'Only people who follow you'),
    (label: 'Fans Only', icon: Icons.favorite_rounded, sub: 'Only your fans see this'),
  ];

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Who can see this?',
      child: Column(
        children: _options.map((o) {
          final active = selected == o.label;
          return GestureDetector(
            onTap: () => onSelect(o.label),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active
                    ? SportSphereColors.electricBlue.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? SportSphereColors.electricBlue.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(o.icon,
                      color: active
                          ? SportSphereColors.electricBlue
                          : SportSphereColors.muted,
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.label,
                            style: TextStyle(
                              color: active
                                  ? SportSphereColors.electricBlue
                                  : SportSphereColors.white,
                              fontWeight: FontWeight.w700,
                            )),
                        Text(o.sub,
                            style: const TextStyle(
                              color: SportSphereColors.muted,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  if (active)
                    Icon(Icons.check_circle_rounded,
                        color: SportSphereColors.electricBlue, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TEXT AREA
// ══════════════════════════════════════════════════════════════════════════════

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final int charsLeft;
  final int maxChars;
  const _TextArea({
    required this.controller,
    required this.charsLeft,
    required this.maxChars,
  });

  @override
  Widget build(BuildContext context) {
    final nearLimit = charsLeft <= 30;
    final overLimit = charsLeft < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: overLimit
                  ? SportSphereColors.danger.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: 6,
            minLines: 3,
            style: const TextStyle(
              color: SportSphereColors.white,
              fontSize: 16,
              height: 1.55,
            ),
            cursorColor: SportSphereColors.electricBlue,
            decoration: InputDecoration(
              hintText:
                  "What's happening in your world of sport? Use @ to mention someone…",
              hintStyle: TextStyle(
                color: SportSphereColors.muted.withValues(alpha: 0.55),
                fontSize: 15,
                height: 1.55,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Character counter
        Semantics(
          label: '$charsLeft characters remaining',
          child: Text(
            overLimit
                ? '${charsLeft.abs()} over limit'
                : '$charsLeft',
            style: TextStyle(
              color: overLimit
                  ? SportSphereColors.danger
                  : nearLimit
                      ? SportSphereColors.sportOrange
                      : SportSphereColors.muted.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight:
                  nearLimit ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MEDIA STRIP
// ══════════════════════════════════════════════════════════════════════════════

class _MediaStrip extends StatelessWidget {
  final List<String> tiles;
  final ValueChanged<int> onRemove;
  const _MediaStrip({required this.tiles, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          ...List.generate(tiles.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < tiles.length - 1 ? 8 : 0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            SportSphereColors.electricBlue
                                .withValues(alpha: 0.25),
                            SportSphereColors.sportGreen
                                .withValues(alpha: 0.15),
                          ],
                        ),
                        border: Border.all(
                          color:
                              Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_rounded,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.black.withValues(alpha: 0.65),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (tiles.length < 4)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () {
                  // trigger parent add
                },
                child: Container(
                  width: 60,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.035),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: SportSphereColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// POLL PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _PollPanel extends StatelessWidget {
  final List<TextEditingController> options;
  final Duration duration;
  final ValueChanged<Duration> onDurationChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;

  const _PollPanel({
    required this.options,
    required this.duration,
    required this.onDurationChanged,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  static const _durations = [
    (label: '1 hour', dur: Duration(hours: 1)),
    (label: '6 hours', dur: Duration(hours: 6)),
    (label: '1 day', dur: Duration(days: 1)),
    (label: '3 days', dur: Duration(days: 3)),
    (label: '7 days', dur: Duration(days: 7)),
  ];

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'POLL',
      color: SportSphereColors.electricBlue,
      icon: Icons.poll_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _PanelField(
                      controller: options[i],
                      hint: 'Option ${i + 1}',
                      icon: Icons.circle_outlined,
                    ),
                  ),
                  if (options.length > 2) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemoveOption(i),
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: SportSphereColors.danger
                            .withValues(alpha: 0.75),
                        size: 22,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          if (options.length < 4)
            GestureDetector(
              onTap: onAddOption,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SportSphereColors.electricBlue
                        .withValues(alpha: 0.30),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: SportSphereColors.electricBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add option',
                      style: TextStyle(
                        color: SportSphereColors.electricBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),
          Text(
            'Poll duration',
            style: TextStyle(
              color: SportSphereColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durations.map((d) {
              final active = duration == d.dur;
              return GestureDetector(
                onTap: () => onDurationChanged(d.dur),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? SportSphereColors.electricBlue
                        : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: active
                          ? SportSphereColors.electricBlue
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    d.label,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : SportSphereColors.muted,
                      fontSize: 12,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PREDICTION PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _PredictionPanel extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final ValueChanged<String> onHomeTeamChanged;
  final ValueChanged<String> onAwayTeamChanged;
  final ValueChanged<int> onHomeScoreChanged;
  final ValueChanged<int> onAwayScoreChanged;

  const _PredictionPanel({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.onHomeTeamChanged,
    required this.onAwayTeamChanged,
    required this.onHomeScoreChanged,
    required this.onAwayScoreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'PREDICTION',
      color: SportSphereColors.sportGreen,
      icon: Icons.insights_rounded,
      child: Row(
        children: [
          // Home team
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Colors.white70,
                  size: 36,
                ),
                const SizedBox(height: 6),
                _PanelField(
                  controller:
                      TextEditingController(text: homeTeam),
                  hint: 'Home Team',
                  icon: Icons.edit_rounded,
                  onChanged: onHomeTeamChanged,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                _ScoreStepper(
                  value: homeScore,
                  onChanged: onHomeScoreChanged,
                ),
              ],
            ),
          ),

          // VS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$homeScore - $awayScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Away team
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Colors.white70,
                  size: 36,
                ),
                const SizedBox(height: 6),
                _PanelField(
                  controller:
                      TextEditingController(text: awayTeam),
                  hint: 'Away Team',
                  icon: Icons.edit_rounded,
                  onChanged: onAwayTeamChanged,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                _ScoreStepper(
                  value: awayScore,
                  onChanged: onAwayScoreChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          onTap: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? SportSphereColors.sportGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: onTap != null
                ? SportSphereColors.sportGreen.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? SportSphereColors.sportGreen
              : SportSphereColors.muted.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOCATION PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _LocationPanel extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  const _LocationPanel({
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'LOCATION',
      color: SportSphereColors.sportOrange,
      icon: Icons.location_on_rounded,
      child: Column(
        children: _locationSuggestions.map((l) {
          final active = selected == l;
          return GestureDetector(
            onTap: () => onSelect(l),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: active
                    ? SportSphereColors.sportOrange
                        .withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: active
                      ? SportSphereColors.sportOrange
                          .withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place_rounded,
                    color: active
                        ? SportSphereColors.sportOrange
                        : SportSphereColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l,
                      style: TextStyle(
                        color: active
                            ? SportSphereColors.white
                            : SportSphereColors.muted,
                        fontSize: 13,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (active)
                    Icon(
                      Icons.check_rounded,
                      color: SportSphereColors.sportOrange,
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DISAPPEARING PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _DisappearingPanel extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  const _DisappearingPanel({
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'DISAPPEARS IN',
      color: SportSphereColors.danger,
      icon: Icons.timer_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _disappearOptions.map((o) {
          final active = selected == o.label;
          return GestureDetector(
            onTap: () => onSelect(o.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? SportSphereColors.danger
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: active
                      ? SportSphereColors.danger
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    o.icon,
                    size: 14,
                    color: active
                        ? Colors.white
                        : SportSphereColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    o.label,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : SportSphereColors.muted,
                      fontSize: 13,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAG PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _TagPanel extends StatelessWidget {
  final List<String> added;
  final ValueChanged<String> onAdd;
  const _TagPanel({required this.added, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'TAG PEOPLE OR TEAMS',
      color: SportSphereColors.brightBlue,
      icon: Icons.alternate_email_rounded,
      child: Column(
        children: _tagSuggestions.map((s) {
          final isAdded = added.contains(s.handle);
          return GestureDetector(
            onTap: isAdded ? null : () => onAdd(s.handle),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isAdded
                    ? SportSphereColors.brightBlue
                        .withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isAdded
                      ? SportSphereColors.brightBlue
                          .withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SportSphereColors.surface2,
                    ),
                    child: Icon(
                      s.icon,
                      color: SportSphereColors.electricBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            color: SportSphereColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          s.handle,
                          style: const TextStyle(
                            color: SportSphereColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isAdded
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: isAdded
                        ? SportSphereColors.brightBlue
                        : SportSphereColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAG CHIPS ROW
// ══════════════════════════════════════════════════════════════════════════════

class _TagChips extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onRemove;
  const _TagChips({required this.tags, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: SportSphereColors.electricBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SportSphereColors.electricBlue.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t,
                style: TextStyle(
                  color: SportSphereColors.electricBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onRemove(t),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: SportSphereColors.electricBlue
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// META BADGES (location + disappearing)
// ══════════════════════════════════════════════════════════════════════════════

class _MetaBadges extends StatelessWidget {
  final String? location;
  final String? disappearsIn;
  final VoidCallback onRemoveLocation;
  final VoidCallback onRemoveDisappearing;

  const _MetaBadges({
    required this.location,
    required this.disappearsIn,
    required this.onRemoveLocation,
    required this.onRemoveDisappearing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (location != null)
          _MetaBadge(
            icon: Icons.place_rounded,
            label: location!,
            color: SportSphereColors.sportOrange,
            onRemove: onRemoveLocation,
          ),
        if (disappearsIn != null)
          _MetaBadge(
            icon: Icons.timer_rounded,
            label: disappearsIn!,
            color: SportSphereColors.danger,
            onRemove: onRemoveDisappearing,
          ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onRemove;
  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              color: color.withValues(alpha: 0.7),
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ATTACHMENT BAR + POST BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class _AttachmentBar extends StatelessWidget {
  final bool expanded;
  final Animation<double> anim;
  final _PostType activeType;
  final bool showLocation;
  final bool showDisappearing;
  final bool showTag;
  final VoidCallback onToggle;
  final VoidCallback onMedia;
  final VoidCallback onPoll;
  final bool allowPrediction;
  final VoidCallback onPrediction;
  final VoidCallback onLive;
  final VoidCallback onLocation;
  final VoidCallback onDisappearing;
  final VoidCallback onTag;
  final bool canPost;
  final bool submitted;
  final bool posting;
  final Animation<double> submitScale;
  final VoidCallback onPost;
  final int charsLeft;
  final int maxChars;

  const _AttachmentBar({
    required this.expanded,
    required this.anim,
    required this.activeType,
    required this.showLocation,
    required this.showDisappearing,
    required this.showTag,
    required this.onToggle,
    required this.onMedia,
    required this.onPoll,
    this.allowPrediction = true,
    required this.onPrediction,
    required this.onLive,
    required this.onLocation,
    required this.onDisappearing,
    required this.onTag,
    required this.canPost,
    required this.submitted,
    required this.posting,
    required this.submitScale,
    required this.onPost,
    required this.charsLeft,
    required this.maxChars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        color: SportSphereColors.background.withValues(alpha: 0.96),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Expanded attachment chips ───────────────────────────
          SizeTransition(
            sizeFactor: anim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _AttachChip(
                      icon: Icons.image_outlined,
                      label: 'Media',
                      active: activeType == _PostType.media,
                      color: SportSphereColors.electricBlue,
                      onTap: onMedia,
                    ),
                    const SizedBox(width: 8),
                    _AttachChip(
                      icon: Icons.poll_outlined,
                      label: 'Poll',
                      active: activeType == _PostType.poll,
                      color: SportSphereColors.electricBlue,
                      onTap: onPoll,
                    ),
                    const SizedBox(width: 8),
                    if (allowPrediction) ...[
                      _AttachChip(
                        icon: Icons.insights_rounded,
                        label: 'Predict',
                        active: activeType == _PostType.prediction,
                        color: SportSphereColors.sportGreen,
                        onTap: onPrediction,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _AttachChip(
                      icon: Icons.sensors,
                      label: 'Live',
                      active: activeType == _PostType.liveCoverage,
                      color: const Color(0xFFE31B23),
                      onTap: onLive,
                    ),
                    const SizedBox(width: 8),
                    _AttachChip(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      active: showLocation,
                      color: SportSphereColors.sportOrange,
                      onTap: onLocation,
                    ),
                    const SizedBox(width: 8),
                    _AttachChip(
                      icon: Icons.timer_outlined,
                      label: 'Vanish',
                      active: showDisappearing,
                      color: SportSphereColors.danger,
                      onTap: onDisappearing,
                    ),
                    const SizedBox(width: 8),
                    _AttachChip(
                      icon: Icons.alternate_email_rounded,
                      label: 'Tag',
                      active: showTag,
                      color: SportSphereColors.brightBlue,
                      onTap: onTag,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Main toolbar row ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                // Attach toggle
                Semantics(
                  label: expanded
                      ? 'Close attachment options'
                      : 'Open attachment options',
                  button: true,
                  child: GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: expanded
                            ? SportSphereColors.electricBlue
                                .withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: expanded
                              ? SportSphereColors.electricBlue
                                  .withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 280),
                        turns: expanded ? 0.125 : 0,
                        child: Icon(
                          Icons.add_rounded,
                          color: expanded
                              ? SportSphereColors.electricBlue
                              : SportSphereColors.muted,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Post button
                Semantics(
                  label: submitted ? 'Posted!' : 'Post',
                  button: true,
                  child: GestureDetector(
                    onTap: (canPost && !posting && !submitted)
                        ? onPost
                        : null,
                    child: ScaleTransition(
                      scale: submitScale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          gradient: LinearGradient(
                            colors: (canPost && !posting)
                                ? [
                                    SportSphereColors.electricBlue,
                                    const Color(0xFF0066DD),
                                  ]
                                : [
                                    SportSphereColors.muted
                                        .withValues(alpha: 0.25),
                                    SportSphereColors.muted
                                        .withValues(alpha: 0.20),
                                  ],
                          ),
                          boxShadow: (canPost && !posting && !submitted)
                              ? [
                                  BoxShadow(
                                    color: SportSphereColors.electricBlue
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: submitted
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Posted!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                )
                              : posting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Post',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                        ),
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

class _AttachChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _AttachChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label attachment',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: active
                ? color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? color : SportSphereColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : SportSphereColors.muted,
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════

/// Labelled content panel (Poll, Prediction, Location, etc.)
class _ContentPanel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  const _ContentPanel({
    required this.label,
    required this.color,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Single-line text field inside a panel
class _PanelField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;

  const _PanelField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onChanged,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: textAlign,
        style: const TextStyle(
          color: SportSphereColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: SportSphereColors.electricBlue,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: SportSphereColors.muted.withValues(alpha: 0.55),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon,
              color: SportSphereColors.muted, size: 16),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

/// Generic bottom-sheet wrapper
class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}


class _LiveCoveragePanel extends StatefulWidget {
  final String? matchId;
  final String? label;
  final void Function(String id, String label) onPicked;
  const _LiveCoveragePanel({required this.matchId, required this.label, required this.onPicked});

  @override
  State<_LiveCoveragePanel> createState() => _LiveCoveragePanelState();
}

class _LiveCoveragePanelState extends State<_LiveCoveragePanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('Match')
          .select('id,homeTeam,awayTeam,status,kickoffAt,league')
          .order('kickoffAt')
          .limit(80);
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(rows as List); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE31B23).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: Color(0xFFE31B23), size: 18),
              SizedBox(width: 8),
              Text('Live coverage', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.label ?? 'Pick a match to cover. Updates go in the live thread.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator()
          else SizedBox(
            height: 180,
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (_, i) {
                final r = _rows[i];
                final id = r['id']?.toString() ?? '';
                final label = '${r['homeTeam']} vs ${r['awayTeam']}';
                final selected = widget.matchId == id;
                return ListTile(
                  dense: true,
                  selected: selected,
                  title: Text(label, style: const TextStyle(fontSize: 13)),
                  subtitle: Text('${r['league'] ?? ''} · ${r['status'] ?? ''}', style: const TextStyle(fontSize: 11)),
                  trailing: selected ? const Icon(Icons.check, color: Color(0xFFE31B23)) : null,
                  onTap: () => widget.onPicked(id, label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
