part of '../app_shell.dart';
// ignore: unused_import

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
enum _PostType { text, media, poll, prediction }

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
  bool _toolbarExpanded = false;

  // ── Active overlay panels ─────────────────────────────────────
  bool _showLocation = false;
  bool _showDisappearing = false;
  bool _showTag = false;

  // ── Media tiles (actual file paths / uploaded URLs) ─────────────
  final List<String> _mediaTiles = [];
  final List<bool> _mediaIsVideo = [];
  final _picker = ImagePicker();
  final _social = SocialRepository();

  // ── Poll state ────────────────────────────────────────────────
  final List<TextEditingController> _pollOptions = [
    TextEditingController(text: ''),
    TextEditingController(text: ''),
  ];
  Duration _pollDuration = const Duration(days: 1);

  // ── Prediction state ─────────────────────────────────────────────────────────
  late final TextEditingController _predHomeCtrl;
  late final TextEditingController _predAwayCtrl;
  int _predHomeScore = 1;
  int _predAwayScore = 1;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _players = [];
  String? _selectedMatchId;
  Map<String, dynamic>? _selectedMatch;  // full match row
  Map<String, dynamic>? _selectedPlayer; // for player prediction
  String _predType = 'match'; // 'match' or 'player'

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
    _predHomeCtrl = TextEditingController();
    _predAwayCtrl = TextEditingController();
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
    // Pre-load matches + players for prediction/poll dropdowns
    _loadTeams();
    _loadMatches();
    _loadPlayers();
  }

  Future<void> _loadTeams() async {
    try {
      final rows = await Supabase.instance.client
          .from('Team').select('id,name').order('name').limit(200);
      if (mounted) {
        setState(() => _teams = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {}
  }

  Future<void> _loadMatches() async {
    try {
      final rows = await Supabase.instance.client
          .from('Match')
          .select('id,homeTeam,awayTeam,kickoffAt,league,status')
          .inFilter('status', ['upcoming', 'live', 'scheduled'])
          .order('kickoffAt')
          .limit(50);
      if (mounted) {
        setState(() => _matches = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {}
  }

  Future<void> _loadPlayers() async {
    try {
      final rows = await Supabase.instance.client
          .from('Player').select('id,name,position,teamId').order('name').limit(300);
      if (mounted) {
        setState(() => _players = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _submitCtrl.dispose();
    _toolbarCtrl.dispose();
    _textCtrl.dispose();
    _predHomeCtrl.dispose();
    _predAwayCtrl.dispose();
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
      _type == _PostType.prediction;

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

  Future<void> _pickMedia() async {
    if (_mediaTiles.length >= 4) return;
    // Show source picker
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: SportSphereColors.electricBlue),
              title: const Text('Gallery', style: TextStyle(color: SportSphereColors.white)),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: SportSphereColors.sportGreen),
              title: const Text('Camera (Photo)', style: TextStyle(color: SportSphereColors.white)),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded, color: SportSphereColors.sportOrange),
              title: const Text('Camera (Video)', style: TextStyle(color: SportSphereColors.white)),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Determine if user wants video
    bool pickVideo = false;
    if (source == ImageSource.camera) {
      // Second sheet was video option — detect by what they tapped
      // The camera source can do both. For simplicity, pick image first.
      pickVideo = false;
    }

    setState(() => _type = _PostType.media);
    try {
      if (pickVideo) {
        final file = await _picker.pickVideo(source: source);
        if (file == null) return;
        setState(() => _posting = true);
        final url = await _social.uploadPickedFile(
          bucket: 'media', folder: 'videos', file: file,
        );
        setState(() {
          _mediaTiles.add(url);
          _mediaIsVideo.add(true);
          _posting = false;
        });
      } else {
        // Show a quick image/video choice if gallery
        if (source == ImageSource.gallery) {
          final choice = await showDialog<String>(
            context: context,
            builder: (d) => SimpleDialog(
              backgroundColor: const Color(0xFF0C1A2A),
              title: const Text('Pick media type', style: TextStyle(color: Colors.white)),
              children: [
                SimpleDialogOption(
                  child: const Text('Image', style: TextStyle(color: SportSphereColors.electricBlue)),
                  onPressed: () => Navigator.pop(d, 'image'),
                ),
                SimpleDialogOption(
                  child: const Text('Video', style: TextStyle(color: SportSphereColors.sportGreen)),
                  onPressed: () => Navigator.pop(d, 'video'),
                ),
              ],
            ),
          );
          if (choice == null) return;
          pickVideo = choice == 'video';
        }

        if (pickVideo) {
          final file = await _picker.pickVideo(source: source);
          if (file == null) return;
          setState(() => _posting = true);
          final url = await _social.uploadPickedFile(
            bucket: 'media', folder: 'videos', file: file,
          );
          setState(() {
            _mediaTiles.add(url);
            _mediaIsVideo.add(true);
            _posting = false;
          });
        } else {
          final file = await _picker.pickImage(source: source, imageQuality: 85);
          if (file == null) return;
          setState(() => _posting = true);
          final url = await _social.uploadPickedFile(
            bucket: 'posts', folder: 'images', file: file,
          );
          setState(() {
            _mediaTiles.add(url);
            _mediaIsVideo.add(false);
            _posting = false;
          });
        }
      }
    } catch (e) {
      setState(() => _posting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: const Color(0xFFE31B23)),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_canPost || _posting) return;
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);

    final repo = SocialRepository();

    try {
      // Extract hashtags from text
      final text = _textCtrl.text.trim();
      final hashtagExp = RegExp(r'#(\w+)');
      final hashtags = hashtagExp
          .allMatches(text)
          .map((m) => m.group(1)!)
          .toList();

      switch (_type) {
        case _PostType.poll:
          final question = text.isNotEmpty
              ? text
              : _pollOptions.first.text.trim();
          final options = _pollOptions
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          await repo.createPollWithPost(
            question: question,
            options: options,
          );

        case _PostType.prediction:
          if (_predType == 'player' && _selectedPlayer != null) {
            // Player prediction: notify via post content
            final playerName = _selectedPlayer!['name'] ?? '';
            final playerNote = text.isNotEmpty ? text : 'I predict $playerName scores!';
            await repo.createPrediction(
              homeTeam: _selectedPlayer!['name'] ?? '',
              awayTeam: '',
              predictedHome: _predHomeScore,
              predictedAway: 0,
              matchId: _selectedMatchId,
              note: playerNote,
            );
          } else {
            final home = _selectedMatch?['homeTeam'] ?? _predHomeCtrl.text.trim();
            final away = _selectedMatch?['awayTeam'] ?? _predAwayCtrl.text.trim();
            await repo.createPrediction(
              homeTeam: home,
              awayTeam: away,
              predictedHome: _predHomeScore,
              predictedAway: _predAwayScore,
              matchId: _selectedMatchId,
              note: text.isNotEmpty ? text : null,
            );
          }

        default:
          await repo.createPost(
            content: text,
            postType: _type == _PostType.media ? 'media' : 'text',
            mediaUrls: List<String>.from(_mediaTiles),
            hashtags: hashtags,
          );
      }

      await _submitCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 400));

      // Refresh post count after successful creation
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        try {
          await Supabase.instance.client.rpc('refresh_user_counts', params: {'p_id': uid});
        } catch (_) {}
      }

      setState(() {
        _submitted = true;
        _posting = false;
      });

      await Future.delayed(const Duration(milliseconds: 900));
    } catch (e) {
      setState(() => _posting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: const Color(0xFFE31B23)),
        );
      }
      return;
    }

    if (mounted) {
      // Reset everything
      _textCtrl.clear();
      _mediaTiles.clear();
      _mediaIsVideo.clear();
      for (var i = 2; i < _pollOptions.length; i++) {
        _pollOptions[i].dispose();
      }
      _pollOptions
        ..removeRange(2, _pollOptions.length)
        ..forEach((c) => c.clear());
      _predHomeCtrl.clear();
      _predAwayCtrl.clear();
      _submitCtrl.reset();
      setState(() {
        _type = _PostType.text;
        _submitted = false;
        _location = null;
        _disappearsIn = null;
        _tags.clear();
        _toolbarExpanded = false;
        _selectedMatch = null;
        _selectedMatchId = null;
        _selectedPlayer = null;
        _predType = 'match';
      });

      // Navigate to home feed so user sees their new post
      context.go('/home');
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
                    isVideo: _mediaIsVideo.isNotEmpty
                        ? List<bool>.from(_mediaIsVideo)
                        : List.filled(_mediaTiles.length, false),
                    onRemove: (i) => setState(() {
                      _mediaTiles.removeAt(i);
                      if (i < _mediaIsVideo.length) _mediaIsVideo.removeAt(i);
                    }),
                  ),
                ],

                // Poll panel
                if (_type == _PostType.poll) ...[
                  const SizedBox(height: 14),
                  _PollPanel(
                    options: _pollOptions,
                    teams: _teams,
                    players: _players,
                    duration: _pollDuration,
                    onDurationChanged: (d) =>
                        setState(() => _pollDuration = d),
                    onAddOption: () {
                      if (_pollOptions.length < 6) {
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
                    onAddTeam: (name) {
                      if (_pollOptions.length < 6) {
                        setState(() => _pollOptions.add(TextEditingController(text: name)));
                      }
                    },
                    onAddPlayer: (name) {
                      if (_pollOptions.length < 6) {
                        setState(() => _pollOptions.add(TextEditingController(text: name)));
                      }
                    },
                  ),
                ],

                // Prediction panel
                if (_type == _PostType.prediction) ...[
                  const SizedBox(height: 14),
                  _PredictionPanel(
                    homeCtrl: _predHomeCtrl,
                    awayCtrl: _predAwayCtrl,
                    homeScore: _predHomeScore,
                    awayScore: _predAwayScore,
                    predType: _predType,
                    matches: _matches,
                    players: _players,
                    selectedMatch: _selectedMatch,
                    selectedPlayer: _selectedPlayer,
                    onPredTypeChanged: (v) => setState(() {
                      _predType = v;
                      _selectedPlayer = null;
                    }),
                    onMatchSelected: (m) => setState(() {
                      _selectedMatch = m;
                      _selectedMatchId = m?['id']?.toString();
                      if (m != null) {
                        _predHomeCtrl.text = m['homeTeam'] ?? '';
                        _predAwayCtrl.text = m['awayTeam'] ?? '';
                      }
                    }),
                    onPlayerSelected: (p) => setState(() => _selectedPlayer = p),
                    onHomeScoreChanged: (v) => setState(() => _predHomeScore = v),
                    onAwayScoreChanged: (v) => setState(() => _predAwayScore = v),
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
          onMedia: _pickMedia,
          onPoll: () => _switchType(_PostType.poll),
          onPrediction: () => _switchType(_PostType.prediction),
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
                    'assets/images/playify_icon.png',
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
      backgroundColor: SportSphereColors.transparent,
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
                    : SportSphereColors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? SportSphereColors.electricBlue.withValues(alpha: 0.45)
                      : SportSphereColors.white.withValues(alpha: 0.08),
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
            color: SportSphereColors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: overLimit
                  ? SportSphereColors.danger.withValues(alpha: 0.5)
                  : SportSphereColors.white.withValues(alpha: 0.07),
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
  final List<bool> isVideo;
  final ValueChanged<int> onRemove;
  const _MediaStrip({required this.tiles, required this.isVideo, required this.onRemove});

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
                        color: const Color(0xFF0B1626),
                        border: Border.all(
                          color: SportSphereColors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: tiles[i].startsWith('http')
                            ? (isVideo.length > i && isVideo[i]
                                ? Container(color: Colors.black, child: const Center(child: Icon(Icons.play_circle_rounded, color: Colors.white, size: 32)))
                                : Image.network(tiles[i], fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 32)))
                            : const Icon(Icons.image_rounded, color: SportSphereColors.white38, size: 32),
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
                                SportSphereColors.black.withValues(alpha: 0.65),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: SportSphereColors.white,
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
                    color: SportSphereColors.white.withValues(alpha: 0.035),
                    border: Border.all(
                      color: SportSphereColors.white.withValues(alpha: 0.10),
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

class _PollPanel extends StatefulWidget {
  final List<TextEditingController> options;
  final List<Map<String,dynamic>> teams;
  final List<Map<String,dynamic>> players;
  final Duration duration;
  final ValueChanged<Duration> onDurationChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<String> onAddTeam;
  final ValueChanged<String> onAddPlayer;

  const _PollPanel({
    required this.options,
    required this.teams,
    required this.players,
    required this.duration,
    required this.onDurationChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onAddTeam,
    required this.onAddPlayer,
  });

  @override
  State<_PollPanel> createState() => _PollPanelState();
}

class _PollPanelState extends State<_PollPanel> {
  bool _loadingTeams = false;
  bool _loadingPlayers = false;

  static const _durations = [
    (label: '1 hour', dur: Duration(hours: 1)),
    (label: '6 hours', dur: Duration(hours: 6)),
    (label: '1 day', dur: Duration(days: 1)),
    (label: '3 days', dur: Duration(days: 3)),
    (label: '7 days', dur: Duration(days: 7)),
  ];

  Future<void> _fillFromTeams() async {
    if (_loadingTeams) return;
    setState(() => _loadingTeams = true);
    try {
      final rows = await Supabase.instance.client
          .from('Team')
          .select('name')
          .order('name')
          .limit(4);
      final names = <String>[];
      for (final r in (rows as List)) {
        final n = (r as Map)['name']?.toString().trim();
        if (n != null && n.isNotEmpty) names.add(n);
      }
      if (names.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No teams found')),
          );
        }
        return;
      }
      for (var i = 0; i < widget.options.length; i++) {
        widget.options[i].text = i < names.length ? names[i] : '';
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load teams: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  Future<void> _fillFromPlayers() async {
    if (_loadingPlayers) return;
    setState(() => _loadingPlayers = true);
    try {
      final rows = await Supabase.instance.client
          .from('Player')
          .select('name')
          .order('name')
          .limit(4);
      final names = <String>[];
      for (final r in (rows as List)) {
        final n = (r as Map)['name']?.toString().trim();
        if (n != null && n.isNotEmpty) names.add(n);
      }
      if (names.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No players found')),
          );
        }
        return;
      }
      for (var i = 0; i < widget.options.length; i++) {
        widget.options[i].text = i < names.length ? names[i] : '';
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load players: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlayers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'POLL',
      color: SportSphereColors.electricBlue,
      icon: Icons.poll_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _loadingTeams ? null : _fillFromTeams,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: SportSphereColors.electricBlue.withValues(alpha: 0.12),
                      border: Border.all(
                        color: SportSphereColors.electricBlue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loadingTeams)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: SportSphereColors.electricBlue),
                          )
                        else
                          const Icon(Icons.groups_rounded, size: 16, color: SportSphereColors.electricBlue),
                        const SizedBox(width: 6),
                        const Text('From teams', style: TextStyle(color: SportSphereColors.electricBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _loadingPlayers ? null : _fillFromPlayers,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: SportSphereColors.electricBlue.withValues(alpha: 0.12),
                      border: Border.all(
                        color: SportSphereColors.electricBlue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loadingPlayers)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: SportSphereColors.electricBlue),
                          )
                        else
                          const Icon(Icons.person_outline_rounded, size: 16, color: SportSphereColors.electricBlue),
                        const SizedBox(width: 6),
                        const Text('From players', style: TextStyle(color: SportSphereColors.electricBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(widget.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _PanelField(
                      controller: widget.options[i],
                      hint: 'Option ${i + 1}',
                      icon: Icons.circle_outlined,
                    ),
                  ),
                  if (widget.options.length > 2) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => widget.onRemoveOption(i),
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: SportSphereColors.danger.withValues(alpha: 0.75),
                        size: 22,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          if (widget.options.length < 6)
            GestureDetector(
              onTap: widget.onAddOption,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SportSphereColors.electricBlue.withValues(alpha: 0.30)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: SportSphereColors.electricBlue, size: 18),
                    SizedBox(width: 8),
                    Text('Add option', style: TextStyle(color: SportSphereColors.electricBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          if (widget.options.length < 6 && (widget.teams.isNotEmpty || widget.players.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (widget.teams.isNotEmpty) GestureDetector(
                onTap: () => _showTeamPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFF9B6DFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF9B6DFF).withValues(alpha: 0.35))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.groups_rounded, color: Color(0xFF9B6DFF), size: 14), SizedBox(width: 5),
                    Text('+ Team', style: TextStyle(color: Color(0xFF9B6DFF), fontSize: 12, fontWeight: FontWeight.w600))]),
                ),
              ),
              if (widget.players.isNotEmpty) GestureDetector(
                onTap: () => _showPlayerPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: SportSphereColors.sportOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20), border: Border.all(color: SportSphereColors.sportOrange.withValues(alpha: 0.35))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_rounded, color: SportSphereColors.sportOrange, size: 14), SizedBox(width: 5),
                    Text('+ Player', style: TextStyle(color: SportSphereColors.sportOrange, fontSize: 12, fontWeight: FontWeight.w600))]),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          const Text('Poll duration', style: TextStyle(color: SportSphereColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durations.map((d) {
              final active = widget.duration == d.dur;
              return GestureDetector(
                onTap: () => widget.onDurationChanged(d.dur),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active ? SportSphereColors.electricBlue : SportSphereColors.white.withValues(alpha: 0.06),
                    border: Border.all(color: active ? SportSphereColors.electricBlue : SportSphereColors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(
                    d.label,
                    style: TextStyle(
                      color: active ? SportSphereColors.white : SportSphereColors.muted,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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

  void _showTeamPicker(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: const Color(0xFF061525),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, sc) => Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(20,16,20,12),
            child: Text('Add Team to Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          Expanded(child: ListView.builder(controller: sc, itemCount: widget.teams.length,
            itemBuilder: (_, i) {
              final t = widget.teams[i];
              return ListTile(
                leading: const Icon(Icons.groups_rounded, color: Color(0xFF9B6DFF)),
                title: Text(t['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(c); widget.onAddTeam(t['name']?.toString() ?? ''); },
              );
            })),
        ]),
      ),
    );
  }

  void _showPlayerPicker(BuildContext ctx) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: ctx, isScrollControlled: true,
      backgroundColor: const Color(0xFF061525),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(builder: (bCtx, bSet) {
        final q = searchCtrl.text.toLowerCase();
        final filtered = widget.players.where((p) => (p['name'] as String? ?? '').toLowerCase().contains(q)).toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (_, sc) => Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(20,16,20,8),
              child: Text('Add Player to Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            Padding(padding: const EdgeInsets.fromLTRB(16,0,16,8),
              child: TextField(controller: searchCtrl, style: const TextStyle(color: Colors.white),
                onChanged: (_) => bSet((){}),
                decoration: InputDecoration(hintText: 'Search players...', hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                  filled: true, fillColor: const Color(0xFF0B1626),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true))),
            Expanded(child: ListView.builder(controller: sc, itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                return ListTile(
                  leading: const Icon(Icons.person_rounded, color: Color(0xFFFF8A00)),
                  title: Text(p['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(p['position']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () { Navigator.pop(bCtx); widget.onAddPlayer(p['name']?.toString() ?? ''); },
                );
              })),
          ]),
        );
      }),
    );
  }
}
// ══════════════════════════════════════════════════════════════════════════════

class _PredictionPanel extends StatelessWidget {
  final TextEditingController homeCtrl;
  final TextEditingController awayCtrl;
  final int homeScore;
  final int awayScore;
  final String predType;
  final List<Map<String,dynamic>> matches;
  final List<Map<String,dynamic>> players;
  final Map<String,dynamic>? selectedMatch;
  final Map<String,dynamic>? selectedPlayer;
  final ValueChanged<String> onPredTypeChanged;
  final ValueChanged<Map<String,dynamic>?> onMatchSelected;
  final ValueChanged<Map<String,dynamic>?> onPlayerSelected;
  final ValueChanged<int> onHomeScoreChanged;
  final ValueChanged<int> onAwayScoreChanged;

  const _PredictionPanel({
    required this.homeCtrl,
    required this.awayCtrl,
    required this.homeScore,
    required this.awayScore,
    required this.predType,
    required this.matches,
    required this.players,
    required this.selectedMatch,
    required this.selectedPlayer,
    required this.onPredTypeChanged,
    required this.onMatchSelected,
    required this.onPlayerSelected,
    required this.onHomeScoreChanged,
    required this.onAwayScoreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ContentPanel(
      label: 'PREDICTION',
      color: SportSphereColors.sportGreen,
      icon: Icons.insights_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Type selector ─────────────────────────────────────────────────
        Row(children: [
          _PredTypeChip(
            label: 'Match Score',
            icon: Icons.sports_soccer_rounded,
            selected: predType == 'match',
            onTap: () => onPredTypeChanged('match'),
          ),
          const SizedBox(width: 8),
          _PredTypeChip(
            label: 'Player Event',
            icon: Icons.person_rounded,
            selected: predType == 'player',
            onTap: () => onPredTypeChanged('player'),
          ),
        ]),

        const SizedBox(height: 14),

        // ── Match selector (shown for both types) ─────────────────────────
        GestureDetector(
          onTap: () => _showMatchPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SportSphereColors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedMatch != null
                    ? SportSphereColors.sportGreen.withValues(alpha: 0.5)
                    : SportSphereColors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(children: [
              Icon(Icons.stadium_rounded,
                  color: selectedMatch != null
                      ? SportSphereColors.sportGreen
                      : SportSphereColors.muted,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                selectedMatch != null
                    ? '${selectedMatch!["homeTeam"]} vs ${selectedMatch!["awayTeam"]}'
                    : matches.isEmpty
                        ? 'No upcoming matches'
                        : 'Select a match (optional)',
                style: TextStyle(
                  color: selectedMatch != null ? SportSphereColors.white : SportSphereColors.muted,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              )),
              Icon(Icons.arrow_drop_down_rounded,
                  color: SportSphereColors.white54, size: 20),
            ]),
          ),
        ),

        const SizedBox(height: 14),

        // ── Match score prediction ─────────────────────────────────────────
        if (predType == 'match') ...[
          Row(children: [
            Expanded(child: Column(children: [
              Icon(Icons.shield_rounded, color: SportSphereColors.white70, size: 32),
              const SizedBox(height: 6),
              Text(
                homeCtrl.text.isEmpty ? 'Home' : homeCtrl.text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SportSphereColors.white,
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _ScoreStepper(value: homeScore, onChanged: onHomeScoreChanged),
            ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                Text('VS', style: TextStyle(
                    color: SportSphereColors.white38,
                    fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SportSphereColors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$homeScore - $awayScore',
                    style: const TextStyle(color: SportSphereColors.white,
                        fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ]),
            ),
            Expanded(child: Column(children: [
              Icon(Icons.shield_outlined, color: SportSphereColors.white70, size: 32),
              const SizedBox(height: 6),
              Text(
                awayCtrl.text.isEmpty ? 'Away' : awayCtrl.text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SportSphereColors.white,
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _ScoreStepper(value: awayScore, onChanged: onAwayScoreChanged),
            ])),
          ]),
        ],

        // ── Player event prediction ────────────────────────────────────────
        if (predType == 'player') ...[
          GestureDetector(
            onTap: () => _showPlayerPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: SportSphereColors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedPlayer != null
                      ? SportSphereColors.electricBlue.withValues(alpha: 0.5)
                      : SportSphereColors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(children: [
                Icon(Icons.person_rounded,
                    color: selectedPlayer != null
                        ? SportSphereColors.electricBlue
                        : SportSphereColors.muted,
                    size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  selectedPlayer != null
                      ? '${selectedPlayer!["name"]}  ·  ${selectedPlayer!["position"] ?? ""}'
                      : players.isEmpty ? 'No players available' : 'Select a player',
                  style: TextStyle(
                    color: selectedPlayer != null ? SportSphereColors.white : SportSphereColors.muted,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                )),
                Icon(Icons.arrow_drop_down_rounded,
                    color: SportSphereColors.white54, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Event type chips
          const Text('Predict event:', style: TextStyle(
              color: SportSphereColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _EventChip(label: 'Goal', icon: Icons.sports_soccer_rounded, color: SportSphereColors.sportGreen,
                onTap: () => onHomeScoreChanged(1)),
            _EventChip(label: 'Assist', icon: Icons.handshake_rounded, color: SportSphereColors.electricBlue,
                onTap: () {}),
            _EventChip(label: 'Red Card', icon: Icons.rectangle_rounded, color: SportSphereColors.danger,
                onTap: () {}),
            _EventChip(label: 'Yellow Card', icon: Icons.rectangle_rounded, color: const Color(0xFFFFD700),
                onTap: () {}),
            _EventChip(label: 'MOTM', icon: Icons.star_rounded, color: const Color(0xFFFFB900),
                onTap: () {}),
          ]),
          const SizedBox(height: 8),
          Text('Goals predicted: $homeScore',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
          Row(children: [
            const Text('Goals: ', style: TextStyle(color: SportSphereColors.white, fontSize: 13)),
            _ScoreStepper(value: homeScore, onChanged: onHomeScoreChanged),
          ]),
        ],
      ]),
    );
  }

  void _showMatchPicker(BuildContext context) {
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No upcoming matches. Admin must add fixtures first.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (_, sc) => Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Select Match', style: TextStyle(
                color: SportSphereColors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (selectedMatch != null)
            TextButton(
              onPressed: () { onMatchSelected(null); Navigator.pop(sheetCtx); },
              child: const Text('Clear selection', style: TextStyle(color: SportSphereColors.muted)),
            ),
          Expanded(child: ListView.builder(
            controller: sc,
            itemCount: matches.length,
            itemBuilder: (_, i) {
              final m = matches[i];
              final date = DateTime.tryParse(m['kickoffAt'] ?? '');
              final dateStr = date == null ? '' :
                  '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
              final isSelected = selectedMatch?['id'] == m['id'];
              return ListTile(
                selected: isSelected,
                selectedTileColor: SportSphereColors.sportGreen.withValues(alpha: 0.08),
                leading: Icon(Icons.sports_soccer_rounded,
                    color: isSelected ? SportSphereColors.sportGreen : SportSphereColors.muted),
                title: Text('${m["homeTeam"]} vs ${m["awayTeam"]}',
                    style: const TextStyle(color: SportSphereColors.white,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('${m["league"] ?? ""}  ·  $dateStr',
                    style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
                onTap: () { onMatchSelected(m); Navigator.pop(sheetCtx); },
              );
            },
          )),
        ]),
      ),
    );
  }

  void _showPlayerPicker(BuildContext context) {
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No players in DB. Admin must add players first.')));
      return;
    }
    final searchCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SportSphereColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(builder: (bCtx, bSet) {
        final query = searchCtrl.text.toLowerCase();
        final filtered = players.where((p) =>
            (p['name'] as String? ?? '').toLowerCase().contains(query)).toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (_, sc) => Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Select Player', style: TextStyle(
                  color: SportSphereColors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: searchCtrl,
                style: const TextStyle(color: SportSphereColors.white),
                onChanged: (_) => bSet(() {}),
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  hintStyle: const TextStyle(color: SportSphereColors.muted),
                  prefixIcon: const Icon(Icons.search_rounded, color: SportSphereColors.muted, size: 20),
                  filled: true, fillColor: const Color(0xFF0B1626),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(child: ListView.builder(
              controller: sc,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final isSelected = selectedPlayer?['id'] == p['id'];
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: SportSphereColors.electricBlue.withValues(alpha: 0.08),
                  leading: Icon(Icons.person_rounded,
                      color: isSelected ? SportSphereColors.electricBlue : SportSphereColors.muted),
                  title: Text(p['name'] as String? ?? '',
                      style: const TextStyle(color: SportSphereColors.white,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${p["position"] ?? ""}',
                      style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
                  onTap: () { onPlayerSelected(p); Navigator.pop(bCtx); },
                );
              },
            )),
          ]),
        );
      }),
    );
  }
}

class _PredTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PredTypeChip({required this.label, required this.icon,
      required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? SportSphereColors.sportGreen.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? SportSphereColors.sportGreen : SportSphereColors.white.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14,
            color: selected ? SportSphereColors.sportGreen : SportSphereColors.muted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? SportSphereColors.sportGreen : SportSphereColors.muted,
        )),
      ]),
    ),
  );
}

class _EventChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _EventChip({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
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
              color: SportSphereColors.white,
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
              : SportSphereColors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: onTap != null
                ? SportSphereColors.sportGreen.withValues(alpha: 0.4)
                : SportSphereColors.white.withValues(alpha: 0.06),
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
                    : SportSphereColors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: active
                      ? SportSphereColors.sportOrange
                          .withValues(alpha: 0.4)
                      : SportSphereColors.white.withValues(alpha: 0.07),
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
                    : SportSphereColors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: active
                      ? SportSphereColors.danger
                      : SportSphereColors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    o.icon,
                    size: 14,
                    color: active
                        ? SportSphereColors.white
                        : SportSphereColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    o.label,
                    style: TextStyle(
                      color: active
                          ? SportSphereColors.white
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
                    : SportSphereColors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isAdded
                      ? SportSphereColors.brightBlue
                          .withValues(alpha: 0.35)
                      : SportSphereColors.white.withValues(alpha: 0.07),
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
  final VoidCallback onPrediction;
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
    required this.onPrediction,
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
            color: SportSphereColors.white.withValues(alpha: 0.07),
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
                    _AttachChip(
                      icon: Icons.insights_rounded,
                      label: 'Predict',
                      active: activeType == _PostType.prediction,
                      color: SportSphereColors.sportGreen,
                      onTap: onPrediction,
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
                            : SportSphereColors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: expanded
                              ? SportSphereColors.electricBlue
                                  .withValues(alpha: 0.45)
                              : SportSphereColors.white.withValues(alpha: 0.10),
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
                                      color: SportSphereColors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Posted!',
                                      style: TextStyle(
                                        color: SportSphereColors.white,
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
                                        color: SportSphereColors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Post',
                                      style: TextStyle(
                                        color: SportSphereColors.white,
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
                : SportSphereColors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.5)
                  : SportSphereColors.white.withValues(alpha: 0.08),
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

  const _PanelField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SportSphereColors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SportSphereColors.white.withValues(alpha: 0.09)),
      ),
      child: TextField(
        controller: controller,
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
              color: SportSphereColors.white.withValues(alpha: 0.18),
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
